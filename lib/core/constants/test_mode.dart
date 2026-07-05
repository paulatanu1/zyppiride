// lib/core/constants/test_mode.dart
// Test Mode Detection for E2E Testing

/// Check if app is running in E2E test mode
/// Pass --dart-define=E2E_TEST_MODE=true when running tests
class TestMode {
  static const bool isE2ETestMode =
      bool.fromEnvironment('E2E_TEST_MODE', defaultValue: false);

  static const String testCollectionPrefix =
      String.fromEnvironment('TEST_COLLECTION_PREFIX', defaultValue: 'e2e_test_');

  /// Firebase collection names for test mode
  static String get usersCollection =>
      isE2ETestMode ? '${testCollectionPrefix}users' : 'users';

  static String get vehiclesCollection =>
      isE2ETestMode ? '${testCollectionPrefix}vehicles' : 'vehicles';

  static String get bookingsCollection =>
      isE2ETestMode ? '${testCollectionPrefix}bookings' : 'bookings';

  static String get driversCollection =>
      isE2ETestMode ? '${testCollectionPrefix}drivers' : 'drivers';

  static String get agreementsCollection =>
      isE2ETestMode ? '${testCollectionPrefix}agreements' : 'agreements';

  static String get complaintsCollection =>
      isE2ETestMode ? '${testCollectionPrefix}complaints' : 'complaints';

  static String get feedbacksCollection =>
      isE2ETestMode ? '${testCollectionPrefix}feedbacks' : 'feedbacks';

  /// Skip OTP verification in test mode
  static bool get skipOtpVerification => isE2ETestMode;

  /// Skip email verification in test mode
  static bool get skipEmailVerification => isE2ETestMode;

  /// Use test Firebase Auth
  static bool get useTestAuth => isE2ETestMode;

  /// Log test mode status
  static void logTestMode() {
    if (isE2ETestMode) {
      // ignore: avoid_print
      print('========================================');
      // ignore: avoid_print
      print('RUNNING IN E2E TEST MODE');
      // ignore: avoid_print
      print('Collection prefix: $testCollectionPrefix');
      // ignore: avoid_print
      print('Skip OTP: $skipOtpVerification');
      // ignore: avoid_print
      print('Skip Email Verification: $skipEmailVerification');
      // ignore: avoid_print
      print('========================================');
    }
  }
}
