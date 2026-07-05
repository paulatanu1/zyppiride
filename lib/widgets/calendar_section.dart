import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/driver_availability.dart';
import '../providers/availability_provider.dart';
import '../utils/bengali_calendar.dart';

class CalendarSection extends ConsumerStatefulWidget {
  final String vehicleId;
  final DriverAvailability availability;

  const CalendarSection({
    super.key,
    required this.vehicleId,
    required this.availability,
  });

  @override
  ConsumerState<CalendarSection> createState() => _CalendarSectionState();
}

class _CalendarSectionState extends ConsumerState<CalendarSection> {
  DateTime _focusedDay = DateTime.now();
  final Set<DateTime> _selectedDates = {};
  bool _showBengaliCalendar = false;
  bool _isMultiSelectMode = false;

  @override
  Widget build(BuildContext context) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const Divider(height: 1),
          _buildSelectionModeToggle(),
          const Divider(height: 1),

          // ✅ FIXED: Wrap calendar in SizedBox with fixed height for better scrolling
          SizedBox(
            height: 380, // Fixed height to enable proper scrolling
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: _buildCalendar(),
            ),
          ),

          const Divider(height: 1),
          _buildActionButtons(),
          const Divider(height: 1),
          _buildLegend(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final bengaliDate = BengaliCalendar.toBengaliDate(_focusedDay);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, color: Colors.blue[700], size: 22),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Availability Calendar',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _showBengaliCalendar
                      ? bengaliDate.format(useBengaliDigits: true)
                      : DateFormat('MMMM yyyy').format(_focusedDay),
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'EN',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        fontWeight: _showBengaliCalendar ? FontWeight.normal : FontWeight.bold,
                        color: _showBengaliCalendar ? Colors.grey[600] : Colors.blue[700],
                      ),
                    ),
                    const SizedBox(width: 2),
                    Transform.scale(
                      scale: 0.6,
                      child: Switch(
                        value: _showBengaliCalendar,
                        onChanged: (value) {
                          setState(() => _showBengaliCalendar = value);
                        },
                        activeTrackColor: Colors.blue[700],
                        thumbColor: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.selected)) {
                            return Colors.white;
                          }
                          return null;
                        }),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      'বাং',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        fontWeight: _showBengaliCalendar ? FontWeight.bold : FontWeight.normal,
                        color: _showBengaliCalendar ? Colors.blue[700] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionModeToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.blue[50],
      child: Row(
        children: [
          Icon(
            _isMultiSelectMode ? Icons.check_box : Icons.check_box_outline_blank,
            color: Colors.blue[700],
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isMultiSelectMode ? 'Multi-Select Mode' : 'Single-Select Mode',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[900],
                  ),
                ),
                Text(
                  _isMultiSelectMode
                      ? 'Select multiple dates to block'
                      : 'Tap date to select, then mark as blocked/available',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: _isMultiSelectMode,
              onChanged: (value) {
                setState(() {
                  _isMultiSelectMode = value;
                  _selectedDates.clear();
                });
              },
              activeTrackColor: Colors.blue[700],
              thumbColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                return null;
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    return TableCalendar(
      firstDay: DateTime.now().subtract(const Duration(days: 1)),
      lastDay: DateTime.now().add(const Duration(days: 730)),
      focusedDay: _focusedDay,
      calendarFormat: CalendarFormat.month,
      startingDayOfWeek: StartingDayOfWeek.monday,

      selectedDayPredicate: (day) {
        return _selectedDates.any((selectedDate) =>
            isSameDay(selectedDate, day));
      },

      onDaySelected: (selectedDay, focusedDay) {
        if (selectedDay.isBefore(DateTime.now().subtract(const Duration(days: 1)))) {
          return;
        }

        setState(() {
          _focusedDay = focusedDay;

          if (_isMultiSelectMode) {
            // Multi-select: toggle date in selection
            final existingDate = _selectedDates.firstWhere(
                  (date) => isSameDay(date, selectedDay),
              orElse: () => DateTime(0),
            );

            if (existingDate.year == 0) {
              _selectedDates.add(selectedDay);
            } else {
              _selectedDates.remove(existingDate);
            }
          } else {
            // Single-select: replace selection
            _selectedDates.clear();
            _selectedDates.add(selectedDay);
          }
        });
      },

      onPageChanged: (focusedDay) {
        setState(() {
          _focusedDay = focusedDay;
        });
      },

      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        titleTextStyle: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        leftChevronIcon: Icon(Icons.chevron_left, size: 28),
        rightChevronIcon: Icon(Icons.chevron_right, size: 28),
      ),

      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey[700],
        ),
        weekendStyle: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey[700],
        ),
      ),

      calendarStyle: CalendarStyle(
        cellMargin: const EdgeInsets.all(6),
        cellPadding: EdgeInsets.zero,
        outsideDaysVisible: false,

        // Selected day style
        selectedDecoration: BoxDecoration(
          color: Colors.orange[400],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange[700]!, width: 2),
        ),
        selectedTextStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),

        // Today style
        todayDecoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue[400]!, width: 2),
        ),
        todayTextStyle: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.blue[900],
        ),
      ),

      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, day, focusedDay) {
          return _buildDayCell(day);
        },
        todayBuilder: (context, day, focusedDay) {
          return _buildDayCell(day, isToday: true);
        },
        selectedBuilder: (context, day, focusedDay) {
          return _buildDayCell(day, isSelected: true);
        },
      ),
    );
  }

  Widget _buildDayCell(DateTime day, {
    bool isToday = false,
    bool isSelected = false,
  }) {
    final dateString = DateFormat('yyyy-MM-dd').format(day);
    final isBlocked = widget.availability.blockedDates.contains(dateString);
    final isPast = day.isBefore(DateTime.now().subtract(const Duration(days: 1)));
    final bengaliDate = BengaliCalendar.toBengaliDate(day);

    Color backgroundColor;
    Color textColor;
    Color? borderColor;

    if (isPast) {
      backgroundColor = Colors.grey[100]!;
      textColor = Colors.grey[400]!;
      borderColor = Colors.grey[300];
    } else if (isSelected) {
      backgroundColor = Colors.orange[400]!;
      textColor = Colors.white;
      borderColor = Colors.orange[700];
    } else if (isToday) {
      backgroundColor = isBlocked ? Colors.red[50]! : Colors.green[50]!;
      textColor = isBlocked ? Colors.red[900]! : Colors.green[900]!;
      borderColor = Colors.blue[400];
    } else if (isBlocked) {
      backgroundColor = Colors.red[50]!;
      textColor = Colors.red[900]!;
      borderColor = Colors.red[300];
    } else {
      backgroundColor = Colors.green[50]!;
      textColor = Colors.green[900]!;
      borderColor = Colors.green[200];
    }

    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: borderColor != null
            ? Border.all(color: borderColor, width: isToday ? 2 : 1)
            : null,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _showBengaliCalendar
                  ? BengaliCalendar.toBengaliNumber(day.day)
                  : '${day.day}',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.w500,
                color: textColor,
              ),
            ),

            if (_showBengaliCalendar && !isSelected) ...[
              const SizedBox(height: 1),
              Text(
                bengaliDate.monthName.substring(0, 2),
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 8,
                  color: textColor.withValues(alpha: 0.6),
                ),
              ),
            ],

            if (isBlocked && !isSelected && !_showBengaliCalendar) ...[
              const SizedBox(height: 2),
              Icon(Icons.block, size: 10, color: Colors.red[700]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final hasSelection = _selectedDates.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (hasSelection) ...[
            Text(
              '${_selectedDates.length} date${_selectedDates.length > 1 ? 's' : ''} selected',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
          ],

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: hasSelection ? _markAsBlocked : null,
                  icon: const Icon(Icons.block, size: 18),
                  label: const Text(
                    'Mark as Blocked',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasSelection ? Colors.red[600] : Colors.grey[300],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: hasSelection ? 2 : 0,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: hasSelection ? _markAsAvailable : null,
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: const Text(
                    'Mark as Available',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasSelection ? Colors.green[600] : Colors.grey[300],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: hasSelection ? 2 : 0,
                  ),
                ),
              ),
            ],
          ),

          if (hasSelection) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                setState(() => _selectedDates.clear());
              },
              icon: const Icon(Icons.clear, size: 16),
              label: const Text(
                'Clear Selection',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Legend',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              _buildLegendItem(Colors.green[50]!, Colors.green[200]!, Colors.green[900]!, 'Available'),
              _buildLegendItem(Colors.red[50]!, Colors.red[300]!, Colors.red[900]!, 'Blocked'),
              _buildLegendItem(Colors.orange[400]!, Colors.orange[700]!, Colors.white, 'Selected'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color bgColor, Color borderColor, Color textColor, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Center(
            child: Text(
              '15',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  void _markAsBlocked() {
    for (final date in _selectedDates) {
      final dateString = DateFormat('yyyy-MM-dd').format(date);
      ref.read(availabilityProvider(widget.vehicleId).notifier).blockDate(dateString);
    }
    setState(() => _selectedDates.clear());
  }

  void _markAsAvailable() {
    for (final date in _selectedDates) {
      final dateString = DateFormat('yyyy-MM-dd').format(date);
      ref.read(availabilityProvider(widget.vehicleId).notifier).unblockDate(dateString);
    }
    setState(() => _selectedDates.clear());
  }
}
