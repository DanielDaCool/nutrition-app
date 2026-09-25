import 'dart:io' show Platform;

import 'package:health/health.dart' as hp;

import 'health_source.dart';

/// [HealthSource] backed by the `health` package (Health Connect on Android).
///
/// On anything other than Android it reports [HcAvailability.unsupported] and
/// never touches the platform channel.
class HealthPackageSource implements HealthSource {
  HealthPackageSource({hp.Health? health, bool? isAndroid})
    : _healthOverride = health,
      _isAndroid = isAndroid ?? Platform.isAndroid;

  // Reading WORKOUT makes the plugin also read distance and calorie records
  // inside each session (health 13.3.2 HealthDataReader.handleWorkoutData).
  // Without those permissions every workout read throws on the native side
  // and comes back as an empty list, so they're requested too.
  static const _types = [
    hp.HealthDataType.STEPS,
    hp.HealthDataType.WORKOUT,
    hp.HealthDataType.DISTANCE_DELTA,
    hp.HealthDataType.TOTAL_CALORIES_BURNED,
  ];
  static const _access = [
    hp.HealthDataAccess.READ,
    hp.HealthDataAccess.READ,
    hp.HealthDataAccess.READ,
    hp.HealthDataAccess.READ,
  ];

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
  Future<bool> hasPermissions() async {
    if (!_isAndroid) return false;
    final granted = await (await _client()).hasPermissions(
      _types,
      permissions: _access,
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
  Future<int?> totalSteps(DateTime start, DateTime end) async {
    if (!_isAndroid) return null;
    return (await _client()).getTotalStepsInInterval(start, end);
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
