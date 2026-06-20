// integration_test/test_report_generator.dart
// Test Report Generator for Zyppi Ride E2E Tests

import 'dart:convert';
import 'dart:io';
import 'test_config.dart';

/// Generates comprehensive test reports in multiple formats
class TestReportGenerator {
  final List<TestSuiteResult> _suiteResults = [];
  final DateTime _reportStartTime;
  String _deviceInfo = 'Unknown Device';
  String _appVersion = '1.0.0';

  TestReportGenerator() : _reportStartTime = DateTime.now();

  /// Set device information for the report
  void setDeviceInfo(String deviceInfo) {
    _deviceInfo = deviceInfo;
  }

  /// Set app version for the report
  void setAppVersion(String version) {
    _appVersion = version;
  }

  /// Add a test suite result
  void addSuiteResult(TestSuiteResult result) {
    _suiteResults.add(result);
  }

  /// Get overall statistics
  Map<String, dynamic> getOverallStats() {
    int totalTests = 0;
    int passedTests = 0;
    int failedTests = 0;

    for (var suite in _suiteResults) {
      totalTests += suite.totalTests;
      passedTests += suite.passedTests;
      failedTests += suite.failedTests;
    }

    return {
      'totalTests': totalTests,
      'passedTests': passedTests,
      'failedTests': failedTests,
      'passRate': totalTests > 0 ? (passedTests / totalTests) * 100 : 0,
      'totalSuites': _suiteResults.length,
    };
  }

  /// Generate JSON report
  String generateJsonReport() {
    final report = {
      'reportMetadata': {
        'generatedAt': DateTime.now().toIso8601String(),
        'startTime': _reportStartTime.toIso8601String(),
        'deviceInfo': _deviceInfo,
        'appVersion': _appVersion,
        'platform': Platform.operatingSystem,
      },
      'summary': getOverallStats(),
      'suites': _suiteResults.map((s) => s.toJson()).toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(report);
  }

  /// Generate HTML report
  String generateHtmlReport() {
    final stats = getOverallStats();
    final buffer = StringBuffer();

    buffer.writeln('''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Zyppi Ride - E2E Test Report</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: #f5f7fa;
            color: #333;
            line-height: 1.6;
        }
        .container { max-width: 1200px; margin: 0 auto; padding: 20px; }

        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 40px;
            border-radius: 10px;
            margin-bottom: 30px;
            box-shadow: 0 10px 30px rgba(102, 126, 234, 0.3);
        }
        .header h1 { font-size: 2.5em; margin-bottom: 10px; }
        .header .subtitle { opacity: 0.9; font-size: 1.1em; }

        .summary-cards {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        .card {
            background: white;
            padding: 25px;
            border-radius: 10px;
            box-shadow: 0 5px 15px rgba(0,0,0,0.08);
            text-align: center;
        }
        .card.passed { border-left: 4px solid #4CAF50; }
        .card.failed { border-left: 4px solid #f44336; }
        .card.total { border-left: 4px solid #2196F3; }
        .card.rate { border-left: 4px solid #FF9800; }
        .card .number {
            font-size: 2.5em;
            font-weight: bold;
            color: #333;
        }
        .card .label { color: #666; margin-top: 5px; }

        .suite {
            background: white;
            border-radius: 10px;
            margin-bottom: 20px;
            box-shadow: 0 5px 15px rgba(0,0,0,0.08);
            overflow: hidden;
        }
        .suite-header {
            padding: 20px;
            background: #f8f9fa;
            border-bottom: 1px solid #e9ecef;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .suite-header h3 { color: #333; }
        .suite-stats {
            display: flex;
            gap: 15px;
        }
        .suite-stat {
            padding: 5px 12px;
            border-radius: 20px;
            font-size: 0.85em;
            font-weight: 600;
        }
        .suite-stat.passed { background: #e8f5e9; color: #2e7d32; }
        .suite-stat.failed { background: #ffebee; color: #c62828; }

        .test-list { padding: 0; }
        .test-item {
            padding: 15px 20px;
            border-bottom: 1px solid #f0f0f0;
            display: flex;
            align-items: center;
            gap: 15px;
        }
        .test-item:last-child { border-bottom: none; }
        .test-item:hover { background: #f8f9fa; }

        .test-status {
            width: 30px;
            height: 30px;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 14px;
        }
        .test-status.passed { background: #4CAF50; color: white; }
        .test-status.failed { background: #f44336; color: white; }

        .test-details { flex: 1; }
        .test-name { font-weight: 500; color: #333; }
        .test-category { font-size: 0.85em; color: #666; }
        .test-duration {
            font-size: 0.85em;
            color: #999;
            font-family: monospace;
        }

        .error-message {
            background: #fff3f3;
            border-left: 3px solid #f44336;
            padding: 10px 15px;
            margin-top: 10px;
            font-size: 0.85em;
            color: #c62828;
            border-radius: 0 5px 5px 0;
        }

        .metadata {
            background: white;
            padding: 20px;
            border-radius: 10px;
            margin-top: 30px;
            box-shadow: 0 5px 15px rgba(0,0,0,0.08);
        }
        .metadata h3 { margin-bottom: 15px; color: #333; }
        .metadata-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
        }
        .metadata-item {
            padding: 10px;
            background: #f8f9fa;
            border-radius: 5px;
        }
        .metadata-item .label { font-size: 0.85em; color: #666; }
        .metadata-item .value { font-weight: 500; color: #333; }

        .footer {
            text-align: center;
            padding: 30px;
            color: #666;
            font-size: 0.9em;
        }

        @media print {
            body { background: white; }
            .container { max-width: none; }
            .suite, .card, .metadata { box-shadow: none; border: 1px solid #ddd; }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Zyppi Ride</h1>
            <p class="subtitle">End-to-End Test Report</p>
        </div>

        <div class="summary-cards">
            <div class="card total">
                <div class="number">${stats['totalTests']}</div>
                <div class="label">Total Tests</div>
            </div>
            <div class="card passed">
                <div class="number">${stats['passedTests']}</div>
                <div class="label">Passed</div>
            </div>
            <div class="card failed">
                <div class="number">${stats['failedTests']}</div>
                <div class="label">Failed</div>
            </div>
            <div class="card rate">
                <div class="number">${stats['passRate'].toStringAsFixed(1)}%</div>
                <div class="label">Pass Rate</div>
            </div>
        </div>
''');

    // Generate suite sections
    for (var suite in _suiteResults) {
      buffer.writeln('''
        <div class="suite">
            <div class="suite-header">
                <h3>${suite.suiteName}</h3>
                <div class="suite-stats">
                    <span class="suite-stat passed">${suite.passedTests} Passed</span>
                    <span class="suite-stat failed">${suite.failedTests} Failed</span>
                </div>
            </div>
            <div class="test-list">
''');

      for (var result in suite.results) {
        final statusIcon = result.passed ? '&#10004;' : '&#10008;';
        final statusClass = result.passed ? 'passed' : 'failed';

        buffer.writeln('''
                <div class="test-item">
                    <div class="test-status $statusClass">$statusIcon</div>
                    <div class="test-details">
                        <div class="test-name">${result.testName}</div>
                        <div class="test-category">${result.category}</div>
                        ${result.errorMessage != null ? '<div class="error-message">${_escapeHtml(result.errorMessage!)}</div>' : ''}
                    </div>
                    <div class="test-duration">${result.duration.inMilliseconds}ms</div>
                </div>
''');
      }

      buffer.writeln('''
            </div>
        </div>
''');
    }

    buffer.writeln('''
        <div class="metadata">
            <h3>Test Environment</h3>
            <div class="metadata-grid">
                <div class="metadata-item">
                    <div class="label">Device</div>
                    <div class="value">$_deviceInfo</div>
                </div>
                <div class="metadata-item">
                    <div class="label">App Version</div>
                    <div class="value">$_appVersion</div>
                </div>
                <div class="metadata-item">
                    <div class="label">Platform</div>
                    <div class="value">${Platform.operatingSystem}</div>
                </div>
                <div class="metadata-item">
                    <div class="label">Report Generated</div>
                    <div class="value">${DateTime.now().toString().split('.')[0]}</div>
                </div>
            </div>
        </div>

        <div class="footer">
            <p>Generated by Zyppi Ride E2E Test Framework</p>
        </div>
    </div>
</body>
</html>
''');

    return buffer.toString();
  }

  /// Generate Markdown report
  String generateMarkdownReport() {
    final stats = getOverallStats();
    final buffer = StringBuffer();

    buffer.writeln('# Zyppi Ride - E2E Test Report\n');
    buffer.writeln('Generated: ${DateTime.now().toString().split('.')[0]}\n');

    buffer.writeln('## Summary\n');
    buffer.writeln('| Metric | Value |');
    buffer.writeln('|--------|-------|');
    buffer.writeln('| Total Tests | ${stats['totalTests']} |');
    buffer.writeln('| Passed | ${stats['passedTests']} |');
    buffer.writeln('| Failed | ${stats['failedTests']} |');
    buffer.writeln('| Pass Rate | ${stats['passRate'].toStringAsFixed(1)}% |');
    buffer.writeln('');

    buffer.writeln('## Test Environment\n');
    buffer.writeln('- **Device:** $_deviceInfo');
    buffer.writeln('- **App Version:** $_appVersion');
    buffer.writeln('- **Platform:** ${Platform.operatingSystem}');
    buffer.writeln('');

    for (var suite in _suiteResults) {
      buffer.writeln('## ${suite.suiteName}\n');
      buffer.writeln(
          '**Duration:** ${suite.totalDuration.inSeconds}s | **Pass Rate:** ${suite.passRate.toStringAsFixed(1)}%\n');

      buffer.writeln('| Status | Test Name | Category | Duration |');
      buffer.writeln('|--------|-----------|----------|----------|');

      for (var result in suite.results) {
        final status = result.passed ? ':white_check_mark:' : ':x:';
        buffer.writeln(
            '| $status | ${result.testName} | ${result.category} | ${result.duration.inMilliseconds}ms |');
      }

      // List failed tests with errors
      final failedTests = suite.results.where((r) => !r.passed).toList();
      if (failedTests.isNotEmpty) {
        buffer.writeln('\n### Failed Tests Details\n');
        for (var result in failedTests) {
          buffer.writeln('**${result.testName}**');
          buffer.writeln('```');
          buffer.writeln(result.errorMessage ?? 'No error message');
          buffer.writeln('```\n');
        }
      }
      buffer.writeln('');
    }

    buffer.writeln('---\n');
    buffer.writeln('*Report generated by Zyppi Ride E2E Test Framework*');

    return buffer.toString();
  }

  /// Generate JUnit XML report (for CI/CD integration)
  String generateJUnitXmlReport() {
    final stats = getOverallStats();
    final buffer = StringBuffer();

    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln(
        '<testsuites name="Zyppi Ride E2E Tests" tests="${stats['totalTests']}" failures="${stats['failedTests']}" time="${_getTotalDurationSeconds()}">');

    for (var suite in _suiteResults) {
      buffer.writeln(
          '  <testsuite name="${suite.suiteName}" tests="${suite.totalTests}" failures="${suite.failedTests}" time="${suite.totalDuration.inSeconds}">');

      for (var result in suite.results) {
        buffer.writeln(
            '    <testcase name="${_escapeXml(result.testName)}" classname="${_escapeXml(result.category)}" time="${result.duration.inMilliseconds / 1000}">');
        if (!result.passed) {
          buffer.writeln(
              '      <failure message="${_escapeXml(result.errorMessage ?? 'Test failed')}">${_escapeXml(result.stackTrace ?? '')}</failure>');
        }
        buffer.writeln('    </testcase>');
      }

      buffer.writeln('  </testsuite>');
    }

    buffer.writeln('</testsuites>');

    return buffer.toString();
  }

  /// Save all report formats to files
  Future<Map<String, String>> saveReports(String outputDir) async {
    final dir = Directory(outputDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final timestamp =
        DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
    final paths = <String, String>{};

    // Save JSON report
    final jsonPath = '$outputDir/test_report_$timestamp.json';
    await File(jsonPath).writeAsString(generateJsonReport());
    paths['json'] = jsonPath;

    // Save HTML report
    final htmlPath = '$outputDir/test_report_$timestamp.html';
    await File(htmlPath).writeAsString(generateHtmlReport());
    paths['html'] = htmlPath;

    // Save Markdown report
    final mdPath = '$outputDir/test_report_$timestamp.md';
    await File(mdPath).writeAsString(generateMarkdownReport());
    paths['markdown'] = mdPath;

    // Save JUnit XML report
    final xmlPath = '$outputDir/test_report_$timestamp.xml';
    await File(xmlPath).writeAsString(generateJUnitXmlReport());
    paths['junit'] = xmlPath;

    return paths;
  }

  /// Print summary to console
  void printSummary() {
    final stats = getOverallStats();

    print('\n${'=' * 60}');
    print('ZYPPI RIDE E2E TEST REPORT');
    print('${'=' * 60}\n');

    print('SUMMARY');
    print('-' * 40);
    print('Total Tests:  ${stats['totalTests']}');
    print('Passed:       ${stats['passedTests']}');
    print('Failed:       ${stats['failedTests']}');
    print('Pass Rate:    ${stats['passRate'].toStringAsFixed(1)}%');
    print('');

    for (var suite in _suiteResults) {
      print('\n${suite.suiteName}');
      print('-' * 40);

      for (var result in suite.results) {
        final status = result.passed ? 'PASS' : 'FAIL';
        final icon = result.passed ? '✓' : '✗';
        print(
            '  $icon [$status] ${result.testName} (${result.duration.inMilliseconds}ms)');
        if (!result.passed && result.errorMessage != null) {
          print('     Error: ${result.errorMessage}');
        }
      }
    }

    print('\n${'=' * 60}');
    print('Report generated at: ${DateTime.now()}');
    print('${'=' * 60}\n');
  }

  double _getTotalDurationSeconds() {
    double total = 0;
    for (var suite in _suiteResults) {
      total += suite.totalDuration.inMilliseconds / 1000;
    }
    return total;
  }

  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}

/// Test runner with reporting capabilities
class TestRunner {
  final TestReportGenerator _reportGenerator;
  final List<TestResult> _currentSuiteResults = [];
  String _currentSuiteName = '';
  DateTime? _suiteStartTime;

  TestRunner() : _reportGenerator = TestReportGenerator();

  TestReportGenerator get reportGenerator => _reportGenerator;

  /// Start a new test suite
  void startSuite(String suiteName) {
    if (_currentSuiteName.isNotEmpty && _currentSuiteResults.isNotEmpty) {
      _finishCurrentSuite();
    }
    _currentSuiteName = suiteName;
    _currentSuiteResults.clear();
    _suiteStartTime = DateTime.now();
    print('\n📋 Starting Test Suite: $suiteName');
    print('─' * 50);
  }

  /// Record a test result
  void recordTest({
    required String testName,
    required String category,
    required bool passed,
    required Duration duration,
    String? errorMessage,
    String? stackTrace,
    Map<String, dynamic>? metadata,
  }) {
    final result = TestResult(
      testName: testName,
      category: category,
      passed: passed,
      duration: duration,
      errorMessage: errorMessage,
      stackTrace: stackTrace,
      metadata: metadata,
    );
    _currentSuiteResults.add(result);

    final icon = passed ? '✅' : '❌';
    final status = passed ? 'PASSED' : 'FAILED';
    print('$icon $testName - $status (${duration.inMilliseconds}ms)');
    if (!passed && errorMessage != null) {
      print('   ⚠️  Error: $errorMessage');
    }
  }

  /// Run a test with automatic timing and error capture
  Future<void> runTest({
    required String testName,
    required String category,
    required Future<void> Function() testFunction,
  }) async {
    final stopwatch = Stopwatch()..start();
    String? errorMessage;
    String? stackTrace;
    bool passed = true;

    try {
      await testFunction();
    } catch (e, st) {
      passed = false;
      errorMessage = e.toString();
      stackTrace = st.toString();
    } finally {
      stopwatch.stop();
      recordTest(
        testName: testName,
        category: category,
        passed: passed,
        duration: stopwatch.elapsed,
        errorMessage: errorMessage,
        stackTrace: stackTrace,
      );
    }
  }

  /// Finish current suite and start recording
  void _finishCurrentSuite() {
    if (_currentSuiteName.isEmpty) return;

    final suiteResult = TestSuiteResult(
      suiteName: _currentSuiteName,
      results: List.from(_currentSuiteResults),
      startTime: _suiteStartTime ?? DateTime.now(),
      endTime: DateTime.now(),
    );
    _reportGenerator.addSuiteResult(suiteResult);

    print(
        '\n📊 Suite Complete: ${suiteResult.passedTests}/${suiteResult.totalTests} passed (${suiteResult.passRate.toStringAsFixed(1)}%)');
  }

  /// Finish all tests and generate reports
  Future<Map<String, String>> finishAndGenerateReports(
      String outputDir) async {
    _finishCurrentSuite();
    _reportGenerator.printSummary();
    return await _reportGenerator.saveReports(outputDir);
  }
}
