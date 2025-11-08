// lib/screens/weekly_schedule_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/weekly_schedule.dart';
import '../providers/schedule_provider.dart';

class WeeklyScheduleScreen extends ConsumerWidget {
  final String userId;
  final String vehicleId;

  const WeeklyScheduleScreen({
    super.key,
    required this.userId,
    required this.vehicleId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduleAsync = ref.watch(scheduleProvider(vehicleId));

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/availability?userId=$userId');
            }
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Weekly Schedule',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
            Text(
              'Set your availability',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          scheduleAsync.when(
            data: (_) => Container(
              margin: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.save, size: 20),
                ),
                onPressed: () => _saveSchedule(context, ref),
                tooltip: 'Save Schedule',
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: scheduleAsync.when(
        data: (schedule) => _buildScheduleContent(context, ref, schedule),
        loading: () => _buildLoadingState(),
        error: (error, stack) => _buildErrorState(context, ref, error),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
          ),
          const SizedBox(height: 16),
          const Text(
            'Loading schedule...',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleContent(BuildContext context, WidgetRef ref, WeeklySchedule schedule) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue[700]!, Colors.blue[500]!],
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.info_outline,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Manage Your Availability',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Toggle days and set times when your vehicle is available',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildQuickStats(schedule),
                const SizedBox(height: 20),
                _buildQuickActions(context, ref),
                const SizedBox(height: 24),
                _buildDayCards(context, ref, schedule),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStats(WeeklySchedule schedule) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            '${schedule.activeDaysCount}',
            'Active Days',
            Icons.check_circle,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            '${7 - schedule.activeDaysCount}',
            'Inactive Days',
            Icons.cancel,
            Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flash_on, color: Colors.blue[700], size: 20),
              const SizedBox(width: 8),
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildActionButton(
                context,
                ref,
                'Copy Monday',
                Icons.content_copy,
                Colors.blue,
                    () {
                  ref.read(scheduleProvider(vehicleId).notifier).copyMondayToAll();
                  _showSnackBar(context, 'Monday schedule copied to all days', Colors.blue);
                },
              ),
              _buildActionButton(
                context,
                ref,
                'Reset All',
                Icons.refresh,
                Colors.orange,
                    () {
                  _showResetConfirmation(context, ref);
                },
              ),
              _buildPresetButton(context, ref),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
      BuildContext context,
      WidgetRef ref,
      String label,
      IconData icon,
      Color color,
      VoidCallback onPressed,
      ) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresetButton(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      onSelected: (preset) {
        ref.read(scheduleProvider(vehicleId).notifier).applyPreset(preset);
        String presetName = preset.replaceAll('_', ' ').toUpperCase();
        _showSnackBar(context, 'Applied $presetName preset', Colors.green);
      },
      itemBuilder: (context) => [
        _buildPresetMenuItem('weekdays', 'Weekdays (Mon-Fri)', Icons.work),
        _buildPresetMenuItem('weekends', 'Weekends (Sat-Sun)', Icons.weekend),
        _buildPresetMenuItem('all', 'All Days', Icons.calendar_month),
      ],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Material(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.apps, size: 18, color: Colors.green[700]),
              const SizedBox(width: 8),
              Text(
                'Presets',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.green[700],
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_drop_down, size: 18, color: Colors.green[700]),
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildPresetMenuItem(String value, String label, IconData icon) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[700]),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCards(BuildContext context, WidgetRef ref, WeeklySchedule schedule) {
    final days = [
      {'key': 'monday', 'label': 'Monday', 'short': 'MON', 'icon': Icons.calendar_today},
      {'key': 'tuesday', 'label': 'Tuesday', 'short': 'TUE', 'icon': Icons.calendar_today},
      {'key': 'wednesday', 'label': 'Wednesday', 'short': 'WED', 'icon': Icons.calendar_today},
      {'key': 'thursday', 'label': 'Thursday', 'short': 'THU', 'icon': Icons.calendar_today},
      {'key': 'friday', 'label': 'Friday', 'short': 'FRI', 'icon': Icons.calendar_today},
      {'key': 'saturday', 'label': 'Saturday', 'short': 'SAT', 'icon': Icons.weekend},
      {'key': 'sunday', 'label': 'Sunday', 'short': 'SUN', 'icon': Icons.weekend},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.event, color: Colors.blue[700], size: 20),
            const SizedBox(width: 8),
            const Text(
              'Weekly Schedule',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...days.map((day) => _buildDayCard(
          context,
          ref,
          day['key'] as String,
          day['label'] as String,
          day['short'] as String,
          day['icon'] as IconData,
          schedule,
        )),
      ],
    );
  }

  Widget _buildDayCard(
      BuildContext context,
      WidgetRef ref,
      String dayKey,
      String dayLabel,
      String dayShort,
      IconData icon,
      WeeklySchedule schedule,
      ) {
    final isActive = schedule.dayActive[dayKey] ?? false;
    final timeSlot = schedule.dayTimes[dayKey];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? Colors.blue[700]! : Colors.grey.shade200,
          width: isActive ? 2 : 1,
        ),
        boxShadow: [
          if (isActive)
            BoxShadow(
              color: Colors.blue.withValues(alpha:0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Material(
              color: isActive ? Colors.blue[50] : Colors.grey[50],
              child: InkWell(
                onTap: () {
                  ref.read(scheduleProvider(vehicleId).notifier).toggleDay(dayKey);
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: isActive ? Colors.blue[700] : Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              icon,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              dayShort,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dayLabel,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isActive ? Colors.black87 : Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 2),
                            if (isActive && timeSlot != null)
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 14,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    timeSlot.format(),
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 13,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              )
                            else
                              Text(
                                'Tap to activate',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                          ],
                        ),
                      ),
                      Transform.scale(
                        scale: 0.9,
                        child: Switch(
                          value: isActive,
                          onChanged: (_) {
                            ref.read(scheduleProvider(vehicleId).notifier).toggleDay(dayKey);
                          },
                          activeThumbColor: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (isActive && timeSlot != null)
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildTimePicker(
                        context,
                        ref,
                        dayKey,
                        'Start Time',
                        timeSlot.start,
                        true,
                        Icons.login,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.arrow_forward, color: Colors.grey[400], size: 20),
                    ),
                    Expanded(
                      child: _buildTimePicker(
                        context,
                        ref,
                        dayKey,
                        'End Time',
                        timeSlot.end,
                        false,
                        Icons.logout,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePicker(
      BuildContext context,
      WidgetRef ref,
      String dayKey,
      String label,
      TimeOfDay time,
      bool isStart,
      IconData icon,
      ) {
    return Material(
      color: Colors.blue[50],
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () async {
          final picked = await showTimePicker(
            context: context,
            initialTime: time,
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: ColorScheme.light(
                    primary: Colors.blue[700]!,
                  ),
                ),
                child: child!,
              );
            },
          );

          if (picked != null) {
            final schedule = ref.read(scheduleProvider(vehicleId)).valueOrNull;
            if (schedule == null) return;

            final currentSlot = schedule.dayTimes[dayKey]!;
            final newSlot = isStart
                ? TimeSlot(start: picked, end: currentSlot.end)
                : TimeSlot(start: currentSlot.start, end: picked);

            ref.read(scheduleProvider(vehicleId).notifier).updateTime(dayKey, newSlot);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 14, color: Colors.blue[700]),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red[50],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
            ),
            const SizedBox(height: 24),
            const Text(
              'Oops! Something went wrong',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                ref.read(scheduleProvider(vehicleId).notifier).loadSchedule();
              },
              icon: const Icon(Icons.refresh),
              label: const Text(
                'Try Again',
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showResetConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange[700]),
            const SizedBox(width: 12),
            const Text(
              'Reset Schedule?',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          'This will deactivate all days and reset times to 9:00 AM - 5:00 PM. This action cannot be undone.',
          style: TextStyle(fontFamily: 'Poppins', fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(fontFamily: 'Poppins', color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(scheduleProvider(vehicleId).notifier).reset();
              _showSnackBar(context, 'Schedule reset successfully', Colors.orange);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text(
              'Reset',
              style: TextStyle(fontFamily: 'Poppins', color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontFamily: 'Poppins'),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _saveSchedule(BuildContext context, WidgetRef ref) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Saving schedule...',
                style: TextStyle(fontFamily: 'Poppins'),
              ),
            ],
          ),
          backgroundColor: Colors.blue[700],
          duration: const Duration(seconds: 1),
        ),
      );

      await ref.read(scheduleProvider(vehicleId).notifier).saveSchedule();

      if (context.mounted) {
        _showSnackBar(context, 'Schedule saved successfully!', Colors.green);
      }
    } catch (e) {
      if (context.mounted) {
        _showSnackBar(context, 'Failed to save: ${e.toString()}', Colors.red);
      }
    }
  }
}
