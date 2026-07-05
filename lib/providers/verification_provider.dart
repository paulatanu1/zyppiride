import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/app_logger.dart';
import '../services/document_verification_service.dart';

// Service provider
final verificationServiceProvider = Provider<DocumentVerificationService>((ref) {
  return DocumentVerificationService();
});

// Verification state
class VerificationState {
  final bool isLoading;
  final VerificationStatus? status;
  final OnlineEligibility? eligibility;
  final List<VehicleVerificationInfo> vehicles;
  final String? error;

  const VerificationState({
    this.isLoading = false,
    this.status,
    this.eligibility,
    this.vehicles = const [],
    this.error,
  });

  VerificationState copyWith({
    bool? isLoading,
    VerificationStatus? status,
    OnlineEligibility? eligibility,
    List<VehicleVerificationInfo>? vehicles,
    String? error,
  }) {
    return VerificationState(
      isLoading: isLoading ?? this.isLoading,
      status: status ?? this.status,
      eligibility: eligibility ?? this.eligibility,
      vehicles: vehicles ?? this.vehicles,
      error: error,
    );
  }
}

// Verification notifier
class VerificationNotifier extends StateNotifier<VerificationState> {
  final DocumentVerificationService _service;
  final String _userId;
  StreamSubscription? _statusSubscription;

  VerificationNotifier(this._service, this._userId)
      : super(const VerificationState()) {
    _init();
  }

  void _init() {
    // Watch verification status
    _statusSubscription = _service.watchVerificationStatus(_userId).listen(
      (status) {
        state = state.copyWith(status: status);
        _checkEligibility();
      },
      onError: (e) {
        AppLogger.error(
          'Verification watch error',
          error: e,
          tag: 'VerificationNotifier',
        );
      },
    );

    loadData();
  }

  Future<void> loadData() async {
    state = state.copyWith(isLoading: true, error: null);

    // Load all data in parallel
    final results = await Future.wait([
      _service.getVerificationStatus(_userId),
      _service.getVehicleVerificationStatus(_userId),
      _service.checkOnlineEligibility(_userId),
    ]);

    final statusResult = results[0] as dynamic;
    final vehiclesResult = results[1] as dynamic;
    final eligibilityResult = results[2] as dynamic;

    state = state.copyWith(
      isLoading: false,
      status: statusResult.dataOrNull,
      vehicles: vehiclesResult.dataOrNull ?? [],
      eligibility: eligibilityResult.dataOrNull,
      error: statusResult.exceptionOrNull?.message ??
          vehiclesResult.exceptionOrNull?.message,
    );
  }

  Future<void> _checkEligibility() async {
    final result = await _service.checkOnlineEligibility(_userId);
    result.when(
      success: (eligibility) {
        state = state.copyWith(eligibility: eligibility);
      },
      failure: (_) {},
    );
  }

  Future<bool> submitForVerification() async {
    state = state.copyWith(isLoading: true);

    final result = await _service.submitForVerification(_userId);

    return result.when(
      success: (_) {
        loadData();
        return true;
      },
      failure: (exception) {
        state = state.copyWith(
          isLoading: false,
          error: exception.message,
        );
        return false;
      },
    );
  }

  Future<void> refresh() async {
    await loadData();
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }
}

// Main provider (family for user ID)
final verificationProvider = StateNotifierProvider.family<VerificationNotifier,
    VerificationState, String>((ref, userId) {
  final service = ref.watch(verificationServiceProvider);
  return VerificationNotifier(service, userId);
});

// Stream provider for verification status
final verificationStatusStreamProvider =
    StreamProvider.family<VerificationStatus, String>((ref, userId) {
  final service = ref.watch(verificationServiceProvider);
  return service.watchVerificationStatus(userId);
});

// Provider for online eligibility (one-time fetch)
final onlineEligibilityProvider =
    FutureProvider.family<OnlineEligibility, String>((ref, userId) async {
  final service = ref.watch(verificationServiceProvider);
  final result = await service.checkOnlineEligibility(userId);
  return result.getOrElse(OnlineEligibility(
    canGoOnline: false,
    reason: 'Unable to check eligibility',
  ));
});

// Stream provider for online eligibility (auto-updates)
final onlineEligibilityStreamProvider =
    StreamProvider.family<OnlineEligibility, String>((ref, userId) {
  final service = ref.watch(verificationServiceProvider);
  return service.watchOnlineEligibility(userId);
});

// Provider for vehicle verification info
final vehicleVerificationProvider =
    FutureProvider.family<List<VehicleVerificationInfo>, String>(
        (ref, userId) async {
  final service = ref.watch(verificationServiceProvider);
  final result = await service.getVehicleVerificationStatus(userId);
  return result.getOrElse([]);
});
