import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/driver_status_service.dart';
import '../core/utils/app_logger.dart';

// Service provider
final driverStatusServiceProvider = Provider<DriverStatusService>((ref) {
  return DriverStatusService();
});

// Driver online status state
class DriverOnlineState {
  final bool isOnline;
  final bool isLoading;
  final String? error;
  final DateTime? lastOnlineAt;

  const DriverOnlineState({
    this.isOnline = false,
    this.isLoading = false,
    this.error,
    this.lastOnlineAt,
  });

  DriverOnlineState copyWith({
    bool? isOnline,
    bool? isLoading,
    String? error,
    DateTime? lastOnlineAt,
  }) {
    return DriverOnlineState(
      isOnline: isOnline ?? this.isOnline,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastOnlineAt: lastOnlineAt ?? this.lastOnlineAt,
    );
  }
}

// Driver online status notifier
class DriverOnlineNotifier extends StateNotifier<DriverOnlineState> {
  final DriverStatusService _service;
  final String _userId;
  StreamSubscription<bool>? _statusSubscription;

  DriverOnlineNotifier(this._service, this._userId) : super(const DriverOnlineState()) {
    _init();
  }

  void _init() {
    // Watch online status from Firestore
    _statusSubscription = _service.watchOnlineStatus(_userId).listen(
      (isOnline) {
        state = state.copyWith(
          isOnline: isOnline,
          isLoading: false,
          lastOnlineAt: isOnline ? DateTime.now() : null,
        );
      },
      onError: (error) {
        AppLogger.error('Error watching online status: $error');
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to sync status',
        );
      },
    );
  }

  Future<void> toggleOnline() async {
    final newStatus = !state.isOnline;
    state = state.copyWith(isLoading: true, error: null);

    final result = await _service.toggleOnlineStatus(
      userId: _userId,
      isOnline: newStatus,
    );

    result.when(
      success: (isOnline) {
        state = state.copyWith(
          isOnline: isOnline,
          isLoading: false,
          lastOnlineAt: isOnline ? DateTime.now() : null,
        );
        AppLogger.success('Driver is now ${isOnline ? "ONLINE" : "OFFLINE"}');
      },
      failure: (exception) {
        state = state.copyWith(
          isLoading: false,
          error: exception.message,
        );
      },
    );
  }

  Future<void> goOnline() async {
    if (state.isOnline) return;
    await toggleOnline();
  }

  Future<void> goOffline() async {
    if (!state.isOnline) return;
    await toggleOnline();
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }
}

// Family provider for driver online status
final driverOnlineProvider = StateNotifierProvider.family<DriverOnlineNotifier, DriverOnlineState, String>((ref, userId) {
  final service = ref.watch(driverStatusServiceProvider);
  return DriverOnlineNotifier(service, userId);
});

// Stream provider for watching online status
final driverOnlineStreamProvider = StreamProvider.family<bool, String>((ref, userId) {
  final service = ref.watch(driverStatusServiceProvider);
  return service.watchOnlineStatus(userId);
});

// Provider for online drivers count
final onlineDriversCountProvider = FutureProvider.family<int, String?>((ref, city) async {
  final service = ref.watch(driverStatusServiceProvider);
  final result = await service.getOnlineDriversCount(city: city);
  return result.when(
    success: (count) => count,
    failure: (_) => 0,
  );
});
