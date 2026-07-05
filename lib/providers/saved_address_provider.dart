import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/saved_address_model.dart';
import '../services/saved_address_service.dart';

/// Provider for SavedAddressService
final savedAddressServiceProvider = Provider<SavedAddressService>((ref) {
  return SavedAddressService();
});

/// State for saved addresses
class SavedAddressState {
  final List<SavedAddress> addresses;
  final bool isLoading;
  final String? error;
  final SavedAddress? selectedAddress;

  const SavedAddressState({
    this.addresses = const [],
    this.isLoading = false,
    this.error,
    this.selectedAddress,
  });

  SavedAddressState copyWith({
    List<SavedAddress>? addresses,
    bool? isLoading,
    String? error,
    SavedAddress? selectedAddress,
    bool clearError = false,
    bool clearSelected = false,
  }) {
    return SavedAddressState(
      addresses: addresses ?? this.addresses,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      selectedAddress:
          clearSelected ? null : (selectedAddress ?? this.selectedAddress),
    );
  }

  /// Get home address if exists
  SavedAddress? get homeAddress {
    try {
      return addresses.firstWhere((a) => a.label == AddressLabel.home);
    } catch (_) {
      return null;
    }
  }

  /// Get work address if exists
  SavedAddress? get workAddress {
    try {
      return addresses.firstWhere((a) => a.label == AddressLabel.work);
    } catch (_) {
      return null;
    }
  }

  /// Get default address if exists
  SavedAddress? get defaultAddress {
    try {
      return addresses.firstWhere((a) => a.isDefault);
    } catch (_) {
      return homeAddress; // Fallback to home if no default
    }
  }

  /// Get other/custom addresses
  List<SavedAddress> get otherAddresses {
    return addresses.where((a) => a.label == AddressLabel.other).toList();
  }

  /// Check if Home address exists
  bool get hasHome => homeAddress != null;

  /// Check if Work address exists
  bool get hasWork => workAddress != null;
}

/// Notifier for managing saved addresses state
class SavedAddressNotifier extends StateNotifier<SavedAddressState> {
  final SavedAddressService _service;
  final String? _userId;

  SavedAddressNotifier(this._service, this._userId)
      : super(const SavedAddressState()) {
    if (_userId != null) {
      loadAddresses();
    }
  }

  /// Load all saved addresses for the user
  Future<void> loadAddresses() async {
    final userId = _userId;
    if (userId == null) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final addresses = await _service.getSavedAddresses(userId);
      state = state.copyWith(
        addresses: addresses,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load addresses',
      );
    }
  }

  /// Add a new address
  Future<bool> addAddress({
    required AddressLabel label,
    String? customLabel,
    required String address,
    String? area,
    String? city,
    String? state,
    String? postalCode,
    required double latitude,
    required double longitude,
    bool isDefault = false,
  }) async {
    final userId = _userId;
    if (userId == null) return false;

    this.state = this.state.copyWith(isLoading: true, clearError: true);

    try {
      final newAddress = SavedAddress(
        addressId: '', // Will be set by service
        userId: userId,
        label: label,
        customLabel: customLabel,
        address: address,
        area: area,
        city: city,
        state: state,
        postalCode: postalCode,
        latitude: latitude,
        longitude: longitude,
        isDefault: isDefault,
        createdAt: DateTime.now(),
      );

      final result = await _service.addAddress(newAddress);

      if (result != null) {
        await loadAddresses(); // Reload to get updated list
        return true;
      }

      this.state = this.state.copyWith(
        isLoading: false,
        error: 'Failed to add address',
      );
      return false;
    } catch (e) {
      this.state = this.state.copyWith(
        isLoading: false,
        error: 'Failed to add address',
      );
      return false;
    }
  }

  /// Update an existing address
  Future<bool> updateAddress(SavedAddress address) async {
    if (_userId == null) return false;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final result = await _service.updateAddress(address);

      if (result != null) {
        await loadAddresses();
        return true;
      }

      state = state.copyWith(
        isLoading: false,
        error: 'Failed to update address',
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to update address',
      );
      return false;
    }
  }

  /// Delete an address
  Future<bool> deleteAddress(String addressId) async {
    final userId = _userId;
    if (userId == null) return false;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final success = await _service.deleteAddress(userId, addressId);

      if (success) {
        await loadAddresses();
        return true;
      }

      state = state.copyWith(
        isLoading: false,
        error: 'Failed to delete address',
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to delete address',
      );
      return false;
    }
  }

  /// Set an address as default
  Future<bool> setDefaultAddress(String addressId) async {
    final userId = _userId;
    if (userId == null) return false;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final success = await _service.setDefaultAddress(userId, addressId);

      if (success) {
        await loadAddresses();
        return true;
      }

      state = state.copyWith(
        isLoading: false,
        error: 'Failed to set default address',
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to set default address',
      );
      return false;
    }
  }

  /// Select an address (for booking flow)
  void selectAddress(SavedAddress? address) {
    state = state.copyWith(
      selectedAddress: address,
      clearSelected: address == null,
    );
  }

  /// Clear selection
  void clearSelection() {
    state = state.copyWith(clearSelected: true);
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Validate and add address from string
  Future<AddressValidationResult> validateAndAddAddress({
    required String addressString,
    required AddressLabel label,
    String? customLabel,
    bool isDefault = false,
  }) async {
    final validation = await _service.validateAddress(addressString);

    if (!validation.isValid) {
      return validation;
    }

    final success = await addAddress(
      label: label,
      customLabel: customLabel,
      address: validation.formattedAddress ?? addressString,
      area: validation.area,
      city: validation.city,
      state: validation.state,
      postalCode: validation.postalCode,
      latitude: validation.latitude!,
      longitude: validation.longitude!,
      isDefault: isDefault,
    );

    if (!success) {
      return AddressValidationResult(
        isValid: false,
        error: 'Failed to save address',
      );
    }

    return validation;
  }
}

/// Provider for current user auth state
final _authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// Provider for saved addresses state
final savedAddressProvider =
    StateNotifierProvider<SavedAddressNotifier, SavedAddressState>((ref) {
  final service = ref.watch(savedAddressServiceProvider);
  final authState = ref.watch(_authStateProvider);
  final userId = authState.value?.uid;

  return SavedAddressNotifier(service, userId);
});

/// Provider for just the addresses list
final savedAddressListProvider = Provider<List<SavedAddress>>((ref) {
  return ref.watch(savedAddressProvider).addresses;
});

/// Provider for home address
final homeAddressProvider = Provider<SavedAddress?>((ref) {
  return ref.watch(savedAddressProvider).homeAddress;
});

/// Provider for work address
final workAddressProvider = Provider<SavedAddress?>((ref) {
  return ref.watch(savedAddressProvider).workAddress;
});

/// Provider for default address
final defaultAddressProvider = Provider<SavedAddress?>((ref) {
  return ref.watch(savedAddressProvider).defaultAddress;
});

/// Provider for selected address (in booking flow)
final selectedAddressProvider = Provider<SavedAddress?>((ref) {
  return ref.watch(savedAddressProvider).selectedAddress;
});

/// Provider for loading state
final savedAddressLoadingProvider = Provider<bool>((ref) {
  return ref.watch(savedAddressProvider).isLoading;
});

/// Stream provider for real-time address updates
final savedAddressStreamProvider =
    StreamProvider.autoDispose<List<SavedAddress>>((ref) {
  final service = ref.watch(savedAddressServiceProvider);
  final authState = ref.watch(_authStateProvider);
  final userId = authState.value?.uid;

  if (userId == null) {
    return Stream.value([]);
  }

  return service.savedAddressesStream(userId);
});
