// integration_test/app_test.dart
// Main E2E Test Runner for Zyppi Ride Android App

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// Test configuration and utilities
import 'test_report_generator.dart';
import 'mocks/mock_firebase_service.dart';

// Test suites
import 'tests/auth_test.dart';
import 'tests/vehicle_management_test.dart';
import 'tests/user_dashboard_test.dart';
import 'tests/driver_dashboard_test.dart';
import 'tests/booking_flow_test.dart';
import 'tests/database_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Zyppi Ride E2E Tests', () {
    late MockFirebaseService mockFirebase;
    late TestRunner testRunner;

    setUpAll(() async {
      // Initialize mock Firebase
      mockFirebase = MockFirebaseService();
      await mockFirebase.initializeTestData();

      // Initialize test runner
      testRunner = TestRunner();
      testRunner.reportGenerator.setDeviceInfo('Android Test Device');
      testRunner.reportGenerator.setAppVersion('1.0.0');

      print('\n');
      print('╔════════════════════════════════════════════════════════════╗');
      print('║          ZYPPI RIDE E2E TEST SUITE                         ║');
      print('║          Android Application Testing                       ║');
      print('╚════════════════════════════════════════════════════════════╝');
      print('\n');
    });

    tearDownAll(() async {
      // Generate and save reports
      final outputDir = 'test_reports';
      final reportPaths = await testRunner.finishAndGenerateReports(outputDir);

      print('\n');
      print('╔════════════════════════════════════════════════════════════╗');
      print('║                  TEST REPORTS GENERATED                     ║');
      print('╠════════════════════════════════════════════════════════════╣');
      print('║  HTML:     ${reportPaths['html']}');
      print('║  JSON:     ${reportPaths['json']}');
      print('║  Markdown: ${reportPaths['markdown']}');
      print('║  JUnit:    ${reportPaths['junit']}');
      print('╚════════════════════════════════════════════════════════════╝');
      print('\n');
    });

    // ==========================================
    // AUTHENTICATION TESTS
    // ==========================================
    testWidgets('Authentication Flow Tests', (WidgetTester tester) async {
      final authTests = AuthTests(
        testRunner: testRunner,
        mockFirebase: mockFirebase,
      );
      await authTests.runAllTests(tester);
    });

    // ==========================================
    // VEHICLE MANAGEMENT TESTS
    // ==========================================
    testWidgets('Vehicle Management Tests', (WidgetTester tester) async {
      final vehicleTests = VehicleManagementTests(
        testRunner: testRunner,
        mockFirebase: mockFirebase,
      );
      await vehicleTests.runAllTests(tester);
    });

    // ==========================================
    // USER DASHBOARD TESTS
    // ==========================================
    testWidgets('User Dashboard Tests', (WidgetTester tester) async {
      final userDashboardTests = UserDashboardTests(
        testRunner: testRunner,
        mockFirebase: mockFirebase,
      );
      await userDashboardTests.runAllTests(tester);
    });

    // ==========================================
    // DRIVER/OWNER DASHBOARD TESTS
    // ==========================================
    testWidgets('Driver/Owner Dashboard Tests', (WidgetTester tester) async {
      final driverDashboardTests = DriverDashboardTests(
        testRunner: testRunner,
        mockFirebase: mockFirebase,
      );
      await driverDashboardTests.runAllTests(tester);
    });

    // ==========================================
    // BOOKING FLOW TESTS
    // ==========================================
    testWidgets('Booking Flow Tests', (WidgetTester tester) async {
      final bookingTests = BookingFlowTests(
        testRunner: testRunner,
        mockFirebase: mockFirebase,
      );
      await bookingTests.runAllTests(tester);
    });

    // ==========================================
    // DATABASE INTERACTION TESTS
    // ==========================================
    testWidgets('Database Interaction Tests', (WidgetTester tester) async {
      final databaseTests = DatabaseTests(
        testRunner: testRunner,
        mockFirebase: mockFirebase,
      );
      await databaseTests.runAllTests(tester);
    });
  });
}

/// Standalone test runner for quick execution
class ZyppiRideTestRunner {
  final MockFirebaseService _mockFirebase;
  final TestRunner _testRunner;

  ZyppiRideTestRunner()
      : _mockFirebase = MockFirebaseService(),
        _testRunner = TestRunner();

  Future<void> initialize() async {
    await _mockFirebase.initializeTestData();
    _testRunner.reportGenerator.setDeviceInfo('Android Test Device');
    _testRunner.reportGenerator.setAppVersion('1.0.0');
  }

  TestRunner get testRunner => _testRunner;
  MockFirebaseService get mockFirebase => _mockFirebase;

  Future<Map<String, String>> generateReports(String outputDir) async {
    return await _testRunner.finishAndGenerateReports(outputDir);
  }
}

/// Quick test function for individual test suite
Future<void> runQuickTest(String suiteName) async {
  final runner = ZyppiRideTestRunner();
  await runner.initialize();

  print('Running quick test: $suiteName');

  switch (suiteName.toLowerCase()) {
    case 'auth':
      // Run auth tests only
      break;
    case 'vehicle':
      // Run vehicle tests only
      break;
    case 'booking':
      // Run booking tests only
      break;
    case 'database':
      // Run database tests only
      break;
    default:
      print('Unknown test suite: $suiteName');
  }

  await runner.generateReports('test_reports');
}
