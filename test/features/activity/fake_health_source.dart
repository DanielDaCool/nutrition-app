import 'dart:async';

import 'package:nutrition_app/core/day_key.dart';
import 'package:nutrition_app/features/activity/health_source.dart';

/// In-memory [HealthSource] that records what was asked of it.
class FakeHealthSource implements HealthSource {
  HcAvailability availabilityValue = HcAvailability.available;

  /// Default for all three granular permissions below, unless overridden.
  bool permissionsGranted = true;

  /// Set to override the steps permission independently of
  /// [permissionsGranted] (e.g. to test one permission declined while
  /// another is granted).
  bool? stepsPermissionOverride;
  bool? workoutPermissionOverride;
  bool? activeCaloriesPermissionOverride;

  bool historyAvailable = true;
  bool historyAuthorized = false;

  bool backgroundAvailable = true;
  bool backgroundAuthorized = false;

  /// Granted when requested (simulates the user tapping "Allow").
  bool grantOnRequest = true;

  /// Steps per day key. Missing days report 0, like Health Connect.
  final Map<String, int?> stepsByDay = {};

  /// Active calories per day key. Missing days report 0, like Health Connect.
  final Map<String, double?> activeCaloriesByDay = {};
  final List<HcWorkout> workoutRecords = [];

  /// When set, every data call waits for it (to test concurrent syncs).
  Completer<void>? gate;

  /// When set, reading workouts throws this.
  Object? workoutsError;

  int availabilityCalls = 0;
  int requestPermissionCalls = 0;
  int requestHistoryCalls = 0;
  int requestBackgroundCalls = 0;
  int installCalls = 0;
  final List<(DateTime, DateTime)> stepCalls = [];
  final List<(DateTime, DateTime)> workoutCalls = [];

  @override
  Future<HcAvailability> availability() async {
    availabilityCalls++;
    if (gate != null) await gate!.future;
    return availabilityValue;
  }

  @override
  Future<bool> hasPermissions() async =>
      await hasStepsPermission() || await hasWorkoutPermission();

  @override
  Future<bool> hasStepsPermission() async =>
      stepsPermissionOverride ?? permissionsGranted;

  @override
  Future<bool> hasWorkoutPermission() async =>
      workoutPermissionOverride ?? permissionsGranted;

  @override
  Future<bool> hasActiveCaloriesPermission() async =>
      activeCaloriesPermissionOverride ?? permissionsGranted;

  @override
  Future<bool> requestPermissions() async {
    requestPermissionCalls++;
    if (grantOnRequest) {
      permissionsGranted = true;
      stepsPermissionOverride = null;
      workoutPermissionOverride = null;
      activeCaloriesPermissionOverride = null;
    }
    return hasPermissions();
  }

  @override
  Future<bool> isHistoryAvailable() async => historyAvailable;

  @override
  Future<bool> isHistoryAuthorized() async => historyAuthorized;

  @override
  Future<bool> requestHistoryAuthorization() async {
    requestHistoryCalls++;
    if (grantOnRequest) historyAuthorized = true;
    return historyAuthorized;
  }

  @override
  Future<bool> isBackgroundAvailable() async => backgroundAvailable;

  @override
  Future<bool> isBackgroundAuthorized() async => backgroundAuthorized;

  @override
  Future<bool> requestBackgroundAuthorization() async {
    requestBackgroundCalls++;
    if (grantOnRequest) backgroundAuthorized = true;
    return backgroundAuthorized;
  }

  @override
  Future<int?> totalSteps(DateTime start, DateTime end) async {
    stepCalls.add((start, end));
    final key = dayKeyOf(start);
    return stepsByDay.containsKey(key) ? stepsByDay[key] : 0;
  }

  @override
  Future<double?> totalActiveCalories(DateTime start, DateTime end) async {
    final key = dayKeyOf(start);
    return activeCaloriesByDay.containsKey(key) ? activeCaloriesByDay[key] : 0;
  }

  @override
  Future<List<HcWorkout>> workouts(DateTime start, DateTime end) async {
    workoutCalls.add((start, end));
    if (workoutsError != null) throw workoutsError!;
    return workoutRecords
        .where((w) => w.end.isAfter(start) && w.start.isBefore(end))
        .toList();
  }

  @override
  Future<void> installHealthConnect() async => installCalls++;
}
