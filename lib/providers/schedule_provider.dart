// lib/providers/schedule_provider.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/weekly_schedule.dart';

class ScheduleNotifier extends StateNotifier<AsyncValue<WeeklySchedule>> {
  final String vehicleId;
  final FirebaseFirestore _firestore;

  ScheduleNotifier(this.vehicleId, this._firestore) : super(const AsyncValue.loading()) {
    loadSchedule();
  }

  Future<void> loadSchedule() async {
    state = const AsyncValue.loading();
    try {
      final doc = await _firestore
          .collection('vehicles')
          .doc(vehicleId)
          .collection('schedules')
          .doc('weekly')
          .get();

      if (doc.exists) {
        state = AsyncValue.data(WeeklySchedule.fromFirestore(doc.data()!));
      } else {
        state = AsyncValue.data(WeeklySchedule.empty());
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> saveSchedule() async {
    final currentSchedule = state.valueOrNull;
    if (currentSchedule == null) return;

    try {
      await _firestore
          .collection('vehicles')
          .doc(vehicleId)
          .collection('schedules')
          .doc('weekly')
          .set(currentSchedule.toFirestore());
    } catch (e) {
      rethrow;
    }
  }

  void toggleDay(String day) {
    state.whenData((schedule) {
      final newDayActive = Map<String, bool>.from(schedule.dayActive);
      newDayActive[day] = !(newDayActive[day] ?? false);
      
      state = AsyncValue.data(schedule.copyWith(dayActive: newDayActive));
    });
  }

  void updateTime(String day, TimeSlot timeSlot) {
    state.whenData((schedule) {
      final newDayTimes = Map<String, TimeSlot>.from(schedule.dayTimes);
      newDayTimes[day] = timeSlot;
      
      state = AsyncValue.data(schedule.copyWith(dayTimes: newDayTimes));
    });
  }

  void copyMondayToAll() {
    state.whenData((schedule) {
      final mondayTime = schedule.dayTimes['monday'];
      if (mondayTime == null) return;

      final newDayTimes = <String, TimeSlot>{};
      for (var day in schedule.dayTimes.keys) {
        newDayTimes[day] = mondayTime;
      }

      state = AsyncValue.data(schedule.copyWith(dayTimes: newDayTimes));
    });
  }

  void reset() {
    state = AsyncValue.data(WeeklySchedule.empty());
  }

  void applyPreset(String preset) {
    state.whenData((schedule) {
      Map<String, bool> newDayActive;
      
      switch (preset) {
        case 'weekdays':
          newDayActive = {
            'monday': true,
            'tuesday': true,
            'wednesday': true,
            'thursday': true,
            'friday': true,
            'saturday': false,
            'sunday': false,
          };
          break;
        case 'weekends':
          newDayActive = {
            'monday': false,
            'tuesday': false,
            'wednesday': false,
            'thursday': false,
            'friday': false,
            'saturday': true,
            'sunday': true,
          };
          break;
        case 'all':
          newDayActive = {
            'monday': true,
            'tuesday': true,
            'wednesday': true,
            'thursday': true,
            'friday': true,
            'saturday': true,
            'sunday': true,
          };
          break;
        default:
          return;
      }

      state = AsyncValue.data(schedule.copyWith(dayActive: newDayActive));
    });
  }
}

final scheduleProvider = StateNotifierProvider.family<ScheduleNotifier, AsyncValue<WeeklySchedule>, String>(
  (ref, vehicleId) => ScheduleNotifier(vehicleId, FirebaseFirestore.instance),
);
