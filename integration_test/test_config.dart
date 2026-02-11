// integration_test/test_config.dart
// E2E Test Configuration for Zyppi Ride App

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Test configuration constants
class TestConfig {
  // Test user credentials
  static const testUserEmail = 'testuser@zyppiride.com';
  static const testUserPassword = 'Test@123456';
  static const testUserPhone = '+919876543210';
  static const testUserName = 'Test User';

  // Test driver credentials
  static const testDriverEmail = 'testdriver@zyppiride.com';
  static const testDriverPassword = 'Driver@123456';
  static const testDriverPhone = '+919876543211';
  static const testDriverName = 'Test Driver';

  // Test owner credentials
  static const testOwnerEmail = 'testowner@zyppiride.com';
  static const testOwnerPassword = 'Owner@123456';
  static const testOwnerPhone = '+919876543212';
  static const testOwnerName = 'Test Owner';

  // Test vehicle data
  static const testVehicleRegistration = 'KA01AB1234';
  static const testVehicleMake = 'Maruti';
  static const testVehicleModel = 'Swift';
  static const testVehicleType = 'Hatchback';

  // Timeouts
  static const Duration shortTimeout = Duration(seconds: 5);
  static const Duration mediumTimeout = Duration(seconds: 15);
  static const Duration longTimeout = Duration(seconds: 30);
  static const Duration veryLongTimeout = Duration(seconds: 60);

  // Test report path
  static const String reportPath = 'test_reports';
}

/// Test result model for reporting
class TestResult {
  final String testName;
  final String category;
  final bool passed;
  final Duration duration;
  final String? errorMessage;
  final String? stackTrace;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  TestResult({
    required this.testName,
    required this.category,
    required this.passed,
    required this.duration,
    this.errorMessage,
    this.stackTrace,
    DateTime? timestamp,
    this.metadata,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'testName': testName,
        'category': category,
        'passed': passed,
        'duration': duration.inMilliseconds,
        'errorMessage': errorMessage,
        'stackTrace': stackTrace,
        'timestamp': timestamp.toIso8601String(),
        'metadata': metadata,
      };

  @override
  String toString() {
    final status = passed ? 'PASSED' : 'FAILED';
    final durationStr = '${duration.inMilliseconds}ms';
    return '[$status] $testName ($durationStr)${errorMessage != null ? '\n  Error: $errorMessage' : ''}';
  }
}

/// Test suite result for grouping tests
class TestSuiteResult {
  final String suiteName;
  final List<TestResult> results;
  final DateTime startTime;
  final DateTime endTime;

  TestSuiteResult({
    required this.suiteName,
    required this.results,
    required this.startTime,
    required this.endTime,
  });

  int get totalTests => results.length;
  int get passedTests => results.where((r) => r.passed).length;
  int get failedTests => results.where((r) => !r.passed).length;
  double get passRate => totalTests > 0 ? (passedTests / totalTests) * 100 : 0;
  Duration get totalDuration => endTime.difference(startTime);

  Map<String, dynamic> toJson() => {
        'suiteName': suiteName,
        'totalTests': totalTests,
        'passedTests': passedTests,
        'failedTests': failedTests,
        'passRate': passRate,
        'totalDuration': totalDuration.inMilliseconds,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'results': results.map((r) => r.toJson()).toList(),
      };
}

/// Test keys for finding widgets
class TestKeys {
  // Auth Screen Keys
  static const loginButton = Key('login_button');
  static const registerButton = Key('register_button');
  static const emailField = Key('email_field');
  static const passwordField = Key('password_field');
  static const phoneField = Key('phone_field');
  static const otpField = Key('otp_field');
  static const submitButton = Key('submit_button');
  static const googleSignInButton = Key('google_signin_button');
  static const forgotPasswordButton = Key('forgot_password_button');

  // Dashboard Keys
  static const userDashboard = Key('user_dashboard');
  static const driverDashboard = Key('driver_dashboard');
  static const ownerDashboard = Key('owner_dashboard');
  static const profileButton = Key('profile_button');
  static const notificationButton = Key('notification_button');
  static const logoutButton = Key('logout_button');

  // Navigation Keys
  static const bottomNav = Key('bottom_navigation');
  static const homeTab = Key('home_tab');
  static const bookingsTab = Key('bookings_tab');
  static const historyTab = Key('history_tab');
  static const profileTab = Key('profile_tab');

  // Vehicle Keys
  static const vehicleListScreen = Key('vehicle_list_screen');
  static const addVehicleButton = Key('add_vehicle_button');
  static const vehicleCard = Key('vehicle_card');
  static const vehicleRegistrationField = Key('vehicle_registration_field');
  static const vehicleMakeDropdown = Key('vehicle_make_dropdown');
  static const vehicleModelDropdown = Key('vehicle_model_dropdown');
  static const vehicleTypeDropdown = Key('vehicle_type_dropdown');

  // Booking Keys
  static const bookingCard = Key('booking_card');
  static const pickupLocationField = Key('pickup_location_field');
  static const dropLocationField = Key('drop_location_field');
  static const bookNowButton = Key('book_now_button');
  static const cancelBookingButton = Key('cancel_booking_button');

  // Profile Keys
  static const profileScreen = Key('profile_screen');
  static const editProfileButton = Key('edit_profile_button');
  static const nameField = Key('name_field');
  static const saveButton = Key('save_button');

  // Availability Keys
  static const availabilityScreen = Key('availability_screen');
  static const onlineToggle = Key('online_toggle');
  static const workingHoursSection = Key('working_hours_section');
}

/// Widget finder helpers
extension WidgetTesterExtensions on WidgetTester {
  /// Find widget by key with timeout
  Future<Finder> findByKeyWithTimeout(Key key,
      {Duration timeout = TestConfig.mediumTimeout}) async {
    final finder = find.byKey(key);
    await pumpAndSettle();
    return finder;
  }

  /// Tap widget by key
  Future<void> tapByKey(Key key) async {
    final finder = find.byKey(key);
    expect(finder, findsOneWidget);
    await tap(finder);
    await pumpAndSettle();
  }

  /// Enter text in field by key
  Future<void> enterTextByKey(Key key, String text) async {
    final finder = find.byKey(key);
    expect(finder, findsOneWidget);
    await enterText(finder, text);
    await pumpAndSettle();
  }

  /// Wait for widget to appear
  Future<bool> waitForWidget(Finder finder,
      {Duration timeout = TestConfig.mediumTimeout}) async {
    final endTime = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(endTime)) {
      await pump(const Duration(milliseconds: 100));
      if (finder.evaluate().isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  /// Take screenshot for report
  Future<List<int>> takeScreenshot() async {
    // This would be implemented with platform-specific screenshot capture
    // For now, return empty bytes
    return [];
  }
}

/// Mock data generators
class MockDataGenerator {
  static Map<String, dynamic> generateUserData({
    String? uid,
    String? email,
    String? name,
    String? phone,
    String? role,
  }) {
    return {
      'userId': uid ?? 'test_user_${DateTime.now().millisecondsSinceEpoch}',
      'email': email ?? TestConfig.testUserEmail,
      'fullName': name ?? TestConfig.testUserName,
      'mobile': phone ?? TestConfig.testUserPhone,
      'role': role ?? 'user',
      'createdAt': DateTime.now(),
      'profileImageUrl': null,
      'is_admin': false,
    };
  }

  static Map<String, dynamic> generateVehicleData({
    String? vehicleId,
    String? userId,
    String? registration,
    String? make,
    String? model,
    String? type,
  }) {
    return {
      'vehicleId':
          vehicleId ?? 'test_vehicle_${DateTime.now().millisecondsSinceEpoch}',
      'userId': userId ?? 'test_user_id',
      'vehicleDetails': {
        'registrationNumber':
            registration ?? TestConfig.testVehicleRegistration,
        'make': make ?? TestConfig.testVehicleMake,
        'model': model ?? TestConfig.testVehicleModel,
        'type': type ?? TestConfig.testVehicleType,
      },
      'documents': {
        'vehicleImages': [],
        'rcImages': [],
        'licenseImages': [],
        'insuranceImages': [],
        'pucImages': [],
      },
      'documentStatus': 'pending',
      'createdAt': DateTime.now(),
      'location': {
        'city': 'Bangalore',
        'state': 'Karnataka',
        'pincode': '560001',
      },
    };
  }

  static Map<String, dynamic> generateBookingData({
    String? bookingId,
    String? userId,
    String? vehicleId,
    String? driverId,
    String? status,
  }) {
    return {
      'bookingId':
          bookingId ?? 'test_booking_${DateTime.now().millisecondsSinceEpoch}',
      'userId': userId ?? 'test_user_id',
      'vehicleId': vehicleId ?? 'test_vehicle_id',
      'driverId': driverId,
      'status': status ?? 'pending',
      'pickup': {
        'address': '123 Test Street, Bangalore',
        'lat': 12.9716,
        'lng': 77.5946,
      },
      'drop': {
        'address': '456 Test Avenue, Bangalore',
        'lat': 12.9816,
        'lng': 77.6046,
      },
      'fare': 250.0,
      'createdAt': DateTime.now(),
    };
  }

  static Map<String, dynamic> generateOfferData({
    String? offerId,
    String? code,
    double? discountPercent,
  }) {
    return {
      'offerId':
          offerId ?? 'test_offer_${DateTime.now().millisecondsSinceEpoch}',
      'code': code ?? 'TEST20',
      'title': 'Test Offer',
      'description': '20% off on your first ride',
      'discountType': 'percentage',
      'discountValue': discountPercent ?? 20.0,
      'minBookingAmount': 100.0,
      'maxDiscount': 50.0,
      'validFrom': DateTime.now(),
      'validTo': DateTime.now().add(const Duration(days: 30)),
      'isActive': true,
    };
  }

  static Map<String, dynamic> generateBannerData({
    String? bannerId,
    String? title,
    bool? isActive,
  }) {
    return {
      'bannerId':
          bannerId ?? 'test_banner_${DateTime.now().millisecondsSinceEpoch}',
      'title': title ?? 'Test Banner',
      'subtitle': 'Test banner subtitle',
      'imageUrl': 'https://example.com/banner.jpg',
      'isActive': isActive ?? true,
      'order': 1,
      'targetType': 'screen',
      'targetValue': '/offers',
    };
  }

  static Map<String, dynamic> generateAvailabilityData({
    String? vehicleId,
    bool? isOnline,
    String? workingMode,
  }) {
    return {
      'vehicleId': vehicleId ?? 'test_vehicle_id',
      'isOnline': isOnline ?? true,
      'workingMode': workingMode ?? 'always_available',
      'customHours': workingMode == 'custom'
          ? {
              'startTime': '09:00',
              'endTime': '18:00',
            }
          : null,
      'lastUpdated': DateTime.now(),
    };
  }
}
