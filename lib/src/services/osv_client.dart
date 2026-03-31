import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/version_check_result.dart';
import '../models/vulnerability_result.dart';
import '../utils/logger.dart';

/// Queries the OSV (Open Source Vulnerabilities) API for known CVEs/GHSAs.
///
/// Uses the batch endpoint — one HTTP request for all packages.
/// Free, no API key required. https://osv.dev/
class OsvClient {
  static const _batchUrl = 'https://api.osv.dev/v1/querybatch';
  static const _timeout  = Duration(seconds: 15);

  final http.Client _httpClient;

  OsvClient({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  /// Checks all [results] for known vulnerabilities in a single batch request.
  ///
  /// Returns a map of packageName → [VulnerabilityResult].
  /// Packages with no vulnerabilities are still included with an empty list.
  Future<Map<String, VulnerabilityResult>> checkAll(
    List<VersionCheckResult> results,
  ) async {
    // Only check packages where we know the version
    final checkable = results
        .where((r) => r.latestVersion != null && r.error == null)
        .toList();

    if (checkable.isEmpty) return {};

    Logger.debug('OSV batch check: ${checkable.length} packages');

    // Build batch request body:
    // { "queries": [ { "package": { "name": "http", "ecosystem": "Pub" },
    //                  "version": "1.2.0" }, ... ] }
    final queries = checkable.map((r) => {
      'package': {'name': r.packageName, 'ecosystem': 'Pub'},
      'version': r.latestVersion,
    }).toList();

    try {
      final response = await _httpClient
          .post(
            Uri.parse(_batchUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'queries': queries}),
          )
          .timeout(_timeout);

      Logger.debug('OSV response: ${response.statusCode}');

      if (response.statusCode != 200) {
        Logger.warn('OSV API returned ${response.statusCode} — skipping security check');
        return {};
      }

      return _parse(checkable, response.body);
    } catch (e) {
      Logger.warn('OSV API unreachable — skipping security check: $e');
      return {};
    } finally {
      _httpClient.close();
    }
  }

  Map<String, VulnerabilityResult> _parse(
    List<VersionCheckResult> checkable,
    String body,
  ) {
    final output = <String, VulnerabilityResult>{};

    try {
      final json     = jsonDecode(body) as Map<String, dynamic>;
      // results array aligns 1-to-1 with the queries array
      final rawList  = (json['results'] as List<dynamic>?) ?? [];

      for (var i = 0; i < checkable.length && i < rawList.length; i++) {
        final pkg    = checkable[i];
        final entry  = rawList[i] as Map<String, dynamic>;
        final vulns  = (entry['vulns'] as List<dynamic>?) ?? [];

        final vulnerabilities = vulns.map<Vulnerability>((v) {
          final vMap    = v as Map<String, dynamic>;
          final id      = vMap['id'] as String? ?? 'UNKNOWN';
          final aliases = (vMap['aliases'] as List<dynamic>?)
                ?.cast<String>() ?? [];
          final summary = vMap['summary'] as String?;

          // Parse severity from database_specific or severity array
          final severity = _extractSeverity(vMap);

          return Vulnerability(
            id: id,
            aliases: aliases,
            summary: summary,
            severity: severity,
          );
        }).toList();

        output[pkg.packageName] = VulnerabilityResult(
          packageName: pkg.packageName,
          version: pkg.latestVersion!,
          vulnerabilities: vulnerabilities,
        );

        if (vulnerabilities.isNotEmpty) {
          Logger.debug(
            '${pkg.packageName}: ${vulnerabilities.length} vuln(s) found '
            '[${vulnerabilities.map((v) => v.id).join(', ')}]',
          );
        }
      }
    } catch (e) {
      Logger.debug('Failed to parse OSV response: $e');
    }

    return output;
  }

  String _extractSeverity(Map<String, dynamic> vuln) {
    // Try CVSS severity from the severity array
    final severityList = vuln['severity'] as List<dynamic>?;
    if (severityList != null) {
      for (final s in severityList) {
        final score = (s as Map<String, dynamic>)['score'] as String?;
        if (score != null) {
          // CVSS score string like "CVSS:3.1/AV:N/.../9.8" — extract base score
          final parts  = score.split('/');
          final bsPart = parts.lastWhere(
            (p) => RegExp(r'^\d+\.\d+$').hasMatch(p),
            orElse: () => '',
          );
          if (bsPart.isNotEmpty) {
            final baseScore = double.tryParse(bsPart);
            if (baseScore != null) return _cvssToSeverity(baseScore);
          }
        }
      }
    }

    // Fallback: database_specific.severity
    final dbSpecific = vuln['database_specific'] as Map<String, dynamic>?;
    final sev = dbSpecific?['severity'] as String?;
    if (sev != null) return sev.toUpperCase();

    return 'UNKNOWN';
  }

  String _cvssToSeverity(double score) {
    if (score >= 9.0) return 'CRITICAL';
    if (score >= 7.0) return 'HIGH';
    if (score >= 4.0) return 'MEDIUM';
    if (score > 0.0)  return 'LOW';
    return 'UNKNOWN';
  }
}
