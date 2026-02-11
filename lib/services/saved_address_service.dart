import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
import '../models/saved_address_model.dart';
import '../core/utils/app_logger.dart';

/// Service for managing saved addresses in Firestore
class SavedAddressService {
  final FirebaseFirestore _firestore;
  static const String _collection = 'savedAddresses';

  SavedAddressService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Get reference to user's saved addresses collection
  CollectionReference<Map<String, dynamic>> _userAddressesRef(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection(_collection);
  }

  /// Get all saved addresses for a user
  Future<List<SavedAddress>> getSavedAddresses(String userId) async {
    try {
      final snapshot = await _userAddressesRef(userId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => SavedAddress.fromFirestore(doc))
          .toList();
    } catch (e, stack) {
      AppLogger.error('Failed to get saved addresses',
          error: e, stackTrace: stack, tag: 'SavedAddressService');
      return [];
    }
  }

  /// Stream of saved addresses for real-time updates
  Stream<List<SavedAddress>> savedAddressesStream(String userId) {
    return _userAddressesRef(userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SavedAddress.fromFirestore(doc))
            .toList());
  }

  /// Get a single saved address by ID
  Future<SavedAddress?> getAddress(String userId, String addressId) async {
    try {
      final doc = await _userAddressesRef(userId).doc(addressId).get();
      if (doc.exists) {
        return SavedAddress.fromFirestore(doc);
      }
      return null;
    } catch (e, stack) {
      AppLogger.error('Failed to get address',
          error: e, stackTrace: stack, tag: 'SavedAddressService');
      return null;
    }
  }

  /// Get default address for a user
  Future<SavedAddress?> getDefaultAddress(String userId) async {
    try {
      final snapshot = await _userAddressesRef(userId)
          .where('isDefault', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return SavedAddress.fromFirestore(snapshot.docs.first);
      }
      return null;
    } catch (e, stack) {
      AppLogger.error('Failed to get default address',
          error: e, stackTrace: stack, tag: 'SavedAddressService');
      return null;
    }
  }

  /// Get address by label (Home, Work)
  Future<SavedAddress?> getAddressByLabel(
      String userId, AddressLabel label) async {
    try {
      final snapshot = await _userAddressesRef(userId)
          .where('label', isEqualTo: label.name)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return SavedAddress.fromFirestore(snapshot.docs.first);
      }
      return null;
    } catch (e, stack) {
      AppLogger.error('Failed to get address by label',
          error: e, stackTrace: stack, tag: 'SavedAddressService');
      return null;
    }
  }

  /// Add a new saved address
  Future<SavedAddress?> addAddress(SavedAddress address) async {
    try {
      // If this is set as default, remove default from other addresses
      if (address.isDefault) {
        await _clearDefaultAddress(address.userId);
      }

      // For Home/Work labels, check if one already exists and update it
      if (address.label != AddressLabel.other) {
        final existing =
            await getAddressByLabel(address.userId, address.label);
        if (existing != null) {
          // Update existing Home/Work address
          return await updateAddress(
            existing.copyWith(
              address: address.address,
              area: address.area,
              city: address.city,
              state: address.state,
              postalCode: address.postalCode,
              latitude: address.latitude,
              longitude: address.longitude,
              isDefault: address.isDefault,
              updatedAt: DateTime.now(),
            ),
          );
        }
      }

      final docRef = _userAddressesRef(address.userId).doc();
      final newAddress = address.copyWith(
        addressId: docRef.id,
        createdAt: DateTime.now(),
      );

      await docRef.set(newAddress.toMap());

      AppLogger.info('Address added successfully', tag: 'SavedAddressService');

      return newAddress;
    } catch (e, stack) {
      AppLogger.error('Failed to add address',
          error: e, stackTrace: stack, tag: 'SavedAddressService');
      return null;
    }
  }

  /// Update an existing saved address
  Future<SavedAddress?> updateAddress(SavedAddress address) async {
    try {
      // If setting as default, remove default from other addresses
      if (address.isDefault) {
        await _clearDefaultAddress(address.userId, exceptId: address.addressId);
      }

      final updatedAddress = address.copyWith(updatedAt: DateTime.now());

      await _userAddressesRef(address.userId)
          .doc(address.addressId)
          .update(updatedAddress.toMap());

      AppLogger.info('Address updated successfully', tag: 'SavedAddressService');

      return updatedAddress;
    } catch (e, stack) {
      AppLogger.error('Failed to update address',
          error: e, stackTrace: stack, tag: 'SavedAddressService');
      return null;
    }
  }

  /// Delete a saved address
  Future<bool> deleteAddress(String userId, String addressId) async {
    try {
      await _userAddressesRef(userId).doc(addressId).delete();

      AppLogger.info('Address deleted successfully', tag: 'SavedAddressService');

      return true;
    } catch (e, stack) {
      AppLogger.error('Failed to delete address',
          error: e, stackTrace: stack, tag: 'SavedAddressService');
      return false;
    }
  }

  /// Set an address as default
  Future<bool> setDefaultAddress(String userId, String addressId) async {
    try {
      // Clear existing default
      await _clearDefaultAddress(userId);

      // Set new default
      await _userAddressesRef(userId).doc(addressId).update({
        'isDefault': true,
        'updatedAt': Timestamp.now(),
      });

      AppLogger.info('Default address set successfully', tag: 'SavedAddressService');

      return true;
    } catch (e, stack) {
      AppLogger.error('Failed to set default address',
          error: e, stackTrace: stack, tag: 'SavedAddressService');
      return false;
    }
  }

  /// Clear default flag from all addresses except specified one
  Future<void> _clearDefaultAddress(String userId, {String? exceptId}) async {
    try {
      final snapshot = await _userAddressesRef(userId)
          .where('isDefault', isEqualTo: true)
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        if (exceptId == null || doc.id != exceptId) {
          batch.update(doc.reference, {'isDefault': false});
        }
      }
      await batch.commit();
    } catch (e, stack) {
      AppLogger.error('Failed to clear default address',
          error: e, stackTrace: stack, tag: 'SavedAddressService');
    }
  }

  /// Validate an address by geocoding it
  Future<AddressValidationResult> validateAddress(String address) async {
    try {
      if (address.trim().isEmpty) {
        return AddressValidationResult(
          isValid: false,
          error: 'Address cannot be empty',
        );
      }

      // Try to geocode the address
      final locations = await locationFromAddress(address);

      if (locations.isEmpty) {
        return AddressValidationResult(
          isValid: false,
          error: 'Could not find this address',
        );
      }

      final location = locations.first;

      // Get full address details via reverse geocoding
      final placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );

      if (placemarks.isEmpty) {
        return AddressValidationResult(
          isValid: true,
          latitude: location.latitude,
          longitude: location.longitude,
        );
      }

      final placemark = placemarks.first;

      return AddressValidationResult(
        isValid: true,
        latitude: location.latitude,
        longitude: location.longitude,
        formattedAddress: _formatAddress(placemark),
        area: placemark.subLocality ?? placemark.locality,
        city: placemark.locality ?? placemark.subAdministrativeArea,
        state: placemark.administrativeArea,
        postalCode: placemark.postalCode,
      );
    } catch (e, stack) {
      AppLogger.error('Address validation failed',
          error: e, stackTrace: stack, tag: 'SavedAddressService');
      return AddressValidationResult(
        isValid: false,
        error: 'Failed to validate address. Please check and try again.',
      );
    }
  }

  /// Format placemark to address string
  String _formatAddress(Placemark placemark) {
    final parts = <String>[];

    if (placemark.street != null && placemark.street!.isNotEmpty) {
      parts.add(placemark.street!);
    }
    if (placemark.subLocality != null && placemark.subLocality!.isNotEmpty) {
      parts.add(placemark.subLocality!);
    }
    if (placemark.locality != null && placemark.locality!.isNotEmpty) {
      parts.add(placemark.locality!);
    }
    if (placemark.administrativeArea != null &&
        placemark.administrativeArea!.isNotEmpty) {
      parts.add(placemark.administrativeArea!);
    }
    if (placemark.postalCode != null && placemark.postalCode!.isNotEmpty) {
      parts.add(placemark.postalCode!);
    }

    return parts.join(', ');
  }

  /// Get address count for a user
  Future<int> getAddressCount(String userId) async {
    try {
      final snapshot = await _userAddressesRef(userId).count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Check if user has Home address
  Future<bool> hasHomeAddress(String userId) async {
    final address = await getAddressByLabel(userId, AddressLabel.home);
    return address != null;
  }

  /// Check if user has Work address
  Future<bool> hasWorkAddress(String userId) async {
    final address = await getAddressByLabel(userId, AddressLabel.work);
    return address != null;
  }
}

/// Result of address validation
class AddressValidationResult {
  final bool isValid;
  final String? error;
  final double? latitude;
  final double? longitude;
  final String? formattedAddress;
  final String? area;
  final String? city;
  final String? state;
  final String? postalCode;

  AddressValidationResult({
    required this.isValid,
    this.error,
    this.latitude,
    this.longitude,
    this.formattedAddress,
    this.area,
    this.city,
    this.state,
    this.postalCode,
  });

  bool get hasCoordinates => latitude != null && longitude != null;
}
