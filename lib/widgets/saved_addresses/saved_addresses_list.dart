import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/saved_address_model.dart';
import '../../providers/saved_address_provider.dart';
import 'saved_address_card.dart';
import 'add_address_modal.dart';

/// Full screen widget for managing saved addresses
class SavedAddressesList extends ConsumerWidget {
  final bool selectionMode;
  final bool showHeader;
  final Function(SavedAddress)? onAddressSelected;

  const SavedAddressesList({
    super.key,
    this.selectionMode = false,
    this.showHeader = true,
    this.onAddressSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addressState = ref.watch(savedAddressProvider);
    final selectedAddress = ref.watch(selectedAddressProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with add button (optional)
        if (showHeader)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Saved Addresses',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _addNewAddress(context),
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Add New'),
                ),
              ],
            ),
          ),

        // Loading state
        if (addressState.isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          )
        // Empty state
        else if (addressState.addresses.isEmpty)
          _buildEmptyState(context)
        // Address list
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: addressState.addresses.length,
              itemBuilder: (context, index) {
                final address = addressState.addresses[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SavedAddressCard(
                    address: address,
                    isSelected: selectedAddress?.addressId == address.addressId,
                    showActions: !selectionMode,
                    onTap: selectionMode
                        ? () {
                            ref
                                .read(savedAddressProvider.notifier)
                                .selectAddress(address);
                            onAddressSelected?.call(address);
                          }
                        : null,
                    onEdit: () => _editAddress(context, address),
                    onDelete: () => _deleteAddress(context, ref, address),
                    onSetDefault: () => _setDefault(context, ref, address),
                  ),
                );
              },
            ),
          ),

        // Error message
        if (addressState.error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      addressState.error!,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_off_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No saved addresses yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Save your frequently used addresses\nfor quick booking',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _addNewAddress(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Address'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addNewAddress(BuildContext context) {
    showAddAddressModal(context);
  }

  void _editAddress(BuildContext context, SavedAddress address) {
    showAddAddressModal(context, existingAddress: address);
  }

  Future<void> _deleteAddress(
    BuildContext context,
    WidgetRef ref,
    SavedAddress address,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Address'),
        content: Text(
          'Are you sure you want to delete "${address.displayLabel}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ref
          .read(savedAddressProvider.notifier)
          .deleteAddress(address.addressId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? 'Address deleted' : 'Failed to delete address',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _setDefault(
    BuildContext context,
    WidgetRef ref,
    SavedAddress address,
  ) async {
    final success = await ref
        .read(savedAddressProvider.notifier)
        .setDefaultAddress(address.addressId);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '${address.displayLabel} set as default'
                : 'Failed to set default address',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }
}

/// Compact widget for quick address selection in booking screens
class QuickAddressSelector extends ConsumerWidget {
  final Function(SavedAddress) onAddressSelected;
  final String? currentAddress;

  const QuickAddressSelector({
    super.key,
    required this.onAddressSelected,
    this.currentAddress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addressState = ref.watch(savedAddressProvider);

    if (addressState.addresses.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.bookmark_outline, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(
                'Saved Places',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Home address
              if (addressState.homeAddress != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _QuickAddressButton(
                    address: addressState.homeAddress!,
                    onTap: () => onAddressSelected(addressState.homeAddress!),
                    isSelected: currentAddress == addressState.homeAddress!.address,
                  ),
                ),

              // Work address
              if (addressState.workAddress != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _QuickAddressButton(
                    address: addressState.workAddress!,
                    onTap: () => onAddressSelected(addressState.workAddress!),
                    isSelected: currentAddress == addressState.workAddress!.address,
                  ),
                ),

              // Other addresses (limit to 3)
              ...addressState.otherAddresses.take(3).map(
                    (address) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _QuickAddressButton(
                        address: address,
                        onTap: () => onAddressSelected(address),
                        isSelected: currentAddress == address.address,
                      ),
                    ),
                  ),

              // View all button
              if (addressState.addresses.length > 5)
                TextButton(
                  onPressed: () => _showAllAddresses(context, ref),
                  child: const Text('View All'),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _showAllAddresses(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => SavedAddressesList(
          selectionMode: true,
          onAddressSelected: (address) {
            onAddressSelected(address);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }
}

class _QuickAddressButton extends StatelessWidget {
  final SavedAddress address;
  final VoidCallback onTap;
  final bool isSelected;

  const _QuickAddressButton({
    required this.address,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                _getLabelIcon(address.label),
                size: 16,
                color: isSelected ? Colors.white : _getLabelColor(address.label),
              ),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    address.displayLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                  if (address.area != null)
                    Text(
                      address.area!,
                      style: TextStyle(
                        fontSize: 11,
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.8)
                            : Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getLabelIcon(AddressLabel label) {
    switch (label) {
      case AddressLabel.home:
        return Icons.home;
      case AddressLabel.work:
        return Icons.work;
      case AddressLabel.other:
        return Icons.location_on;
    }
  }

  Color _getLabelColor(AddressLabel label) {
    switch (label) {
      case AddressLabel.home:
        return Colors.blue;
      case AddressLabel.work:
        return Colors.orange;
      case AddressLabel.other:
        return Colors.purple;
    }
  }
}
