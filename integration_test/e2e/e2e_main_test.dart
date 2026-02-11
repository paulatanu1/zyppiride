// integration_test/e2e/e2e_main_test.dart
// Main E2E Test Runner - Complete User Journey Tests

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:zyppi_ride/main.dart' as app;

import 'config/e2e_test_config.dart';
import 'helpers/firebase_test_helper.dart';
import 'helpers/widget_test_helper.dart';
import 'tests/complete_flow_tests.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('E2E Test Suite - Complete User Journey', () {
    late FirebaseTestHelper firebaseHelper;
    E2ETestReport? testReport;

    setUpAll(() async {
      // Initialize Firebase
      await Firebase.initializeApp();

      // Initialize helpers
      firebaseHelper = FirebaseTestHelper();
      testReport = E2ETestReport();

      // Try to create test directories
      try {
        await E2ETestConfig.ensureDirectories();
      } catch (e) {
        debugPrint('Warning: Could not create test directories: $e');
      }

      // Print test mode info
      debugPrint('═══════════════════════════════════════════');
      debugPrint('   ZYPPI RIDE E2E TEST SUITE');
      debugPrint('   Running in: ${E2ETestConfig.testEnvironment}');
      debugPrint('   Test Users: ${E2ETestConfig.testUsers.length}');
      debugPrint('═══════════════════════════════════════════');
    });

    tearDownAll(() async {
      if (testReport != null) {
        try {
          await _generateReports(testReport!);
        } catch (e) {
          debugPrint('Warning: Could not save reports: $e');
        }

        if (E2ETestConfig.cleanupAfterTests) {
          debugPrint('\n🧹 Cleaning up test data...');
          await firebaseHelper.cleanupAllTestData();
        }

        debugPrint('\n═══════════════════════════════════════════');
        debugPrint('   TEST SUITE COMPLETE');
        debugPrint('   Total: ${testReport!.results.length}');
        debugPrint('   Passed: ${testReport!.passedCount}');
        debugPrint('   Failed: ${testReport!.failedCount}');
        debugPrint('   Success Rate: ${testReport!.successRate.toStringAsFixed(1)}%');
        debugPrint('═══════════════════════════════════════════');
      }
    });

    // ========================================
    // RUN TESTS FOR EACH USER
    // ========================================

    for (int i = 0; i < E2ETestConfig.testUsers.length; i++) {
      final testUser = E2ETestConfig.testUsers[i];
      final testVehicle = E2ETestConfig.testVehicles[i];

      group('User ${i + 1}: ${testUser.fullName} (${testUser.roleString})', () {
        late E2ETestContext context;
        late WidgetTestHelper widgetHelper;

        setUp(() {
          context = E2ETestContext(currentUser: testUser);
        });

        // ========================================
        // COMPLETE REGISTRATION FLOW
        // ========================================
        testWidgets(
          'Complete Registration Flow',
          (WidgetTester tester) async {
            widgetHelper = WidgetTestHelper(tester);

            debugPrint('\n');
            debugPrint('══════════════════════════════════════════════════════');
            debugPrint('  📋 REGISTRATION FLOW: ${testUser.fullName}');
            debugPrint('  📧 Email: ${testUser.email}');
            debugPrint('  👤 Role: ${testUser.roleString}');
            debugPrint('══════════════════════════════════════════════════════');

            // Launch app
            app.main();
            await widgetHelper.pumpAndSettle(timeout: E2ETestConfig.longTimeout);

            // Run complete registration flow
            final registrationFlow = CompleteRegistrationFlowTests(
              widgetHelper: widgetHelper,
              firebaseHelper: firebaseHelper,
              context: context,
            );

            await registrationFlow.runAllTests();

            // Copy results to main report
            for (final result in context.results) {
              testReport?.addResult(result);
            }

            // Logout for next test
            await firebaseHelper.logout();
            await widgetHelper.pumpAndSettle();
          },
          timeout: const Timeout(Duration(minutes: 5)),
        );

        // ========================================
        // LOGIN FLOW (after registration)
        // ========================================
        testWidgets(
          'Complete Login Flow',
          (WidgetTester tester) async {
            widgetHelper = WidgetTestHelper(tester);
            context.results.clear();

            debugPrint('\n');
            debugPrint('══════════════════════════════════════════════════════');
            debugPrint('  🔐 LOGIN FLOW: ${testUser.fullName}');
            debugPrint('══════════════════════════════════════════════════════');

            // Launch app
            app.main();
            await widgetHelper.pumpAndSettle(timeout: E2ETestConfig.longTimeout);

            // Run login flow
            final loginFlow = CompleteLoginFlowTests(
              widgetHelper: widgetHelper,
              firebaseHelper: firebaseHelper,
              context: context,
            );

            await loginFlow.runAllTests();

            // Copy results to main report
            for (final result in context.results) {
              testReport?.addResult(result);
            }
          },
          timeout: const Timeout(Duration(minutes: 5)),
        );

        // ========================================
        // ROLE-SPECIFIC DASHBOARD TESTS
        // ========================================
        if (testUser.role == TestUserRole.driver) {
          testWidgets(
            'Driver Dashboard Flow',
            (WidgetTester tester) async {
              widgetHelper = WidgetTestHelper(tester);
              context.results.clear();

              debugPrint('\n');
              debugPrint('══════════════════════════════════════════════════════');
              debugPrint('  🚗 DRIVER DASHBOARD: ${testUser.fullName}');
              debugPrint('══════════════════════════════════════════════════════');

              // Ensure logged in
              if (!firebaseHelper.isLoggedIn) {
                await firebaseHelper.loginUser(testUser);
              }

              // Launch app
              app.main();
              await widgetHelper.pumpAndSettle(timeout: E2ETestConfig.longTimeout);

              // Run driver flow
              final driverFlow = DriverDashboardFlowTests(
                widgetHelper: widgetHelper,
                firebaseHelper: firebaseHelper,
                context: context,
              );

              await driverFlow.runAllTests();

              // Copy results
              for (final result in context.results) {
                testReport?.addResult(result);
              }
            },
            timeout: const Timeout(Duration(minutes: 5)),
          );
        }

        if (testUser.role == TestUserRole.owner) {
          testWidgets(
            'Owner Dashboard & Vehicle Registration Flow',
            (WidgetTester tester) async {
              widgetHelper = WidgetTestHelper(tester);
              context.results.clear();

              debugPrint('\n');
              debugPrint('══════════════════════════════════════════════════════');
              debugPrint('  🚙 OWNER DASHBOARD: ${testUser.fullName}');
              debugPrint('  🚗 Test Vehicle: ${testVehicle.registrationNumber}');
              debugPrint('══════════════════════════════════════════════════════');

              // Ensure logged in
              if (!firebaseHelper.isLoggedIn) {
                await firebaseHelper.loginUser(testUser);
              }

              // Launch app
              app.main();
              await widgetHelper.pumpAndSettle(timeout: E2ETestConfig.longTimeout);

              // Run owner flow
              final ownerFlow = OwnerDashboardFlowTests(
                widgetHelper: widgetHelper,
                firebaseHelper: firebaseHelper,
                context: context,
                testVehicle: testVehicle,
              );

              await ownerFlow.runAllTests();

              // Copy results
              for (final result in context.results) {
                testReport?.addResult(result);
              }
            },
            timeout: const Timeout(Duration(minutes: 5)),
          );
        }

        // ========================================
        // LOGOUT FLOW
        // ========================================
        testWidgets(
          'Logout Flow',
          (WidgetTester tester) async {
            widgetHelper = WidgetTestHelper(tester);
            context.results.clear();

            debugPrint('\n');
            debugPrint('══════════════════════════════════════════════════════');
            debugPrint('  🚪 LOGOUT: ${testUser.fullName}');
            debugPrint('══════════════════════════════════════════════════════');

            // Ensure logged in
            if (!firebaseHelper.isLoggedIn) {
              await firebaseHelper.loginUser(testUser);
            }

            // Launch app
            app.main();
            await widgetHelper.pumpAndSettle(timeout: E2ETestConfig.longTimeout);

            // Run logout flow
            final logoutFlow = LogoutFlowTests(
              widgetHelper: widgetHelper,
              firebaseHelper: firebaseHelper,
              context: context,
            );

            await logoutFlow.runLogout();

            // Copy results
            for (final result in context.results) {
              testReport?.addResult(result);
            }

            debugPrint('\n✅ Completed all tests for: ${testUser.fullName}');
          },
          timeout: const Timeout(Duration(minutes: 5)),
        );
      });
    }
  });
}

/// Generate JSON and HTML reports
Future<void> _generateReports(E2ETestReport report) async {
  // Print JSON report to console with clear separation
  debugPrint('\n════════════════════════════════════════════');
  debugPrint('   E2E TEST REPORT (JSON)');
  debugPrint('════════════════════════════════════════════');

  // Use print() for markers and JSON to ensure clean output
  // ignore: avoid_print
  print('<!-- BEGIN_JSON_REPORT -->');

  // Print JSON line by line to avoid buffer issues
  final jsonLines = report.toJsonString().split('\n');
  for (final line in jsonLines) {
    // ignore: avoid_print
    print(line);
  }

  // ignore: avoid_print
  print('<!-- END_JSON_REPORT -->');

  // Print summary
  debugPrint('\n════════════════════════════════════════════');
  debugPrint('   TEST RESULTS SUMMARY');
  debugPrint('════════════════════════════════════════════');

  for (final result in report.results) {
    final status = result.passed ? '✅' : '❌';
    debugPrint('$status ${result.testName} (${result.duration.inMilliseconds}ms)');
    if (!result.passed && result.errorMessage != null) {
      debugPrint('   Error: ${result.errorMessage}');
    }
  }

  debugPrint('\n════════════════════════════════════════════');
}
