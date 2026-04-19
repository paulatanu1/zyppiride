import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/verification_provider.dart';
import '../../services/document_verification_service.dart';

/// A badge widget that displays vehicle document verification status
class VerificationStatusBadge extends ConsumerWidget {
  final String userId;
  final bool showDetails;
  final bool compact;

  const VerificationStatusBadge({
    super.key,
    required this.userId,
    this.showDetails = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use stream provider for real-time eligibility updates
    final eligibilityAsync = ref.watch(onlineEligibilityStreamProvider(userId));

    return eligibilityAsync.when(
      data: (eligibility) {
        // Determine status based on eligibility
        String status;
        if (eligibility.canGoOnline) {
          status = 'approved';
        } else if (eligibility.missingItems.contains('vehicle_registration')) {
          status = 'pending';
        } else if (eligibility.reason?.contains('under review') == true) {
          status = 'submitted';
        } else {
          status = 'pending';
        }
        return _buildSimpleBadge(context, status);
      },
      loading: () => _buildLoadingBadge(),
      error: (e, s) => _buildErrorBadge(),
    );
  }

  Widget _buildSimpleBadge(BuildContext context, String status) {
    final (color, icon, text) = switch (status) {
      'approved' => (Colors.green, Icons.verified, 'Verified'),
      'submitted' => (Colors.blue, Icons.hourglass_empty, 'Under Review'),
      'rejected' => (Colors.red, Icons.error_outline, 'Rejected'),
      _ => (Colors.orange, Icons.pending_outlined, 'Pending'),
    };

    if (compact) {
      return Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: color),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(fontFamily: 'Poppins', 
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const SizedBox(
        width: 60,
        height: 16,
        child: LinearProgressIndicator(minHeight: 2),
      ),
    );
  }

  Widget _buildErrorBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.help_outline, size: 16, color: Colors.grey),
          const SizedBox(width: 6),
          Text(
            'Unknown',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

}

/// A card widget showing verification requirement warning
class VerificationRequiredCard extends StatelessWidget {
  final String userId;
  final OnlineEligibility eligibility;
  final VoidCallback? onActionPressed;

  const VerificationRequiredCard({
    super.key,
    required this.userId,
    required this.eligibility,
    this.onActionPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.orange.shade500, Colors.orange.shade600],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Verification Required',
                  style: TextStyle(fontFamily: 'Poppins', 
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            eligibility.reason ?? 'Complete verification to go online',
            style: TextStyle(fontFamily: 'Poppins', 
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onActionPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.orange.shade700,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _getActionButtonText(),
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getActionButtonText() {
    if (eligibility.missingItems.contains('vehicle_registration')) {
      return 'Register Vehicle';
    } else if (eligibility.missingItems.contains('vehicle_documents')) {
      return 'Upload Documents';
    } else if (eligibility.missingItems.contains('verification_under_review')) {
      return 'View Status';
    } else if (eligibility.missingItems.contains('verification_rejected')) {
      return 'Resubmit Documents';
    }
    return 'Complete Verification';
  }
}
