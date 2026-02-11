import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/verification_provider.dart';
import '../../services/document_verification_service.dart';

/// A badge widget that displays the user's verification status
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
    final verificationAsync = ref.watch(verificationStatusStreamProvider(userId));

    return verificationAsync.when(
      data: (status) => _buildBadge(context, status),
      loading: () => _buildLoadingBadge(),
      error: (e, s) => _buildErrorBadge(),
    );
  }

  Widget _buildBadge(BuildContext context, VerificationStatus status) {
    final (color, icon, text) = switch (status.status) {
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

    return GestureDetector(
      onTap: showDetails ? () => _showDetailsDialog(context, status) : null,
      child: Container(
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
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            if (showDetails) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.info_outline,
                size: 14,
                color: color.withValues(alpha: 0.7),
              ),
            ],
          ],
        ),
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
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  void _showDetailsDialog(BuildContext context, VerificationStatus status) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Verification Status',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusRow('Status', status.displayStatus),
            if (status.submittedAt != null)
              _buildStatusRow(
                'Submitted',
                _formatDate(status.submittedAt!),
              ),
            if (status.approvedAt != null)
              _buildStatusRow(
                'Approved',
                _formatDate(status.approvedAt!),
              ),
            if (status.notes != null && status.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Notes:',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                status.notes!,
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[700]),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: GoogleFonts.poppins(color: Colors.deepPurple),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
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
                  style: GoogleFonts.poppins(
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
            style: GoogleFonts.poppins(
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
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
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
