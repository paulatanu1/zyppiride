# 09 — State Management

## Library

`flutter_riverpod: ^2.5.1`. The app is wrapped in `ProviderScope` at the top of `main.dart`:

```dart
runApp(const ProviderScope(child: MyApp()));
```

There is **no** `ChangeNotifier`-based state, no `Provider`-package code, no `Bloc`. The codebase consistently uses Riverpod patterns.

## Provider catalogue (`lib/providers/`)

| File | Type | Provides | Notes |
|---|---|---|---|
| `availability_provider.dart` | StateNotifier / Stream | Vehicle availability state | Schedules + blocked dates |
| `booking_provider.dart` | StateNotifier + Streams | Active booking, history, create flow | Backed by `BookingService` |
| `driver_status_provider.dart` | StateNotifier | Driver online/offline status | Backed by `DriverStatusService` |
| `live_location_provider.dart` | StateNotifier + Stream | Driver location tracking control | Backed by `LiveLocationService` |
| `location_provider.dart` | StateNotifier | Current pickup location, geocoding | Backed by `LocationService` |
| `notification_provider.dart` | StateNotifier | FCM init, token persistence | Initialised once on app start |
| `saved_address_provider.dart` | StateNotifier + Stream | User's saved addresses | Backed by `SavedAddressService` |
| `schedule_provider.dart` | StateNotifier | Weekly schedule editor | Backed by `vehicles/{id}/schedules` |
| `user_dashboard_provider.dart` | StateNotifier | Dashboard composite (user, banners, offers) | Composed from multiple services |
| `vehicle_search_provider.dart` | StateNotifier | Vehicle search filters + results | Backed by `VehicleSearchService` |
| `verification_provider.dart` | StateNotifier + Stream | Driver verification state | Watches `users/{uid}` + per-vehicle `documentStatus`; computes `canGoOnline` |

## Patterns in use

### 1. Service provider + state notifier

This is the dominant pattern. Two providers per feature:

```dart
// (1) inject the service
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    auth: FirebaseAuth.instance,
    firestore: FirebaseFirestore.instance,
  );
});

// (2) state notifier that owns mutable state and exposes intents
final phoneAuthNotifierProvider =
    StateNotifierProvider<PhoneAuthNotifier, PhoneAuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return PhoneAuthNotifier(authService);
});
```

This isolates business logic from Firebase calls and lets tests override the service via `ProviderScope(overrides: [...])`.

### 2. Stream-backed providers

Long-lived Firestore subscriptions are exposed via `Stream`s on the service and consumed via either `StreamProvider` or hand-rolled subscriptions inside a `StateNotifier`. Example: `verification_provider.dart` (`_statusSubscription = _service.watchVerificationStatus(_userId).listen(...)`).

### 3. Family providers (parameterised)

For per-user / per-vehicle subscriptions, providers should be created with `.family` so multiple parameters can coexist without state leakage. Example pattern used:

```dart
final activeBookingStreamProvider = StreamProvider.family<Booking?, String>((ref, userId) {
  return ref.watch(bookingServiceProvider).getActiveBookingStream(userId);
});
```

### 4. Disposal

`StateNotifier`s that own `StreamSubscription`s must override `dispose()` to cancel them — `VerificationNotifier` does this with `_statusSubscription?.cancel()`. When using `.family` providers in widgets, prefer `autoDispose` to release resources on widget unmount.

## State object shape

`StateNotifier` state objects are immutable. Example (`VerificationState`):

```dart
class VerificationState {
  final bool isLoading;
  final VerificationStatus? status;
  final OnlineEligibility? eligibility;
  final List<VehicleVerificationInfo> vehicles;
  final String? error;

  const VerificationState({ ... });
  VerificationState copyWith({ ... }) { ... }
}
```

Field rules:
- All fields are `final`.
- `null` is preferred over sentinels for "not yet loaded".
- `error` is a transient slot — null it out at the start of every action.

## Consumption from widgets

Inside `ConsumerWidget` / `ConsumerStatefulWidget`:

| Need | API |
|---|---|
| Reactive read | `ref.watch(provider)` |
| One-shot read inside a callback / `onPressed` | `ref.read(provider)` |
| Invalidate / reset | `ref.invalidate(provider)` |
| Listen-only side effects | `ref.listen(provider, (prev, next) { ... })` |

Example:

```dart
class ReserveVehicleScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(vehicleSearchProvider);
    final filters = ref.watch(vehicleSearchFiltersProvider);
    return results.when(
      data: (vehicles) => _List(vehicles),
      loading: () => const CircularProgressIndicator(),
      error: (e, _) => Text('Error: $e'),
    );
  }
}
```

## Where state lives — cheat sheet

| Concern | Provider |
|---|---|
| Logged-in user (raw Firebase) | `FirebaseAuth.instance.currentUser` directly (router-level), or wrap in `Provider` for testability |
| Current rider's pickup location | `location_provider.dart` |
| Active booking for the rider | `booking_provider.dart` (stream-based) |
| Driver's pending requests | `booking_provider.dart` (stream-based) |
| Driver online toggle | `driver_status_provider.dart` |
| Driver verification & per-vehicle approval | `verification_provider.dart` |
| Live driver location (publishing) | `live_location_provider.dart` |
| Live driver location (consuming, rider side) | `live_location_provider.dart` (stream from `drivers/{id}`) |
| Vehicle search filters + results | `vehicle_search_provider.dart` |
| Saved addresses | `saved_address_provider.dart` |
| Notification system (init + token) | `notification_provider.dart` |

## Anti-patterns the codebase avoids (and you should too)

- **Don't** use `StatefulWidget` + `setState` to manage async Firestore subscriptions — leak risk.
- **Don't** keep state in widget classes; that breaks Riverpod's override-for-test capability.
- **Don't** introduce `ChangeNotifier` (per `CLAUDE.md` guidance).
- **Don't** call `ref.read` in `build`; use `ref.watch` to react to changes, or `ref.read` inside callbacks.
