import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/driver_status_provider.dart';
import '../../providers/verification_provider.dart';
import '../../services/document_verification_service.dart';

/// A toggle widget for driver online/offline status
class DriverOnlineToggle extends ConsumerWidget {
  final String userId;
  final bool showLabel;
  final bool compact;

  const DriverOnlineToggle({
    super.key,
    required this.userId,
    this.showLabel = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusState = ref.watch(driverOnlineProvider(userId));

    if (compact) {
      return _buildCompactToggle(context, ref, statusState);
    }

    return _buildFullToggle(context, ref, statusState);
  }

  Widget _buildCompactToggle(
    BuildContext context,
    WidgetRef ref,
    DriverOnlineState statusState,
  ) {
    return GestureDetector(
      onTap: statusState.isLoading
          ? null
          : () => ref.read(driverOnlineProvider(userId).notifier).toggleOnline(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: statusState.isOnline
              ? Colors.green.shade50
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: statusState.isOnline
                ? Colors.green.shade400
                : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (statusState.isLoading)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(
                    statusState.isOnline ? Colors.green : Colors.grey,
                  ),
                ),
              )
            else
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusState.isOnline
                      ? Colors.green.shade500
                      : Colors.grey.shade400,
                  boxShadow: statusState.isOnline
                      ? [
                          BoxShadow(
                            color: Colors.green.withValues(alpha: 0.4),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              ),
            const SizedBox(width: 8),
            Text(
              statusState.isOnline ? 'Online' : 'Offline',
              style: TextStyle(fontFamily: 'Poppins', 
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: statusState.isOnline
                    ? Colors.green.shade700
                    : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullToggle(
    BuildContext context,
    WidgetRef ref,
    DriverOnlineState statusState,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: statusState.isOnline
              ? [Colors.green.shade500, Colors.green.shade600]
              : [Colors.grey.shade400, Colors.grey.shade500],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (statusState.isOnline ? Colors.green : Colors.grey)
                .withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Status indicator
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: statusState.isLoading
                ? const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Icon(
                    statusState.isOnline
                        ? Icons.wifi_rounded
                        : Icons.wifi_off_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
          ),
          const SizedBox(width: 16),

          // Status text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusState.isOnline
                      ? 'You are Online'
                      : 'You are Offline',
                  style: TextStyle(fontFamily: 'Poppins', 
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  statusState.isOnline
                      ? 'Accepting ride requests'
                      : 'Tap to start receiving rides',
                  style: TextStyle(fontFamily: 'Poppins', 
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),

          // Toggle switch
          Transform.scale(
            scale: 1.2,
            child: Switch(
              value: statusState.isOnline,
              onChanged: statusState.isLoading
                  ? null
                  : (value) => ref
                      .read(driverOnlineProvider(userId).notifier)
                      .toggleOnline(),
              activeThumbColor: Colors.white,
              activeTrackColor: Colors.white.withValues(alpha: 0.4),
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}

/// A header card variant for driver dashboard
class DriverOnlineStatusCard extends ConsumerWidget {
  final String userId;

  const DriverOnlineStatusCard({
    super.key,
    required this.userId,
  });

  /// Get effective userId, falling back to FirebaseAuth if empty
  String get _effectiveUserId {
    if (userId.isNotEmpty) return userId;
    return FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effectiveId = _effectiveUserId;
    if (effectiveId.isEmpty) {
      return _buildLoadingCard();
    }

    final statusState = ref.watch(driverOnlineProvider(effectiveId));
    // Use stream provider for real-time eligibility updates
    final eligibilityAsync = ref.watch(onlineEligibilityStreamProvider(effectiveId));

    // Check eligibility first
    return eligibilityAsync.when(
      data: (eligibility) {
        if (!eligibility.canGoOnline) {
          return _buildVerificationRequired(context, eligibility);
        }
        return _buildOnlineStatusCard(context, ref, statusState);
      },
      loading: () => _buildLoadingCard(),
      error: (e, s) => _buildOnlineStatusCard(context, ref, statusState),
    );
  }

  Widget _buildVerificationRequired(
    BuildContext context,
    OnlineEligibility eligibility,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.orange.shade500, Colors.orange.shade600],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verification Required',
                      style: TextStyle(fontFamily: 'Poppins', 
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      eligibility.reason ?? 'Complete verification to go online',
                      style: TextStyle(fontFamily: 'Poppins', 
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _navigateToVerification(context, eligibility),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.orange.shade700,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_getActionIcon(eligibility), size: 22),
                  const SizedBox(width: 8),
                  Text(
                    _getActionButtonText(eligibility),
                    style: TextStyle(fontFamily: 'Poppins', 
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getActionIcon(OnlineEligibility eligibility) {
    if (eligibility.missingItems.contains('vehicle_registration')) {
      return Icons.directions_car_outlined;
    } else if (eligibility.missingItems.contains('vehicle_documents')) {
      return Icons.upload_file_outlined;
    } else if (eligibility.missingItems.contains('verification_under_review')) {
      return Icons.hourglass_empty;
    }
    return Icons.verified_outlined;
  }

  String _getActionButtonText(OnlineEligibility eligibility) {
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

  void _navigateToVerification(BuildContext context, OnlineEligibility eligibility) {
    final effectiveId = _effectiveUserId;
    if (eligibility.missingItems.contains('vehicle_registration')) {
      context.push('/vehicle-registration?userId=$effectiveId');
    } else if (eligibility.missingItems.contains('vehicle_documents') ||
        eligibility.missingItems.contains('verification_rejected')) {
      // No approved/submitted docs yet — go to upload screen
      context.push('/document-upload?userId=$effectiveId');
    } else if (eligibility.missingItems.contains('verification_under_review')) {
      // Docs submitted, waiting for admin — show profile/status, not upload
      context.push('/driver-profile?userId=$effectiveId');
    } else {
      context.push('/driver-profile?userId=$effectiveId');
    }
  }

  Widget _buildLoadingCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.grey.shade400, Colors.grey.shade500],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildOnlineStatusCard(
    BuildContext context,
    WidgetRef ref,
    DriverOnlineState statusState,
  ) {
    final effectiveId = _effectiveUserId;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: statusState.isOnline
              ? [Colors.green.shade600, Colors.teal.shade500]
              : [Colors.grey.shade500, Colors.blueGrey.shade400],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (statusState.isOnline ? Colors.green : Colors.grey)
                .withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Animated status icon
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: statusState.isLoading
                    ? const SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          statusState.isOnline
                              ? Icons.power_settings_new_rounded
                              : Icons.power_off_rounded,
                          key: ValueKey(statusState.isOnline),
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
              ),
              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        statusState.isOnline
                            ? 'You\'re Online!'
                            : 'You\'re Offline',
                        key: ValueKey(statusState.isOnline),
                        style: TextStyle(fontFamily: 'Poppins', 
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusState.isOnline
                          ? 'Ready to accept ride requests'
                          : 'Go online to receive rides',
                      style: TextStyle(fontFamily: 'Poppins', 
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Toggle button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: statusState.isLoading
                  ? null
                  : () => ref
                      .read(driverOnlineProvider(effectiveId).notifier)
                      .toggleOnline(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: statusState.isOnline
                    ? Colors.red.shade600
                    : Colors.green.shade600,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    statusState.isOnline
                        ? Icons.stop_circle_outlined
                        : Icons.play_circle_outlined,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    statusState.isOnline ? 'Go Offline' : 'Go Online',
                    style: TextStyle(fontFamily: 'Poppins', 
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Error message
          if (statusState.error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, size: 18, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      statusState.error!,
                      style: TextStyle(fontFamily: 'Poppins', 
                        fontSize: 12,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
