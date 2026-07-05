import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/app_logger.dart';
import '../models/driver_availability.dart';
import '../providers/availability_provider.dart';

class WorkingHoursSection extends ConsumerStatefulWidget {
  final String vehicleId;
  final DriverAvailability availability;

  const WorkingHoursSection({
    super.key,
    required this.vehicleId,
    required this.availability,

  });


  @override
  ConsumerState<WorkingHoursSection> createState() => _WorkingHoursSectionState();
}

class _WorkingHoursSectionState extends ConsumerState<WorkingHoursSection> {
  late TextEditingController _startTimeController;
  late TextEditingController _endTimeController;
  String? _validationError;

  @override
  void initState() {
    AppLogger.debug('Working Hours Section loaded for vehicleId: ${widget.vehicleId}', tag: 'WorkingHours');
    super.initState();
    _startTimeController = TextEditingController(
      text: widget.availability.customHours?.startTime ?? '09:00',
    );
    _endTimeController = TextEditingController(
      text: widget.availability.customHours?.endTime ?? '18:00',
    );
  }

  @override
  void dispose() {
    _startTimeController.dispose();
    _endTimeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
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
              Icon(Icons.access_time, color: Colors.green[700], size: 20),
              const SizedBox(width: 8),
              const Text(
                'Working Hours',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Set your availability schedule',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          
          _buildModeOption(
            'Always Available',
            'Accept trips 24/7',
            Icons.all_inclusive,
            Colors.green,
            'always_available',
          ),
          
          _buildModeOption(
            'Day Shift (6 AM - 6 PM)',
            'Only daytime trips',
            Icons.wb_sunny,
            Colors.orange,
            'day_shift',
          ),
          
          _buildModeOption(
            'Night Shift (6 PM - 6 AM)',
            'Only nighttime trips',
            Icons.nightlight_round,
            Colors.indigo,
            'night_shift',
          ),
          
          _buildModeOption(
            'Custom Hours',
            'Set your own schedule',
            Icons.schedule,
            Colors.blue,
            'custom',
          ),
          
          if (widget.availability.workingMode == 'custom') ...[
            const SizedBox(height: 16),
            _buildCustomHoursInput(),
          ],
        ],
      ),
    );
  }

  Widget _buildModeOption(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    String mode,
  ) {
    final isSelected = widget.availability.workingMode == mode;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() => _validationError = null);
            
            if (mode == 'custom') {
              ref.read(availabilityProvider(widget.vehicleId).notifier)
                 .updateWorkingMode(mode, customHours: CustomHours(
                   startTime: _startTimeController.text,
                   endTime: _endTimeController.text,
                 ));
            } else {
              ref.read(availabilityProvider(widget.vehicleId).notifier)
                 .updateWorkingMode(mode);
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSelected ? color.withValues(alpha:0.1) : Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? color : Colors.grey[300]!,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isSelected ? color : Colors.grey[400],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? color : Colors.black87,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle, color: color, size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomHoursInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Set Custom Hours',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.blue[900],
            ),
          ),
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: _buildTimeField(
                  'Start Time',
                  _startTimeController,
                  Icons.login,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTimeField(
                  'End Time',
                  _endTimeController,
                  Icons.logout,
                ),
              ),
            ],
          ),
          
          if (_validationError != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _validationError!,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: Colors.red[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saveCustomHours,
              icon: const Icon(Icons.check, size: 18),
              label: const Text(
                'Apply Custom Hours',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeField(String label, TextEditingController controller, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.blue[900],
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: true,
          onTap: () => _selectTime(context, controller),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            prefixIcon: Icon(icon, color: Colors.blue[700], size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.blue[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.blue[300]!),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Future<void> _selectTime(BuildContext context, TextEditingController controller) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _parseTime(controller.text),
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
      setState(() {
        controller.text = _formatTime(picked);
        _validationError = null;
      });
    }
  }

  TimeOfDay _parseTime(String time) {
    final parts = time.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  void _saveCustomHours() {
    // ✅ VALIDATION
    final error = _validateCustomHours(
      _startTimeController.text,
      _endTimeController.text,
    );

    if (error != null) {
      setState(() => _validationError = error);
      return;
    }

    // ✅ Save if validation passes
    ref.read(availabilityProvider(widget.vehicleId).notifier)
       .updateCustomHours(_startTimeController.text, _endTimeController.text);

    setState(() => _validationError = null);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Text(
              'Custom hours applied successfully',
              style: TextStyle(fontFamily: 'Poppins'),
            ),
          ],
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ✅ VALIDATION LOGIC
  String? _validateCustomHours(String startTime, String endTime) {
    // Check if empty
    if (startTime.isEmpty || endTime.isEmpty) {
      return 'Please select both start and end times';
    }

    // Parse times
    final startParts = startTime.split(':');
    final endParts = endTime.split(':');

    if (startParts.length != 2 || endParts.length != 2) {
      return 'Invalid time format. Use HH:mm format';
    }

    final startHour = int.tryParse(startParts[0]);
    final startMinute = int.tryParse(startParts[1]);
    final endHour = int.tryParse(endParts[0]);
    final endMinute = int.tryParse(endParts[1]);

    if (startHour == null || startMinute == null || endHour == null || endMinute == null) {
      return 'Invalid time values';
    }

    // Validate ranges
    if (startHour < 0 || startHour > 23 || endHour < 0 || endHour > 23) {
      return 'Hours must be between 0 and 23';
    }

    if (startMinute < 0 || startMinute > 59 || endMinute < 0 || endMinute > 59) {
      return 'Minutes must be between 0 and 59';
    }

    // Convert to minutes for comparison
    final startTotalMinutes = startHour * 60 + startMinute;
    final endTotalMinutes = endHour * 60 + endMinute;

    // Check if end is after start
    if (endTotalMinutes <= startTotalMinutes) {
      return 'End time must be after start time';
    }

    // Check minimum duration (1 hour)
    final durationMinutes = endTotalMinutes - startTotalMinutes;
    if (durationMinutes < 60) {
      return 'Minimum shift duration is 1 hour';
    }

    // Check maximum duration (16 hours)
    if (durationMinutes > 960) {
      return 'Maximum shift duration is 16 hours';
    }

    return null; // ✅ Validation passed
  }
}
