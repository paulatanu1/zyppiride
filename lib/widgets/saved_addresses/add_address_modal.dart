import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';

import '../../models/saved_address_model.dart';
import '../../providers/saved_address_provider.dart';

/// Modal for adding or editing a saved address
class AddAddressModal extends ConsumerStatefulWidget {
  final SavedAddress? existingAddress;

  const AddAddressModal({
    super.key,
    this.existingAddress,
  });

  @override
  ConsumerState<AddAddressModal> createState() => _AddAddressModalState();
}

class _AddAddressModalState extends ConsumerState<AddAddressModal> {
  // Same API key as vehicle registration screen
  static const String googleApiKey = 'AIzaSyABUF7GCEM6h1n3isugLj2qOEySpTtxd1I';

  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _customLabelController = TextEditingController();
  final _searchFocusNode = FocusNode();

  AddressLabel _selectedLabel = AddressLabel.home;
  bool _isDefault = false;
  bool _isLoading = false;
  bool _isValidating = false;
  String? _error;

  // Validated address data
  double? _latitude;
  double? _longitude;
  String? _formattedAddress;
  String? _area;
  String? _city;
  String? _state;
  String? _postalCode;

  // Track the last processed prediction to avoid duplicate processing
  String? _lastProcessedPrediction;

  bool get isEditing => widget.existingAddress != null;

  @override
  void initState() {
    super.initState();
    if (widget.existingAddress != null) {
      _addressController.text = widget.existingAddress!.address;
      _selectedLabel = widget.existingAddress!.label;
      _customLabelController.text = widget.existingAddress!.customLabel ?? '';
      _isDefault = widget.existingAddress!.isDefault;
      _latitude = widget.existingAddress!.latitude;
      _longitude = widget.existingAddress!.longitude;
      _area = widget.existingAddress!.area;
      _city = widget.existingAddress!.city;
      _state = widget.existingAddress!.state;
      _postalCode = widget.existingAddress!.postalCode;
      _formattedAddress = widget.existingAddress!.address;
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _customLabelController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;

    if (_latitude == null || _longitude == null) {
      setState(() {
        _error = 'Please select a valid address from suggestions';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final notifier = ref.read(savedAddressProvider.notifier);

      bool success;
      if (isEditing) {
        final updatedAddress = widget.existingAddress!.copyWith(
          label: _selectedLabel,
          customLabel: _selectedLabel == AddressLabel.other
              ? _customLabelController.text.trim()
              : null,
          address: _formattedAddress ?? _addressController.text.trim(),
          area: _area,
          city: _city,
          state: _state,
          postalCode: _postalCode,
          latitude: _latitude,
          longitude: _longitude,
          isDefault: _isDefault,
        );
        success = await notifier.updateAddress(updatedAddress);
      } else {
        success = await notifier.addAddress(
          label: _selectedLabel,
          customLabel: _selectedLabel == AddressLabel.other
              ? _customLabelController.text.trim()
              : null,
          address: _formattedAddress ?? _addressController.text.trim(),
          area: _area,
          city: _city,
          state: _state,
          postalCode: _postalCode,
          latitude: _latitude!,
          longitude: _longitude!,
          isDefault: _isDefault,
        );
      }

      if (mounted) {
        if (success) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isEditing
                  ? 'Address updated successfully'
                  : 'Address saved successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          setState(() {
            _error = 'Failed to save address. Please try again.';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'An error occurred. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _onPlaceSelected(Prediction prediction) async {
    final description = prediction.description ?? '';

    // Avoid duplicate processing
    if (description.isEmpty || description == _lastProcessedPrediction) {
      return;
    }
    _lastProcessedPrediction = description;

    setState(() {
      _isValidating = true;
      _error = null;
    });

    try {
      // Get coordinates from the selected place
      List<Location> locations = await locationFromAddress(description);

      if (locations.isNotEmpty && mounted) {
        Location location = locations[0];

        // Get detailed address info via reverse geocoding
        List<Placemark> placemarks = await placemarkFromCoordinates(
          location.latitude,
          location.longitude,
        );

        if (mounted) {
          setState(() {
            _latitude = location.latitude;
            _longitude = location.longitude;
            _formattedAddress = description;

            if (placemarks.isNotEmpty) {
              final place = placemarks[0];
              _area = place.subLocality ?? place.locality;
              _city = place.locality ?? place.subAdministrativeArea;
              _state = place.administrativeArea;
              _postalCode = place.postalCode;
            }

            _isValidating = false;
          });
        }
      } else {
        _lastProcessedPrediction = null; // Reset to allow retry
        setState(() {
          _isValidating = false;
          _error = 'Could not find location coordinates';
        });
      }
    } catch (e) {
      _lastProcessedPrediction = null; // Reset to allow retry
      if (mounted) {
        setState(() {
          _isValidating = false;
          _error = 'Could not validate address. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isEditing ? 'Edit Address' : 'Add New Address',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          // Scrollable content
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: 20 + bottomPadding,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Label Selection
                    const Text(
                      'Save as',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: AddressLabel.values.map((label) {
                        final isSelected = _selectedLabel == label;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedLabel = label;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? theme.primaryColor
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? theme.primaryColor
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getLabelIcon(label),
                                  size: 18,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey.shade600,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  label.displayName,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Custom label (for Other)
                    if (_selectedLabel == AddressLabel.other) ...[
                      TextFormField(
                        controller: _customLabelController,
                        decoration: InputDecoration(
                          labelText: 'Custom Label',
                          hintText: 'e.g., Gym, Parents, Office 2',
                          prefixIcon: const Icon(Icons.label_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (_selectedLabel == AddressLabel.other &&
                              (value == null || value.trim().isEmpty)) {
                            return 'Please enter a label for this address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Address Search
                    const Text(
                      'Search Address',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Google Places Search - same pattern as vehicle registration
                    Container(
                      key: const ValueKey('google_places_container'),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: GooglePlaceAutoCompleteTextField(
                        textEditingController: _addressController,
                        googleAPIKey: googleApiKey,
                        focusNode: _searchFocusNode,
                        inputDecoration: InputDecoration(
                          hintText: 'Search for your address...',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[400],
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: theme.primaryColor,
                          ),
                          suffixIcon: _isValidating
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        debounceTime: 600,
                        countries: const ['in'],
                        isLatLngRequired: false,
                        getPlaceDetailWithLatLng: (Prediction prediction) {
                          _onPlaceSelected(prediction);
                        },
                        itemClick: (Prediction prediction) {
                          _addressController.text = prediction.description ?? '';
                          _addressController.selection = TextSelection.fromPosition(
                            TextPosition(offset: prediction.description?.length ?? 0),
                          );
                          // Also trigger place selection to ensure coordinates are captured
                          // as getPlaceDetailWithLatLng may not always fire reliably
                          _onPlaceSelected(prediction);
                        },
                        itemBuilder: (context, index, Prediction prediction) {
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.grey[200]!,
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  color: theme.primaryColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    prediction.description ?? '',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        seperatedBuilder: const Divider(height: 0),
                        isCrossBtnShown: true,
                      ),
                    ),

                    // Validated address info
                    if (_latitude != null && _longitude != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle,
                                color: Colors.green.shade700, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Address verified',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green.shade700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (_area != null || _city != null)
                                    Text(
                                      [_area, _city, _state]
                                          .where((e) => e != null && e.isNotEmpty)
                                          .join(', '),
                                      style: TextStyle(
                                        color: Colors.green.shade600,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),

                    // Default address toggle
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.star_outline, color: Colors.amber),
                              SizedBox(width: 8),
                              Text(
                                'Set as default address',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          Switch(
                            value: _isDefault,
                            onChanged: (value) {
                              setState(() {
                                _isDefault = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Error message
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline,
                                color: Colors.red.shade700, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            _isLoading || _isValidating ? null : _saveAddress,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                isEditing ? 'Update Address' : 'Save Address',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getLabelIcon(AddressLabel label) {
    switch (label) {
      case AddressLabel.home:
        return Icons.home_outlined;
      case AddressLabel.work:
        return Icons.work_outline;
      case AddressLabel.other:
        return Icons.location_on_outlined;
    }
  }
}

/// Show add address modal
Future<bool?> showAddAddressModal(
  BuildContext context, {
  SavedAddress? existingAddress,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => AddAddressModal(existingAddress: existingAddress),
  );
}
