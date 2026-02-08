import 'package:flutter/material.dart';
import '../../models/saved_address_model.dart';

/// Card widget for displaying a saved address
class SavedAddressCard extends StatelessWidget {
  final SavedAddress address;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onSetDefault;
  final bool isSelected;
  final bool showActions;
  final bool compact;

  const SavedAddressCard({
    super.key,
    required this.address,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onSetDefault,
    this.isSelected = false,
    this.showActions = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(compact ? 12 : 16),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.primaryColor.withValues(alpha: 0.1)
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? theme.primaryColor
                  : Colors.grey.shade200,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: compact ? 40 : 48,
                height: compact ? 40 : 48,
                decoration: BoxDecoration(
                  color: _getLabelColor(address.label).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    _getLabelIcon(address.label),
                    color: _getLabelColor(address.label),
                    size: compact ? 20 : 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Address details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          address.displayLabel,
                          style: TextStyle(
                            fontSize: compact ? 14 : 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        if (address.isDefault) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Default',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      address.shortAddress,
                      style: TextStyle(
                        fontSize: compact ? 12 : 14,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: compact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!compact && address.address != address.shortAddress) ...[
                      const SizedBox(height: 2),
                      Text(
                        address.address,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // Actions or selection indicator
              if (showActions)
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    color: Colors.grey.shade600,
                  ),
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        onEdit?.call();
                        break;
                      case 'delete':
                        onDelete?.call();
                        break;
                      case 'default':
                        onSetDefault?.call();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 20),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    if (!address.isDefault)
                      const PopupMenuItem(
                        value: 'default',
                        child: Row(
                          children: [
                            Icon(Icons.star_outline, size: 20),
                            SizedBox(width: 8),
                            Text('Set as Default'),
                          ],
                        ),
                      ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline,
                              size: 20, color: Colors.red),
                          const SizedBox(width: 8),
                          const Text('Delete',
                              style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                )
              else if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: theme.primaryColor,
                  size: 24,
                )
              else if (onTap != null)
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey.shade400,
                  size: 24,
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
        return Icons.home_outlined;
      case AddressLabel.work:
        return Icons.work_outline;
      case AddressLabel.other:
        return Icons.location_on_outlined;
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

/// Compact chip for quick address selection
class SavedAddressChip extends StatelessWidget {
  final SavedAddress address;
  final VoidCallback? onTap;
  final bool isSelected;

  const SavedAddressChip({
    super.key,
    required this.address,
    this.onTap,
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
              const SizedBox(width: 6),
              Text(
                address.displayLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                ),
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
}
