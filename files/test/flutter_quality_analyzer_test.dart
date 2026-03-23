import 'dart:io';
import 'package:test/test.dart';
import 'package:flutter_quality_analyzer/flutter_quality_analyzer.dart';

void main() {
  // ─── PubspecReader Tests ───────────────────────────────────────────────────
  group('PubspecReader', () {
    late PubspecReader reader;
    late Directory tempDir;

    setUp(() {
      reader = PubspecReader();
      tempDir = Directory.systemTemp.createTempSync('fqa_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('returns failure when pubspec.yaml does not exist', () {
      final result = reader.read(tempDir.path);
      expect(result.isFailure, isTrue);
      expect(result.error, contains('pubspec.yaml'));
    });

    test('parses a valid pubspec.yaml correctly', () {
      File('${tempDir.path}/pubspec.yaml').writeAsStringSync('''
name: my_app
dependencies:
  http: ^1.0.0
  riverpod: ^2.0.0
  flutter:
    sdk: flutter
dev_dependencies:
  test: ^1.24.0
''');

      final result = reader.read(tempDir.path);
      expect(result.isSuccess, isTrue);

      final pubspec = result.value!;
      expect(pubspec.projectName, equals('my_app'));

      final names = pubspec.dependencies.map((d) => d.name).toList();
      expect(names, contains('http'));
      expect(names, contains('riverpod'));
      expect(names, contains('test'));

      // Flutter SDK dep must be excluded
      expect(names, isNot(contains('flutter')));
    });

    test('filters out path and git dependencies', () {
      File('${tempDir.path}/pubspec.yaml').writeAsStringSync('''
name: my_app
dependencies:
  local_pkg:
    path: ../local_pkg
  git_pkg:
    git:
      url: https://github.com/example/pkg.git
  http: ^1.0.0
''');

      final result = reader.read(tempDir.path);
      expect(result.isSuccess, isTrue);

      final names = result.value!.dependencies.map((d) => d.name).toList();
      expect(names, contains('http'));
      expect(names, isNot(contains('local_pkg')));
      expect(names, isNot(contains('git_pkg')));
    });

    test('handles empty dependencies gracefully', () {
      File('${tempDir.path}/pubspec.yaml').writeAsStringSync('''
name: empty_app
''');
      final result = reader.read(tempDir.path);
      expect(result.isSuccess, isTrue);
      expect(result.value!.dependencies, isEmpty);
    });
  });

  // ─── VersionUtils Tests ────────────────────────────────────────────────────
  group('VersionUtils', () {
    test('stripConstraint removes caret', () {
      expect(VersionUtils.stripConstraint('^1.2.3'), equals('1.2.3'));
    });

    test('stripConstraint removes >=', () {
      expect(VersionUtils.stripConstraint('>=2.0.0'), equals('2.0.0'));
    });

    test('stripConstraint leaves plain version unchanged', () {
      expect(VersionUtils.stripConstraint('1.0.0'), equals('1.0.0'));
    });

    test('isValidSemver returns true for valid versions', () {
      expect(VersionUtils.isValidSemver('1.2.3'), isTrue);
      expect(VersionUtils.isValidSemver('0.0.1'), isTrue);
      expect(VersionUtils.isValidSemver('10.20.30'), isTrue);
    });

    test('isValidSemver returns false for invalid versions', () {
      expect(VersionUtils.isValidSemver('^1.2.3'), isFalse);
      expect(VersionUtils.isValidSemver('not-a-version'), isFalse);
    });

    test('formatConstraint returns dash for null', () {
      expect(VersionUtils.formatConstraint(null), equals('-'));
      expect(VersionUtils.formatConstraint(''), equals('-'));
    });

    test('formatConstraint returns value for non-null', () {
      expect(VersionUtils.formatConstraint('^1.0.0'), equals('^1.0.0'));
    });
  });

  // ─── Result Tests ──────────────────────────────────────────────────────────
  group('Result<T>', () {
    test('success holds value', () {
      final r = Result.success(42);
      expect(r.isSuccess, isTrue);
      expect(r.isFailure, isFalse);
      expect(r.value, equals(42));
      expect(r.error, isNull);
    });

    test('failure holds error', () {
      final r = Result<int>.failure('oops');
      expect(r.isFailure, isTrue);
      expect(r.isSuccess, isFalse);
      expect(r.error, equals('oops'));
      expect(r.value, isNull);
    });
  });

  // ─── VersionCheckResult Tests ──────────────────────────────────────────────
  group('VersionCheckResult', () {
    test('failed factory sets error and null latestVersion', () {
      final r = VersionCheckResult.failed(
        packageName: 'foo',
        currentConstraint: '^1.0.0',
        error: 'Network error',
      );
      expect(r.latestVersion, isNull);
      expect(r.error, equals('Network error'));
      expect(r.isOutdated, isFalse);
    });

    test('outdated flag works correctly', () {
      final r = VersionCheckResult(
        packageName: 'foo',
        currentConstraint: '^0.13.0',
        latestVersion: '1.2.0',
        isOutdated: true,
      );
      expect(r.isOutdated, isTrue);
    });
  });
}
