# Zyppi Ride E2E Testing Framework

## Overview

This E2E (End-to-End) testing framework provides comprehensive automated testing for the Zyppi Ride Flutter application. It tests complete user journeys for both **Drivers** and **Owners** including registration, login, dashboard features, and vehicle management.

## Features

- ✅ **TEST MODE Flag** - Isolated test environment via `--dart-define`
- ✅ **Separate Firebase Collections** - Test data uses prefixed collections
- ✅ **5 Fixed Test Users** - 3 Drivers + 2 Owners with consistent credentials
- ✅ **Bypass Verification** - Skip OTP/email verification in test mode
- ✅ **Screenshot on Failure** - Automatic screenshot capture
- ✅ **JSON + HTML Reports** - Detailed test reports with styling
- ✅ **Loop-based Execution** - Tests run for all 5 users sequentially

## Test Users

Using [Mailinator.com](https://www.mailinator.com/) for real email testing. Check inbox at `https://www.mailinator.com/v4/public/inboxes.jsp?to=<username>`

| # | Name | Email | Role | Password |
|---|------|-------|------|----------|
| 1 | Test Driver One | zyppi.driver1@mailinator.com | Driver | TestDriver@001 |
| 2 | Test Driver Two | zyppi.driver2@mailinator.com | Driver | TestDriver@002 |
| 3 | Test Owner One | zyppi.owner1@mailinator.com | Owner | TestOwner@001 |
| 4 | Test Owner Two | zyppi.owner2@mailinator.com | Owner | TestOwner@002 |
| 5 | Test Owner Three | zyppi.owner3@mailinator.com | Owner | TestOwner@003 |

## Test Vehicles (for Owners)

| # | Registration | Brand | Model | Type |
|---|--------------|-------|-------|------|
| 1 | E2E-TEST-001 | Maruti | Swift Dzire | Sedan |
| 2 | E2E-TEST-002 | Hyundai | i20 | Hatchback |
| 3 | E2E-TEST-003 | Toyota | Innova | SUV |
| 4 | E2E-TEST-004 | Honda | City | Sedan |
| 5 | E2E-TEST-005 | Tata | Nexon | SUV |

## Directory Structure

```
integration_test/
└── e2e/
    ├── README.md                          # This file
    ├── run_e2e_tests.sh                   # Shell script runner
    ├── e2e_main_test.dart                 # Main test orchestrator
    ├── config/
    │   └── e2e_test_config.dart           # Test configuration & users
    ├── helpers/
    │   ├── firebase_test_helper.dart      # Firebase operations
    │   └── widget_test_helper.dart        # Widget interaction helpers
    └── tests/
        ├── auth_registration_tests.dart   # Registration flow tests
        ├── auth_login_tests.dart          # Login/logout flow tests
        ├── vehicle_registration_tests.dart # Vehicle management tests
        └── driver_flow_tests.dart         # Driver-specific tests
```

## Running Tests

### Quick Start

```bash
# Make the script executable
chmod +x integration_test/e2e/run_e2e_tests.sh

# Run on Android
./integration_test/e2e/run_e2e_tests.sh --android

# Run on iOS
./integration_test/e2e/run_e2e_tests.sh --ios
```

### Using Flutter Commands Directly

```bash
# Run on Android emulator
flutter test integration_test/e2e/e2e_main_test.dart \
  --dart-define=E2E_TEST_MODE=true \
  -d <emulator-id>

# Run on iOS simulator
flutter test integration_test/e2e/e2e_main_test.dart \
  --dart-define=E2E_TEST_MODE=true \
  -d <simulator-id>

# Run with verbose output
flutter test integration_test/e2e/e2e_main_test.dart \
  --dart-define=E2E_TEST_MODE=true \
  --verbose
```

### Script Options

```bash
./run_e2e_tests.sh [OPTIONS]

Options:
  --android     Run on Android device/emulator (default)
  --ios         Run on iOS device/simulator
  --device ID   Specify device ID
  --clean       Clean build before running
  --verbose     Verbose output
  --help        Show help message
```

## Test Reports

After running tests, reports are generated in:

```
test_results/
├── reports/
│   ├── latest_report.json        # Latest JSON report
│   ├── latest_report.html        # Latest HTML report
│   ├── e2e_report_<timestamp>.json
│   └── e2e_report_<timestamp>.html
└── screenshots/
    └── FAILURE_<test_name>_<timestamp>.png
```

### JSON Report Structure

```json
{
  "testRun": "2024-01-15T10:30:00.000Z",
  "environment": "E2E_TEST",
  "totalTests": 25,
  "passed": 24,
  "failed": 1,
  "successRate": 96.0,
  "duration": "PT3M45S",
  "results": [
    {
      "testName": "Successful User Login",
      "category": "Login/Success",
      "passed": true,
      "duration": "PT2.5S",
      "errorMessage": null,
      "screenshotPath": null
    }
  ]
}
```

### HTML Report

The HTML report includes:
- Summary statistics with visual indicators
- Success/failure badges for each test
- Duration information
- Error messages for failed tests
- Links to failure screenshots

## Firebase Collections

Test data is isolated using collection prefixes:

| Production Collection | Test Collection |
|-----------------------|-----------------|
| `users` | `e2e_test_users` |
| `vehicles` | `e2e_test_vehicles` |
| `bookings` | `e2e_test_bookings` |
| `drivers` | `e2e_test_drivers` |

## Test Coverage

### Authentication Tests
- Navigate to Registration Screen
- Registration Form Validation
- Successful User Registration
- Role Selection After Registration
- Verify Firestore User Document
- Navigate to Login Screen
- Login Form Validation
- Successful User Login
- Verify Role-Based Dashboard
- Verify User Session Persistence
- User Logout
- Re-Login After Logout

### Dashboard Tests
- Dashboard Loads Successfully
- Online/Offline Toggle (Drivers)
- Dashboard Navigation Tiles
- Profile Screen Access

### Vehicle Management Tests (Owners)
- Navigate to Vehicle Registration
- Vehicle Form Validation
- Fill Vehicle Details Form
- Submit Vehicle Registration
- Verify Vehicle in Firestore
- Vehicle List Display

### Driver-Specific Tests
- Navigate to Driver Booking Dashboard
- Online/Offline Toggle
- View Pending Bookings
- Profile Verification Status
- Earnings Display

## Customization

### Adding New Test Users

Edit `integration_test/e2e/config/e2e_test_config.dart`:

```dart
static final List<E2ETestUser> testUsers = [
  // Add new users here
  E2ETestUser(
    email: 'new.user@zyppiride.test',
    password: 'SecurePassword123',
    fullName: 'New Test User',
    phone: '+919999999999',
    role: TestUserRole.driver,
  ),
];
```

### Adding New Test Suites

1. Create a new file in `integration_test/e2e/tests/`
2. Create a test suite class extending the pattern:

```dart
class MyNewTestSuite {
  final WidgetTestHelper widgetHelper;
  final FirebaseTestHelper firebaseHelper;
  final E2ETestContext context;
  late E2ETestRunner runner;

  MyNewTestSuite({...}) {
    runner = E2ETestRunner(widgetHelper, context);
  }

  Future<void> runAllTests() async {
    await _testMyFeature();
  }

  Future<void> _testMyFeature() async {
    await runner.runTest(
      name: 'My Feature Test',
      category: 'MyFeature/Test',
      testFunction: () async {
        // Test implementation
      },
    );
  }
}
```

3. Import and run in `e2e_main_test.dart`

## Troubleshooting

### Tests Not Finding Widgets

The test helpers use multiple finder strategies. If widgets aren't found:
1. Add widget keys to your UI code
2. Add new finder strategies to the test helpers

### Firebase Permission Errors

Ensure your `firestore.rules` allow access to test collections:

```javascript
match /e2e_test_{collection}/{document=**} {
  allow read, write: if true; // For testing only
}
```

### Screenshots Not Saving

Check that the app has storage permissions and the directories exist:

```bash
mkdir -p test_results/screenshots
mkdir -p test_results/reports
```

## Best Practices

1. **Run on Emulator/Simulator** - Physical devices may have timing issues
2. **Use Clean State** - Run with `--clean` for consistent results
3. **Check Firestore Rules** - Ensure test collections are accessible
4. **Review HTML Reports** - Use the visual report for quick failure analysis
5. **Keep Test Data Isolated** - Always use the test collection prefix

## Contributing

When adding new tests:
1. Follow the existing test suite patterns
2. Add comprehensive logging
3. Include screenshot capture on failures
4. Update this README with new test coverage
