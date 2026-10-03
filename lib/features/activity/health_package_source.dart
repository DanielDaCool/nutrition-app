// The real [HealthSource]: a thin adapter over the `health` plugin.
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:health/health.dart' as hp;

import 'health_source.dart';

/// [HealthSource] backed by the `health` package (Health Connect on Android).
///
/// On anything other than Android (web included) it reports
/// [HcAvailability.unsupported] and never touches the platform channel.
class HealthPackageSource implements HealthSource {
  /// [health] and [isAndroid] are overridable for tests; by default a new
  /// plugin client is created lazily and the platform is detected.
  HealthPackageSource({hp.Health? health, bool? isAndroid})
    : _healthOverride = health,
      // Platform.* throws on web, so check kIsWeb first.
      _isAndroid = isAndroid ?? (!kIsWeb && Platform.isAndroid);

  // Requested together so the OS permission screen offers all of them in one
  // go; whether each is actually granted is then checked independently
  // (Health Connect lets the user toggle each one on its own).
  static const _types = [
    hp.HealthDataType.STEPS,
    hp.HealthDataType.WORKOUT,
    hp.HealthDataType.DISTANCE_DELTA,
    hp.HealthDataType.TOTAL_CALORIES_BURNED,
    hp.HealthDataType.ACTIVE_ENERGY_BURNED,
  ];
  static const _access = [
    hp.HealthDataAccess.READ,
    hp.HealthDataAccess.READ,
    hp.HealthDataAccess.READ,
    hp.HealthDataAccess.READ,
    hp.HealthDataAccess.READ,
  ];

  static const _stepsTypes = [hp.HealthDataType.STEPS];
  static const _stepsAccess = [hp.HealthDataAccess.READ];

  // Reading WORKOUT makes the plugin also read distance and calorie records
  // inside each session (health 13.3.2 HealthDataReader.handleWorkoutData).
  // Without those permissions every workout read throws on the native side
  // and comes back as an empty list, so a workout sync needs all of them,
  // not just WORKOUT itself.
  static const _workoutTypes = [
    hp.HealthDataType.WORKOUT,
    hp.HealthDataType.DISTANCE_DELTA,
    hp.HealthDataType.TOTAL_CALORIES_BURNED,
    hp.HealthDataType.ACTIVE_ENERGY_BURNED,
  ];
  static const _workoutAccess = [
    hp.HealthDataAccess.READ,
    hp.HealthDataAccess.READ,
    hp.HealthDataAccess.READ,
    hp.HealthDataAccess.READ,
  ];

  static const _activeCaloriesTypes = [hp.HealthDataType.ACTIVE_ENERGY_BURNED];
  static const _activeCaloriesAccess = [hp.HealthDataAccess.READ];

  final hp.Health? _healthOverride;
  final bool _isAndroid;
  hp.Health? _health;
  bool _configured = false;

  Future<hp.Health> _client() async {
    final h = _health ??= _healthOverride ?? hp.Health();
    if (!_configured) {
      await h.configure();
      _configured = true;
    }
    return h;
  }

  @override
  Future<HcAvailability> availability() async {
    if (!_isAndroid) return HcAvailability.unsupported;
    final status = await (await _client()).getHealthConnectSdkStatus();
    return switch (status) {
      hp.HealthConnectSdkStatus.sdkAvailable => HcAvailability.available,
      hp.HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired =>
        HcAvailability.updateRequired,
      hp.HealthConnectSdkStatus.sdkUnavailable => HcAvailability.notInstalled,
      null => HcAvailability.unsupported,
    };
  }

  @override
  Future<bool> hasPermissions() async =>
      await hasStepsPermission() || await hasWorkoutPermission();

  @override
  Future<bool> hasStepsPermission() =>
      _hasPermission(_stepsTypes, _stepsAccess);

  @override
  Future<bool> hasWorkoutPermission() =>
      _hasPermission(_workoutTypes, _workoutAccess);

  @override
  Future<bool> hasActiveCaloriesPermission() =>
      _hasPermission(_activeCaloriesTypes, _activeCaloriesAccess);

  Future<bool> _hasPermission(
    List<hp.HealthDataType> types,
    List<hp.HealthDataAccess> access,
  ) async {
    if (!_isAndroid) return false;
    final granted = await (await _client()).hasPermissions(
      types,
      permissions: access,
    );
    return granted ?? false;
  }

  @override
  Future<bool> requestPermissions() async {
    if (!_isAndroid) return false;
    return (await _client()).requestAuthorization(_types, permissions: _access);
  }

  @override
  Future<bool> isHistoryAvailable() async {
    if (!_isAndroid) return false;
    return (await _client()).isHealthDataHistoryAvailable();
  }

  @override
  Future<bool> isHistoryAuthorized() async {
    if (!_isAndroid) return false;
    return (await _client()).isHealthDataHistoryAuthorized();
  }

  @override
  Future<bool> requestHistoryAuthorization() async {
    if (!_isAndroid) return false;
    return (await _client()).requestHealthDataHistoryAuthorization();
  }

  @override
  Future<bool> isBackgroundAvailable() async {
    if (!_isAndroid) return false;
    return (await _client()).isHealthDataInBackgroundAvailable();
  }

  @override
  Future<bool> isBackgroundAuthorized() async {
    if (!_isAndroid) return false;
    return (await _client()).isHealthDataInBackgroundAuthorized();
  }

  @override
  Future<bool> requestBackgroundAuthorization() async {
    if (!_isAndroid) return false;
    return (await _client()).requestHealthDataInBackgroundAuthorization();
  }

  @override
  Future<int?> totalSteps(DateTime start, DateTime end) async {
    if (!_isAndroid) return null;
    return (await _client()).getTotalStepsInInterval(start, end);
  }

  @override
  Future<double?> totalActiveCalories(DateTime start, DateTime end) async {
    if (!_isAndroid) return null;
    // Health Connect's own aggregation dedupes overlapping records from more
    // than one source app (e.g. a watch and its phone app both writing
    // active calories) by source priority, the same way
    // [totalSteps]/getTotalStepsInInterval does for steps. Summing raw
    // getHealthDataFromTypes records instead (as this used to) double-counts
    // whenever more than one app wrote overlapping data.
    final points = await (await _client()).getHealthAggregateDataFromTypes(
      types: const [hp.HealthDataType.ACTIVE_ENERGY_BURNED],
      startDate: start,
      endDate: end,
    );
    double total = 0;
    for (final p in points) {
      final value = p.value;
      if (value is! hp.NumericHealthValue) continue;
      total += value.numericValue.toDouble();
    }
    return total;
  }

  @override
  Future<List<HcWorkout>> workouts(DateTime start, DateTime end) async {
    if (!_isAndroid) return const [];
    final points = await (await _client()).getHealthDataFromTypes(
      types: const [hp.HealthDataType.WORKOUT],
      startTime: start,
      endTime: end,
    );
    final result = <HcWorkout>[];
    for (final p in points) {
      final value = p.value;
      if (value is! hp.WorkoutHealthValue || p.uuid.isEmpty) continue;
      final kcal = value.totalEnergyBurned;
      result.add(
        HcWorkout(
          id: p.uuid,
          start: p.dateFrom,
          end: p.dateTo,
          activityType: value.workoutActivityType.name,
          // health 13.3.x does not pass ExerciseSessionRecord.title through.
          title: null,
          sourceApp: p.sourceName.isEmpty ? null : p.sourceName,
          kcal: kcal == null || kcal <= 0 ? null : kcal.toDouble(),
        ),
      );
    }
    return result;
  }

  @override
  Future<void> installHealthConnect() async {
    if (!_isAndroid) return;
    await (await _client()).installHealthConnect();
  }
}
