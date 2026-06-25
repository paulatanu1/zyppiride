# 14 — Testing Documentation

## Test surface

```
test/                       # Unit + widget tests (flutter_test)
integration_test/           # End-to-end tests (integration_test + flutter_driver)
  ├── e2e/                  # Full booking-flow E2E scenarios
  ├── mocks/                # Generated mocks (mockito @GenerateMocks)
  └── tests/                # Individual integration tests
test_driver/                # Flutter Driver scripts
test_reports/               # CI artefacts
test_results/               # CI artefacts
run_e2e_tests.sh            # Wrapper script (executable)
E2E_TESTING_DOCUMENTATION.md  # Existing in-depth E2E spec (preserved alongside)
```

## Test packages (`pubspec.yaml`)

| Package | Use |
|---|---|
| `flutter_test` (SDK) | Unit + widget tests |
| `integration_test` (SDK) | Drives the full app on a device |
| `flutter_driver` (SDK) | Imperative device control (used by `test_driver/`) |
| `mockito: ^5.4.4` | Mock generation |
| `build_runner: ^2.4.8` | Code generation for `@GenerateMocks` |
| `test: ^1.24.9` | Plain Dart tests |

## Generating mocks

After adding `@GenerateMocks([SomeService])` to a test file:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Mocks land in the same directory with `.mocks.dart` suffix.

## Running tests

```bash
# Unit + widget tests
flutter test

# Single file
flutter test test/path/to/some_test.dart

# Integration tests (default Firebase project)
flutter test integration_test/

# Integration tests in E2E test mode (isolated Firestore namespace)
flutter test integration_test/ --dart-define=E2E_TEST_MODE=true

# Wrapper script (provisions test mode + collects logs)
./run_e2e_tests.sh
```

## E2E test mode design

Source: `lib/core/constants/test_mode.dart`.

```dart
class TestMode {
  static const bool isE2ETestMode =
      bool.fromEnvironment('E2E_TEST_MODE', defaultValue: false);
  static const String testCollectionPrefix =
      String.fromEnvironment('TEST_COLLECTION_PREFIX', defaultValue: 'e2e_test_');

  static String get usersCollection      => isE2ETestMode ? '${testCollectionPrefix}users'      : 'users';
  static String get vehiclesCollection   => isE2ETestMode ? '${testCollectionPrefix}vehicles'   : 'vehicles';
  static String get bookingsCollection   => isE2ETestMode ? '${testCollectionPrefix}bookings'   : 'bookings';
  static String get driversCollection    => isE2ETestMode ? '${testCollectionPrefix}drivers'    : 'drivers';
  static bool   get skipOtpVerification  => isE2ETestMode;
  static bool   get skipEmailVerification => isE2ETestMode;
}
```

When enabled:
1. All service-layer Firestore calls hit `e2e_test_*` collections instead of production.
2. OTP and email-verification gates are bypassed (so the test harness doesn't need access to a real SMS / inbox).
3. Test data can be wiped between runs without touching production data.

## Recommended test pyramid

| Layer | Coverage target | Examples |
|---|---|---|
| **Unit** | `FareCalculator`, `Booking.fromMap` / `toMap` round-trips, `BookingStatus.fromString` | These are pure, no external deps — fast and high-coverage. |
| **Service** | `BookingService.createBooking` with mocked Firestore (mockito) | Verify status, OTP generation, fare calculation. |
| **Widget** | `BookingConfirmationSheet`, `DriverOnlineToggle` (test the eligibility gate) | Use `ProviderScope(overrides: [...])` to inject mocked notifiers. |
| **Integration** | Full booking flow: login → search → confirm → driver accept → start → complete | Requires E2E test mode + a seeded test driver/vehicle. |

## Existing integration-test layout

| Folder | Purpose |
|---|---|
| `integration_test/tests/` | Per-feature integration scenarios |
| `integration_test/e2e/` | Full end-to-end user journeys |
| `integration_test/mocks/` | Service mocks (`MockBookingService`, `MockAuthService`, etc.) |
| `test_driver/` | `flutter_driver` entry points if running outside `integration_test` |

A pre-existing `E2E_TESTING_DOCUMENTATION.md` at the repo root contains the operational playbook for these tests; treat that as the canonical run-book and this section as the architectural overview.

## Testing the Firestore rules

The rules can (and should) be tested in isolation using the Firebase emulator and `@firebase/rules-unit-testing`:

```bash
firebase emulators:start --only firestore
# in another shell:
cd functions
npm install --save-dev @firebase/rules-unit-testing mocha
# write tests against the emulator that try forbidden writes (e.g. isAdmin = true)
```

Sample assertion (pseudo):

```js
await assertFails(
  alice.firestore().doc('users/alice').set({ isAdmin: true })
);
await assertSucceeds(
  alice.firestore().doc('users/alice').update({ fullName: 'A' })
);
```

This catches accidental rule regressions before deploy.

## Testing Cloud Functions locally

```bash
firebase emulators:start --only functions,firestore,auth
```

Hits all three emulators on `localhost`. Point the client at the emulators via:

```dart
// In a test-only main, before runApp:
FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
```

## CI integration (skeleton)

```yaml
# Sketch — adapt to your CI of choice
jobs:
  test:
    steps:
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test --coverage
      - uses: codecov/codecov-action@v3

  e2e:
    needs: test
    runs-on: macos-latest  # iOS sim available
    steps:
      - run: flutter test integration_test/ --dart-define=E2E_TEST_MODE=true
```

## Known gaps and recommendations

- **Coverage report**: no `lcov`/codecov wiring exists in the repo today.
- **No widget tests for the booking confirmation sheet** — high-value place to add tests since fare display drives revenue.
- **No rules-emulator tests** — given the rule surface is the primary security control (see [11](11-security-audit-report.md)), adding these is the single highest-ROI testing investment.
