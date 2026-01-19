// lib/models/weekly_schedule.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class WeeklySchedule {
  final Map<String, bool> dayActive;
  final Map<String, TimeSlot> dayTimes;

  WeeklySchedule({
    required this.dayActive,
    required this.dayTimes,
  });

  factory WeeklySchedule.empty() {
    return WeeklySchedule(
      dayActive: {
        'monday': false,
        'tuesday': false,
        'wednesday': false,
        'thursday': false,
        'friday': false,
        'saturday': false,
        'sunday': false,
      },
      dayTimes: {
        'monday': TimeSlot(start: const TimeOfDay(hour: 9, minute: 0), end: const TimeOfDay(hour: 17, minute: 0)),
        'tuesday': TimeSlot(start: const TimeOfDay(hour: 9, minute: 0), end: const TimeOfDay(hour: 17, minute: 0)),
        'wednesday': TimeSlot(start: const TimeOfDay(hour: 9, minute: 0), end: const TimeOfDay(hour: 17, minute: 0)),
        'thursday': TimeSlot(start: const TimeOfDay(hour: 9, minute: 0), end: const TimeOfDay(hour: 17, minute: 0)),
        'friday': TimeSlot(start: const TimeOfDay(hour: 9, minute: 0), end: const TimeOfDay(hour: 17, minute: 0)),
        'saturday': TimeSlot(start: const TimeOfDay(hour: 9, minute: 0), end: const TimeOfDay(hour: 17, minute: 0)),
        'sunday': TimeSlot(start: const TimeOfDay(hour: 9, minute: 0), end: const TimeOfDay(hour: 17, minute: 0)),
      },
    );
  }

  factory WeeklySchedule.fromFirestore(Map<String, dynamic> data) {
    final dayActive = Map<String, bool>.from(data['dayActive'] ?? {});
    final dayTimesData = data['dayTimes'] as Map<String, dynamic>? ?? {};

    final dayTimes = dayTimesData.map((key, value) {
      final timeData = value as Map<String, dynamic>;
      return MapEntry(
        key,
        TimeSlot.fromMap(timeData),
      );
    });

    return WeeklySchedule(
      dayActive: dayActive.isEmpty ? WeeklySchedule.empty().dayActive : dayActive,
      dayTimes: dayTimes.isEmpty ? WeeklySchedule.empty().dayTimes : dayTimes,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'dayActive': dayActive,
      'dayTimes': dayTimes.map((key, value) => MapEntry(key, value.toMap())),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // FIXED: Changed dayTimes parameter type from Map<String, dynamic> to Map<String, TimeSlot>
  WeeklySchedule copyWith({
    Map<String, bool>? dayActive,
    Map<String, TimeSlot>? dayTimes, // ← FIXED THIS LINE
  }) {
    return WeeklySchedule(
      dayActive: dayActive ?? this.dayActive,
      dayTimes: dayTimes ?? this.dayTimes,
    );
  }

  int get activeDaysCount => dayActive.values.where((active) => active).length;
}

class TimeSlot {
  final TimeOfDay start;
  final TimeOfDay end;

  TimeSlot({required this.start, required this.end});

  factory TimeSlot.fromMap(Map<String, dynamic> map) {
    return TimeSlot(
      start: TimeOfDay(
        hour: map['startHour'] ?? 9,
        minute: map['startMinute'] ?? 0,
      ),
      end: TimeOfDay(
        hour: map['endHour'] ?? 17,
        minute: map['endMinute'] ?? 0,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'startHour': start.hour,
      'startMinute': start.minute,
      'endHour': end.hour,
      'endMinute': end.minute,
    };
  }

  String format() {
    return '${_formatTime(start)} - ${_formatTime(end)}';
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  TimeSlot copyWith({
    TimeOfDay? start,
    TimeOfDay? end,
  }) {
    return TimeSlot(
      start: start ?? this.start,
      end: end ?? this.end,
    );
  }
}
