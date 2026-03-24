import 'dart:io';
import 'package:flutter_quality_analyzer/src/models/result.dart';
import 'package:flutter_quality_analyzer/src/models/version_check_result.dart';
import 'package:flutter_quality_analyzer/src/services/coverage_analyzer.dart';
import 'package:flutter_quality_analyzer/src/services/pubspec_reader.dart';
import 'package:flutter_quality_analyzer/src/utils/version_utils.dart';
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

    test('new fields default to null', () {
      final r = VersionCheckResult(
        packageName: 'foo',
        currentConstraint: '^1.0.0',
        latestVersion: '1.0.0',
        isOutdated: false,
      );
      expect(r.license, isNull);
      expect(r.pubPoints, isNull);
      expect(r.popularity, isNull);
      expect(r.likes, isNull);
      expect(r.hasTests, isNull);
      expect(r.testFileCount, isNull);
    });

    test('copyWith updates only specified fields', () {
      final r = VersionCheckResult(
        packageName: 'foo',
        currentConstraint: '^1.0.0',
        latestVersion: '1.0.0',
        isOutdated: false,
      );

      final updated = r.copyWith(
        license: 'MIT',
        pubPoints: 140,
        popularity: 95,
        likes: 200,
      );

      // Updated fields
      expect(updated.license, equals('MIT'));
      expect(updated.pubPoints, equals(140));
      expect(updated.popularity, equals(95));
      expect(updated.likes, equals(200));

      // Unchanged fields stay the same
      expect(updated.packageName, equals('foo'));
      expect(updated.currentConstraint, equals('^1.0.0'));
      expect(updated.isOutdated, isFalse);
      expect(updated.hasTests, isNull);
    });

    test('copyWith does not mutate original', () {
      final original = VersionCheckResult(
        packageName: 'bar',
        currentConstraint: '^2.0.0',
        latestVersion: '2.0.0',
        isOutdated: false,
      );

      original.copyWith(license: 'BSD', pubPoints: 120);

      // Original must be untouched
      expect(original.license, isNull);
      expect(original.pubPoints, isNull);
    });
  });

  // ─── CoverageAnalyzer Tests ───────────────────────────────────────────────
  group('CoverageAnalyzer', () {
    late CoverageAnalyzer analyzer;
    late Directory tempDir;

    setUp(() {
      analyzer = CoverageAnalyzer();
      tempDir = Directory.systemTemp.createTempSync('fqa_cov_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('returns grade None when no test/ directory exists', () {
      final result = analyzer.analyze(tempDir.path);
      expect(result.hasTestDirectory, isFalse);
      expect(result.testFileCount, equals(0));
      expect(result.grade, equals('None'));
      expect(result.testFiles, isEmpty);
    });

    test('detects test files correctly', () {
      // Create lib/ with source files
      final libDir = Directory('${tempDir.path}/lib')..createSync();
      File('${libDir.path}/foo.dart').writeAsStringSync('class Foo {}');
      File('${libDir.path}/bar.dart').writeAsStringSync('class Bar {}');

      // Create test/ with test files
      final testDir = Directory('${tempDir.path}/test')..createSync();
      File('${testDir.path}/foo_test.dart').writeAsStringSync('void main() {}');

      final result = analyzer.analyze(tempDir.path);
      expect(result.hasTestDirectory, isTrue);
      expect(result.testFileCount, equals(1));
      expect(result.sourceFileCount, equals(2));
      expect(result.testFiles, contains('foo_test.dart'));
    });

    test('grade is Excellent when ratio >= 0.8', () {
      final libDir = Directory('${tempDir.path}/lib')..createSync();
      final testDir = Directory('${tempDir.path}/test')..createSync();

      // 4 source files, 4 test files → ratio = 1.0
      for (var i = 0; i < 4; i++) {
        File('${libDir.path}/file$i.dart').writeAsStringSync('');
        File('${testDir.path}/file${i}_test.dart').writeAsStringSync('');
      }

      final result = analyzer.analyze(tempDir.path);
      expect(result.grade, equals('Excellent'));
    });

    test('grade is Poor when ratio < 0.2', () {
      final libDir = Directory('${tempDir.path}/lib')..createSync();
      final testDir = Directory('${tempDir.path}/test')..createSync();

      // 10 source files, 1 test file → ratio = 0.1
      for (var i = 0; i < 10; i++) {
        File('${libDir.path}/file$i.dart').writeAsStringSync('');
      }
      File('${testDir.path}/one_test.dart').writeAsStringSync('');

      final result = analyzer.analyze(tempDir.path);
      expect(result.grade, equals('Poor'));
    });

    test('grade is None when test dir exists but has no test files', () {
      Directory('${tempDir.path}/test').createSync();
      // No *_test.dart files inside

      final result = analyzer.analyze(tempDir.path);
      expect(result.testFileCount, equals(0));
      expect(result.grade, equals('None'));
    });

    test('coverageRatio is 0 when no source files exist', () {
      Directory('${tempDir.path}/test').createSync();
      // No lib/ directory

      final result = analyzer.analyze(tempDir.path);
      expect(result.coverageRatio, equals(0.0));
    });
  });
}
