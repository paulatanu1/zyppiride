// integration_test/e2e/config/e2e_test_config.dart
// Enterprise-grade E2E Test Configuration

import 'dart:convert';
import 'dart:io';

/// E2E Test User Roles
enum TestUserRole {
  driver,
  owner,
}

/// Test User Data Model
class E2ETestUser {
  final String id;
  final String email;
  final String password;
  final String phone;
  final String fullName;
  final TestUserRole role;
  final String city;
  final String state;
  final Map<String, dynamic>? vehicleData;

  const E2ETestUser({
    required this.id,
    required this.email,
    required this.password,
    required this.phone,
    required this.fullName,
    required this.role,
    this.city = 'Bangalore',
    this.state = 'Karnataka',
    this.vehicleData,
  });

  String get roleString => role == TestUserRole.driver ? 'Driver' : 'Vehicle Owner';

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'phone': phone,
        'fullName': fullName,
        'role': roleString,
        'city': city,
        'state': state,
      };

  Map<String, dynamic> toFirestoreUser() => {
        'userId': id,
        'email': email,
        'mobile': phone,
        'fullName': fullName,
        'role': roleString,
        'city': city,
        'state': state,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'isDriver': role == TestUserRole.driver,
        'verificationStatus': 'pending',
        'fcmToken': null,
        'profileImageUrl': null,
      };
}

/// Test Vehicle Data Model
class E2ETestVehicle {
  final String registrationNumber;
  final String brand;
  final String model;
  final String vehicleType;
  final String category;
  final int seatingCapacity;
  final String fuelType;
  final String color;
  final int year;

  const E2ETestVehicle({
    required this.registrationNumber,
    required this.brand,
    required this.model,
    required this.vehicleType,
    required this.category,
    this.seatingCapacity = 4,
    this.fuelType = 'Petrol',
    this.color = 'White',
    this.year = 2022,
  });

  Map<String, dynamic> toFirestore(String ownerId) => {
        'registrationNumber': registrationNumber,
        'brand': brand,
        'model': model,
        'vehicleType': vehicleType,
        'category': category,
        'seatingCapacity': seatingCapacity,
        'fuelType': fuelType,
        'color': color,
        'year': year,
        'userId': ownerId,
        'isOnline': false,
        'isActive': true,
        'documentStatus': 'pending',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'location': {
          'city': 'Bangalore',
          'state': 'Karnataka',
          'latitude': 12.9716,
          'longitude': 77.5946,
        },
        'fareSettings': {
          'baseFare': 50.0,
          'perKmCharge': 12.0,
          'perMinuteCharge': 2.0,
          'minimumFare': 80.0,
        },
      };
}

/// Main E2E Configuration
class E2ETestConfig {
  // ============================
  // TEST MODE FLAGS
  // ============================
  static const bool isE2ETestMode = true;
  static const String testCollectionPrefix = 'e2e_test_';
  static const bool skipOtpVerification = true;
  static const bool skipEmailVerification = true;
  static const bool captureScreenshotsOnFailure = true;
  static const bool cleanupAfterTests = false;
  static const String testEnvironment = 'E2E_TEST';

  // ============================
  // TIMEOUTS
  // ============================
  static const Duration shortTimeout = Duration(seconds: 5);
  static const Duration mediumTimeout = Duration(seconds: 15);
  static const Duration longTimeout = Duration(seconds: 30);
  static const Duration veryLongTimeout = Duration(seconds: 60);
  static const Duration pumpSettleTimeout = Duration(seconds: 10);

  // ============================
  // REPORT PATHS (using project root absolute path)
  // ============================
  static String get reportDirectory =>
      '/Users/atanu_paul/Documents/zyppi_ride/test_results/reports';
  static String get screenshotDirectory =>
      '/Users/atanu_paul/Documents/zyppi_ride/test_results/screenshots';
  static String get jsonReportFile =>
      '/Users/atanu_paul/Documents/zyppi_ride/test_results/reports/report.json';
  static String get htmlReportFile =>
      '/Users/atanu_paul/Documents/zyppi_ride/test_results/reports/report.html';

  // ============================
  // 5 FIXED TEST USERS (using Mailinator.com for real email testing)
  // ============================
  static const List<E2ETestUser> testUsers = [
    // Driver 1
    E2ETestUser(
      id: 'e2e_driver_001',
      email: 'zyppi.driver1@mailinator.com',
      password: 'TestDriver@001',
      phone: '+919000000001',
      fullName: 'Test Driver One',
      role: TestUserRole.driver,
      city: 'Bangalore',
      state: 'Karnataka',
    ),
    // Driver 2
    E2ETestUser(
      id: 'e2e_driver_002',
      email: 'zyppi.driver2@mailinator.com',
      password: 'TestDriver@002',
      phone: '+919000000002',
      fullName: 'Test Driver Two',
      role: TestUserRole.driver,
      city: 'Chennai',
      state: 'Tamil Nadu',
    ),
    // Owner 1
    E2ETestUser(
      id: 'e2e_owner_001',
      email: 'zyppi.owner1@mailinator.com',
      password: 'TestOwner@001',
      phone: '+919000000003',
      fullName: 'Test Owner One',
      role: TestUserRole.owner,
      city: 'Bangalore',
      state: 'Karnataka',
    ),
    // Owner 2
    E2ETestUser(
      id: 'e2e_owner_002',
      email: 'zyppi.owner2@mailinator.com',
      password: 'TestOwner@002',
      phone: '+919000000004',
      fullName: 'Test Owner Two',
      role: TestUserRole.owner,
      city: 'Mumbai',
      state: 'Maharashtra',
    ),
    // Owner 3 (with multiple vehicles)
    E2ETestUser(
      id: 'e2e_owner_003',
      email: 'zyppi.owner3@mailinator.com',
      password: 'TestOwner@003',
      phone: '+919000000005',
      fullName: 'Test Owner Three',
      role: TestUserRole.owner,
      city: 'Delhi',
      state: 'Delhi',
    ),
  ];

  // ============================
  // TEST VEHICLES
  // ============================
  static const List<E2ETestVehicle> testVehicles = [
    E2ETestVehicle(
      registrationNumber: 'KA01E2E0001',
      brand: 'Maruti',
      model: 'Swift',
      vehicleType: 'Hatchback',
      category: 'Mini',
      seatingCapacity: 4,
      fuelType: 'Petrol',
      color: 'White',
      year: 2022,
    ),
    E2ETestVehicle(
      registrationNumber: 'KA01E2E0002',
      brand: 'Honda',
      model: 'City',
      vehicleType: 'Sedan',
      category: 'Sedan',
      seatingCapacity: 4,
      fuelType: 'Petrol',
      color: 'Silver',
      year: 2023,
    ),
    E2ETestVehicle(
      registrationNumber: 'TN01E2E0001',
      brand: 'Toyota',
      model: 'Innova',
      vehicleType: 'SUV',
      category: 'SUV',
      seatingCapacity: 7,
      fuelType: 'Diesel',
      color: 'Black',
      year: 2022,
    ),
    E2ETestVehicle(
      registrationNumber: 'MH01E2E0001',
      brand: 'Tata',
      model: 'Ace',
      vehicleType: 'Pickup',
      category: 'Goods',
      seatingCapacity: 2,
      fuelType: 'Diesel',
      color: 'Blue',
      year: 2021,
    ),
    E2ETestVehicle(
      registrationNumber: 'DL01E2E0001',
      brand: 'Mahindra',
      model: 'XUV700',
      vehicleType: 'SUV',
      category: 'Premium',
      seatingCapacity: 7,
      fuelType: 'Diesel',
      color: 'Red',
      year: 2023,
    ),
  ];

  // ============================
  // HELPER METHODS
  // ============================

  /// Get drivers only
  static List<E2ETestUser> get drivers =>
      testUsers.where((u) => u.role == TestUserRole.driver).toList();

  /// Get owners only
  static List<E2ETestUser> get owners =>
      testUsers.where((u) => u.role == TestUserRole.owner).toList();

  /// Get user by email
  static E2ETestUser? getUserByEmail(String email) {
    try {
      return testUsers.firstWhere((u) => u.email == email);
    } catch (e) {
      return null;
    }
  }

  /// Get user by ID
  static E2ETestUser? getUserById(String id) {
    try {
      return testUsers.firstWhere((u) => u.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Ensure report directories exist
  static Future<void> ensureDirectories() async {
    final dirs = [reportDirectory, screenshotDirectory];
    for (final dir in dirs) {
      final directory = Directory(dir);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
    }
  }

  /// Get Firebase collection name with test prefix
  static String getCollection(String baseName) {
    return isE2ETestMode ? '$testCollectionPrefix$baseName' : baseName;
  }
}

/// Test Execution Context
class E2ETestContext {
  final E2ETestUser currentUser;
  final DateTime startTime;
  final List<E2ETestResult> results;
  String? currentTestName;
  bool isLoggedIn;

  E2ETestContext({
    required this.currentUser,
  })  : startTime = DateTime.now(),
        results = [],
        isLoggedIn = false;

  void addResult(E2ETestResult result) {
    results.add(result);
  }

  Map<String, dynamic> toJson() => {
        'user': currentUser.toJson(),
        'startTime': startTime.toIso8601String(),
        'endTime': DateTime.now().toIso8601String(),
        'totalTests': results.length,
        'passedTests': results.where((r) => r.passed).length,
        'failedTests': results.where((r) => !r.passed).length,
        'results': results.map((r) => r.toJson()).toList(),
      };
}

/// Individual Test Result
class E2ETestResult {
  final String testName;
  final String category;
  final bool passed;
  final Duration duration;
  final String? errorMessage;
  final String? stackTrace;
  final String? screenshotPath;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  E2ETestResult({
    required this.testName,
    required this.category,
    required this.passed,
    required this.duration,
    this.errorMessage,
    this.stackTrace,
    this.screenshotPath,
    this.metadata,
  }) : timestamp = DateTime.now();

  Map<String, dynamic> toJson() => {
        'testName': testName,
        'category': category,
        'passed': passed,
        'duration': duration.inMilliseconds,
        'errorMessage': errorMessage,
        'stackTrace': stackTrace,
        'screenshotPath': screenshotPath,
        'timestamp': timestamp.toIso8601String(),
        'metadata': metadata,
      };

  @override
  String toString() {
    final status = passed ? '✅ PASS' : '❌ FAIL';
    return '$status | $testName (${duration.inMilliseconds}ms)';
  }
}

/// Full Test Report
class E2ETestReport {
  final String reportId;
  final DateTime startTime;
  DateTime? endTime;
  final String environment;
  final List<E2ETestResult> results;

  E2ETestReport({
    DateTime? startTime,
    this.endTime,
    this.environment = 'E2E Test',
  })  : reportId = 'E2E_${DateTime.now().millisecondsSinceEpoch}',
        startTime = startTime ?? DateTime.now(),
        results = [];

  void addResult(E2ETestResult result) {
    results.add(result);
  }

  int get totalTests => results.length;
  int get passedCount => results.where((r) => r.passed).length;
  int get failedCount => results.where((r) => !r.passed).length;
  double get successRate =>
      totalTests > 0 ? (passedCount / totalTests) * 100 : 0;
  Duration get totalDuration =>
      (endTime ?? DateTime.now()).difference(startTime);

  Map<String, dynamic> toJson() => {
        'reportId': reportId,
        'environment': environment,
        'startTime': startTime.toIso8601String(),
        'endTime': (endTime ?? DateTime.now()).toIso8601String(),
        'totalDuration': totalDuration.inSeconds,
        'summary': {
          'totalTests': totalTests,
          'passedTests': passedCount,
          'failedTests': failedCount,
          'passRate': successRate.toStringAsFixed(2),
        },
        'results': results.map((r) => r.toJson()).toList(),
      };

  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());

  Future<void> saveToFile() async {
    await E2ETestConfig.ensureDirectories();

    // Save JSON
    final jsonFile = File(E2ETestConfig.jsonReportFile);
    await jsonFile.writeAsString(toJsonString());

    // Save HTML
    final htmlFile = File(E2ETestConfig.htmlReportFile);
    await htmlFile.writeAsString(toHtmlReport());
  }

  String toHtmlReport() {
    final buffer = StringBuffer();
    buffer.writeln('''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>E2E Test Report - Zyppi Ride</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: #f5f5f5; color: #333; }
        .container { max-width: 1200px; margin: 0 auto; padding: 20px; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; border-radius: 10px; margin-bottom: 20px; }
        .header h1 { font-size: 28px; margin-bottom: 10px; }
        .header p { opacity: 0.9; }
        .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin-bottom: 30px; }
        .summary-card { background: white; padding: 20px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); text-align: center; }
        .summary-card.passed { border-left: 4px solid #4CAF50; }
        .summary-card.failed { border-left: 4px solid #f44336; }
        .summary-card.total { border-left: 4px solid #2196F3; }
        .summary-card.rate { border-left: 4px solid #FF9800; }
        .summary-card h3 { font-size: 32px; margin-bottom: 5px; }
        .summary-card p { color: #666; font-size: 14px; }
        .test-section { background: white; border-radius: 10px; margin-bottom: 20px; overflow: hidden; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .section-header { padding: 15px 20px; background: #f8f9fa; border-bottom: 1px solid #eee; }
        .section-header h2 { font-size: 18px; }
        .test-list { padding: 0; }
        .test-item { display: flex; justify-content: space-between; align-items: center; padding: 12px 20px; border-bottom: 1px solid #eee; }
        .test-item:last-child { border-bottom: none; }
        .test-item.pass { background: #f1f8e9; }
        .test-item.fail { background: #ffebee; }
        .test-name { flex: 1; }
        .test-category { color: #666; font-size: 12px; margin-right: 15px; padding: 2px 8px; background: #e0e0e0; border-radius: 10px; }
        .test-duration { color: #999; font-size: 12px; margin-right: 15px; }
        .test-status { width: 24px; height: 24px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: 14px; }
        .test-status.pass { background: #4CAF50; color: white; }
        .test-status.fail { background: #f44336; color: white; }
        .error-message { color: #f44336; font-size: 12px; margin-top: 5px; padding: 10px; background: #ffebee; border-radius: 5px; }
        .footer { text-align: center; padding: 20px; color: #666; font-size: 12px; }
        .progress-bar { height: 8px; background: #e0e0e0; border-radius: 4px; overflow: hidden; margin-top: 10px; }
        .progress-fill { height: 100%; background: linear-gradient(90deg, #4CAF50, #8BC34A); border-radius: 4px; transition: width 0.3s; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Zyppi Ride E2E Test Report</h1>
            <p>Report ID: $reportId</p>
            <p>Generated: ${DateTime.now().toString()}</p>
            <p>Duration: ${totalDuration.inMinutes}m ${totalDuration.inSeconds % 60}s</p>
        </div>

        <div class="summary">
            <div class="summary-card total">
                <h3>$totalTests</h3>
                <p>Total Tests</p>
            </div>
            <div class="summary-card passed">
                <h3>$passedCount</h3>
                <p>Passed</p>
            </div>
            <div class="summary-card failed">
                <h3>$failedCount</h3>
                <p>Failed</p>
            </div>
            <div class="summary-card rate">
                <h3>${successRate.toStringAsFixed(1)}%</h3>
                <p>Pass Rate</p>
                <div class="progress-bar">
                    <div class="progress-fill" style="width: $successRate%"></div>
                </div>
            </div>
        </div>

        <div class="test-section">
            <div class="section-header">
                <h2>Test Results</h2>
            </div>
            <div class="test-list">
''');

    // Add test results
    for (final result in results) {
      final statusClass = result.passed ? 'pass' : 'fail';
      final statusIcon = result.passed ? '✓' : '✗';

      buffer.writeln('''
                <div class="test-item $statusClass">
                    <div class="test-name">
                        <strong>${result.testName}</strong>
                        ${!result.passed && result.errorMessage != null ? '<div class="error-message">${_escapeHtml(result.errorMessage!)}</div>' : ''}
                    </div>
                    <span class="test-category">${result.category}</span>
                    <span class="test-duration">${result.duration.inMilliseconds}ms</span>
                    <div class="test-status $statusClass">$statusIcon</div>
                </div>
''');
    }

    buffer.writeln('''
            </div>
        </div>

        <div class="footer">
            <p>Zyppi Ride E2E Test Framework | Generated automatically</p>
        </div>
    </div>
</body>
</html>
''');

    return buffer.toString();
  }

  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;');
  }
}
