// OWNER: engine agent (A). Contract stub: keep the class name and constructor.
// Settings tab: current targets, check-in entry, profile form, Health
// Connect and data export.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../core/app_features.dart';
import '../../data/db/database.dart';
import '../../domain/models.dart';
import '../activity/widgets/health_connect_tile.dart';
import '../activity/widgets/step_goal_tile.dart';
import '../activity/widgets/walk_reminder_tile.dart';
import '../targets/checkin_screen.dart';
import '../targets/engine/engine.dart';
import '../targets/engine/explain.dart';
import '../targets/targets_providers.dart';
import '../weight/weight_providers.dart';
import 'data_export.dart';
import 'error_retry.dart';
import 'import_flow.dart';

/// The Settings tab of the home shell.
///
/// Until a profile exists the profile form comes first, since nothing else
/// works without it.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final missingProfile = profile.hasValue && profile.value == null;
    final isWeb = ref.watch(isWebProvider);
    const profileSection = [
      _SectionHeader('Profile', key: Key('profileHeader')),
      ProfileForm(key: Key('profileForm'), lockable: true),
    ];
    const targetsSection = [
      CurrentTargetsCard(key: Key('targetsCard')),
      CheckInTile(key: Key('checkInTile')),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (missingProfile) ...[
            const Padding(
              key: Key('startHere'),
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                'Start here: fill in your profile to get your daily targets.',
              ),
            ),
            ...profileSection,
            const Divider(),
            ...targetsSection,
          ] else ...[
            ...targetsSection,
            const Divider(),
            ...profileSection,
          ],
          // Health Connect and walk reminders are Android-only; the step
          // goal only applies to Health Connect steps.
          if (!isWeb) ...const [
            Divider(),
            HealthConnectSettingsTile(),
            StepGoalSettingsTile(),
            WalkReminderSettingsTile(),
          ],
          const Divider(),
          const _SectionHeader('Your data'),
          const ExportDataTile(),
          const ImportDataTile(),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

/// The targets in effect today.
class CurrentTargetsCard extends ConsumerWidget {
  const CurrentTargetsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targets = ref.watch(currentTargetsProvider);
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: targets.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) {
            debugPrint('Loading targets failed: $e');
            return ErrorRetry(
              message: "Couldn't load your targets",
              onRetry: () => ref.invalidate(currentTargetsProvider),
            );
          },
          data: (t) {
            if (t == null) {
              final hasProfile = ref.watch(profileProvider).value != null;
              return Text(
                hasProfile
                    ? 'No targets yet. Log your weight on Today and your '
                          'daily targets show up here.'
                    : 'No targets yet. Fill in your profile and log your '
                          'weight to get your daily targets.',
              );
            }
            final m = t.macros;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Daily targets', style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(kcal(m.kcal), style: theme.textTheme.headlineMedium),
                Text(
                  'Protein ${m.proteinG.round()} g · Fat ${m.fatG.round()} g · '
                  'Carbs ${m.carbsG.round()} g',
                ),
                const SizedBox(height: 4),
                Text(
                  'Maintenance about ${kcal(t.maintenanceKcal)} '
                  '(${_methodText(t.method)}) · since ${t.effectiveFrom}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

String _methodText(TargetMethod m) => switch (m) {
  TargetMethod.formula => 'formula',
  TargetMethod.blended => 'formula + your data',
  TargetMethod.adaptive => 'from your data',
};

/// Opens [CheckInScreen]; highlights when a check-in is due.
class CheckInTile extends ConsumerWidget {
  const CheckInTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = ref.watch(checkInDueProvider).value ?? false;
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Badge(
        isLabelVisible: due,
        child: Icon(
          due ? Icons.notification_important : Icons.event_repeat,
          color: due ? scheme.primary : null,
        ),
      ),
      title: const Text('Weekly check-in'),
      subtitle: Text(
        due
            ? 'Your check-in is ready, tap to review'
            : 'Review your targets any time',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const CheckInScreen())),
    );
  }
}

const _activityText = {
  ActivityLevel.sedentary: ('Sedentary', 'Desk job, little or no exercise'),
  ActivityLevel.light: ('Light', 'Light exercise 1–3 days a week'),
  ActivityLevel.moderate: ('Moderate', 'Exercise 3–5 days a week'),
  ActivityLevel.active: ('Active', 'Hard exercise 6–7 days a week'),
};

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// Whole years between [birthDate] and [now].
int ageOn(DateTime birthDate, DateTime now) {
  var age = now.year - birthDate.year;
  if (now.month < birthDate.month ||
      (now.month == birthDate.month && now.day < birthDate.day)) {
    age--;
  }
  return age;
}

/// Profile & goal settings, saved to the single Profiles row (id = 1).
///
/// Also used by the first-run setup: [extra] widgets (e.g. a weigh-in field)
/// go inside the same [Form] above the save button, so their validators run
/// with the profile's, and [onSaved] runs after the profile is stored instead
/// of the default "Profile saved" snackbar.
class ProfileForm extends ConsumerStatefulWidget {
  const ProfileForm({
    super.key,
    this.saveLabel = 'Save profile',
    this.extra = const [],
    this.onSaved,
    this.lockable = false,
  });

  /// Text on the save button.
  final String saveLabel;

  /// Extra form fields shown above the save button.
  final List<Widget> extra;

  /// Runs after the profile is saved; replaces the default snackbar.
  final Future<void> Function()? onSaved;

  /// When true and a profile already exists, the form opens read-only behind
  /// an "Edit" button, and saving asks for confirmation. First-run setup
  /// (no profile yet) is never locked, so this has no effect there.
  final bool lockable;

  @override
  ConsumerState<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<ProfileForm> {
  final _formKey = GlobalKey<FormState>();
  final _height = TextEditingController();
  final _goal = TextEditingController();
  Sex _sex = Sex.male;
  GoalDirection _goalDirection = GoalDirection.lose;
  DateTime? _birthDate;
  ActivityLevel _activity = ActivityLevel.light;
  double _ratePct = 0.5;
  double _proteinPerKg = 1.8;
  int _weekday = DateTime.sunday;
  bool _loaded = false;

  /// `updatedAt` of the profile row the fields were last loaded from.
  DateTime? _loadedUpdatedAt;
  bool _saving = false;
  bool _editing = false;
  String? _birthError;

  @override
  void dispose() {
    _height.dispose();
    _goal.dispose();
    super.dispose();
  }

  void _load(Profile? p) {
    if (_loaded) return;
    _loaded = true;
    if (p == null) return;
    _loadedUpdatedAt = p.updatedAt;
    _sex = Sex.values[p.sex];
    _goalDirection = GoalDirection.values[p.goalDirection];
    _birthDate = p.birthDate;
    _height.text = _num(p.heightCm);
    _activity = ActivityLevel.values[p.activityLevel];
    _goal.text = _num(p.goalWeightKg);
    _ratePct = p.weeklyRatePct.clamp(0.25, 1.0);
    _proteinPerKg = p.proteinPerKg.clamp(1.6, 2.2);
    _weekday = p.checkInWeekday;
  }

  static String _num(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  static double? _parse(String s) =>
      double.tryParse(s.trim().replaceAll(',', '.'));

  Future<void> _pickBirthDate() async {
    final now = ref.read(clockProvider)();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 30, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year - 13, now.month, now.day),
      initialEntryMode: DatePickerEntryMode.input,
      helpText: 'Birth date',
      fieldHintText: 'MM/DD/YYYY',
      errorFormatText: 'Type it like 09/25/1996',
      errorInvalidText: 'Pick a date at least 13 years ago',
    );
    if (picked != null) {
      setState(() {
        _birthDate = picked;
        _birthError = null;
      });
    }
  }

  bool get _hasExistingProfile => ref.read(profileProvider).value != null;

  void _startEditing() => setState(() => _editing = true);

  void _cancelEditing() {
    setState(() {
      _editing = false;
      _birthError = null;
      _loaded = false;
    });
    _load(ref.read(profileProvider).value);
  }

  Future<bool> _confirmSave() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save profile changes?'),
        content: const Text(
          'This updates your goal weight, height and other profile details.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirmSaveProfile'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Save changes'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _save() async {
    final formOk = _formKey.currentState!.validate();
    if (_birthDate == null) {
      setState(() => _birthError = 'Add your birth date');
    }
    if (!formOk || _birthDate == null) return;
    if (widget.lockable && _hasExistingProfile && !await _confirmSave()) {
      return;
    }
    if (!mounted) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final hasWeighIn = ref.read(weighInsProvider).value?.isNotEmpty ?? false;
    final checkInDue = ref.read(checkInDueProvider).value ?? false;
    try {
      final newTargets = await ref
          .read(targetsRepositoryProvider)
          .saveProfile(
            sex: _sex,
            birthDate: _birthDate!,
            heightCm: _parse(_height.text)!,
            activityLevel: _activity,
            goalWeightKg: _parse(_goal.text)!,
            weeklyRatePct: _ratePct,
            proteinPerKg: _proteinPerKg,
            checkInWeekday: _weekday,
            goalDirection: _goalDirection,
          );
      if (mounted) setState(() => _editing = false);
      final onSaved = widget.onSaved;
      if (onSaved != null) {
        await onSaved();
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              newTargets != null
                  ? 'Profile saved. New target: '
                        '${kcal(newTargets.macros.kcal)}'
                  : checkInDue
                  ? 'Profile saved. Your targets update at your weekly '
                        'check-in, which is due now.'
                  : hasWeighIn
                  ? 'Profile saved'
                  : 'Profile saved. Next: log your weight on Today to get '
                        'your targets.',
            ),
          ),
        );
      }
    } catch (e, s) {
      debugPrint('Saving profile failed: $e\n$s');
      messenger.showSnackBar(
        SnackBar(
          content: const Text("Couldn't save your profile"),
          action: SnackBarAction(
            label: 'Try again',
            onPressed: () {
              if (mounted) _save();
            },
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? Function(String?) _range(String what, double min, double max) => (s) {
    final v = _parse(s ?? '');
    if (v == null) return 'Enter your $what';
    if (v < min || v > max) return 'Between ${_num(min)} and ${_num(max)}';
    return null;
  };

  @override
  Widget build(BuildContext context) {
    // Reload the fields when the stored profile appears or changes while
    // they aren't being edited: e.g. this form was built (empty) before
    // first-run setup saved a profile, or the profile was saved elsewhere.
    // Without this the form would keep stale defaults, and saving it would
    // overwrite the real profile with them.
    ref.listen<AsyncValue<Profile?>>(profileProvider, (_, next) {
      final p = next.value;
      if (p == null || _editing || _saving) return;
      if (_loaded && p.updatedAt == _loadedUpdatedAt) return;
      setState(() {
        _loaded = false;
        _birthError = null;
        _load(p);
      });
    });
    final profile = ref.watch(profileProvider);
    if (profile.isLoading && !_loaded) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: LinearProgressIndicator(),
      );
    }
    if (profile.hasError && !_loaded) {
      debugPrint('Loading profile failed: ${profile.error}');
      return ErrorRetry(
        message: "Couldn't load your profile",
        onRetry: () => ref.invalidate(profileProvider),
      );
    }
    _load(profile.value);
    final locked = widget.lockable && profile.value != null && !_editing;

    ref.watch(weighInsProvider); // read by _save for the snackbar text
    final now = ref.read(clockProvider)();
    final trendKg = ref.watch(weightTrendProvider).value?.lastOrNull?.trendKg;
    final goalKg = _parse(_goal.text);
    final atGoal =
        trendKg != null &&
        goalKg != null &&
        (_goalDirection == GoalDirection.lose
            ? trendKg <= goalKg
            : trendKg >= goalKg);
    final theme = Theme.of(context);

    // Faster loss is only capped once there's a weight, height and birth
    // date to estimate body composition from; until then the full range
    // stays open (matches how the engine falls back when data is missing).
    final heightVal = _parse(_height.text);
    double? rateMax;
    if (trendKg != null &&
        heightVal != null &&
        heightVal > 0 &&
        _birthDate != null) {
      final age = ageOn(_birthDate!, now);
      final bmi = trendKg / math.pow(heightVal / 100, 2);
      final bodyFat = deurenbergBodyFatPercent(
        bmi: bmi,
        ageYears: age,
        sex: _sex,
      ).clamp(5.0, 50.0);
      rateMax = _goalDirection == GoalDirection.lose
          ? maxWeeklyRatePct(bmi: bmi, bodyFatPercent: bodyFat)
          : maxWeeklyGainRatePct(bodyFatPercent: bodyFat);
    }
    final effectiveRateMax = rateMax ?? 1.0;
    // Shown (and used by the engine) capped, but the stored choice isn't
    // changed unless the user moves the slider: silently lowering it would
    // look like a rate change to the engine and restart the diet phase.
    final shownRatePct = math.min(_ratePct, effectiveRateMax);
    final rateOverCap = _ratePct > effectiveRateMax;
    final rateKg = trendKg == null ? null : trendKg * shownRatePct / 100;

    return Form(
      key: _formKey,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (locked)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Locked to prevent accidental changes',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            SegmentedButton<Sex>(
              segments: const [
                ButtonSegment(value: Sex.male, label: Text('Male')),
                ButtonSegment(value: Sex.female, label: Text('Female')),
              ],
              selected: {_sex},
              onSelectionChanged: locked
                  ? null
                  : (s) => setState(() => _sex = s.first),
            ),
            ListTile(
              key: const Key('birthDate'),
              contentPadding: EdgeInsets.zero,
              enabled: !locked,
              title: const Text('Birth date'),
              subtitle: Text(
                _birthError ??
                    (_birthDate == null
                        ? 'Tap to type it'
                        : '${DateFormat.yMMMd('en_US').format(_birthDate!)}'
                              ' · ${ageOn(_birthDate!, now)} years old'),
                style: _birthError == null
                    ? null
                    : TextStyle(color: theme.colorScheme.error),
              ),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: locked ? null : _pickBirthDate,
            ),
            TextFormField(
              key: const Key('heightCm'),
              controller: _height,
              enabled: !locked,
              decoration: const InputDecoration(
                labelText: 'Height',
                suffixText: 'cm',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.next,
              validator: _range('height', 100, 250),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ActivityLevel>(
              key: const Key('activityLevel'),
              initialValue: _activity,
              isExpanded: true,
              itemHeight: null,
              decoration: const InputDecoration(labelText: 'Activity level'),
              selectedItemBuilder: (_) => [
                for (final a in ActivityLevel.values)
                  Text(_activityText[a]!.$1),
              ],
              items: [
                for (final a in ActivityLevel.values)
                  DropdownMenuItem(
                    value: a,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_activityText[a]!.$1),
                          Text(
                            _activityText[a]!.$2,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
              onChanged: locked
                  ? null
                  : (a) => setState(() => _activity = a ?? _activity),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _activityText[_activity]!.$2,
                style: theme.textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 12),
            if (ref.watch(featureEnabledProvider(AppFeature.gainGoals))) ...[
              SegmentedButton<GoalDirection>(
                key: const Key('goalDirection'),
                segments: const [
                  ButtonSegment(
                    value: GoalDirection.lose,
                    label: Text('Lose weight'),
                  ),
                  ButtonSegment(
                    value: GoalDirection.gain,
                    label: Text('Gain weight'),
                  ),
                ],
                selected: {_goalDirection},
                onSelectionChanged: locked
                    ? null
                    : (s) => setState(() => _goalDirection = s.first),
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              key: const Key('goalWeightKg'),
              controller: _goal,
              enabled: !locked,
              decoration: const InputDecoration(
                labelText: 'Goal weight',
                suffixText: 'kg',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: widget.extra.isEmpty
                  ? TextInputAction.done
                  : TextInputAction.next,
              onChanged: (_) => setState(() {}),
              validator: _range('goal weight', 30, 300),
            ),
            const SizedBox(height: 16),
            Text(
              atGoal
                  ? "You're at your goal, targets will hold your weight"
                  : '${_goalDirection == GoalDirection.lose ? 'Weekly loss rate' : 'Weekly gain rate'}: '
                        '${shownRatePct.toStringAsFixed(2)} % per '
                        'week${rateKg == null ? '' : ' (≈ ${rateKg.toStringAsFixed(2)} kg/week)'}',
              key: const Key('rateText'),
            ),
            Slider(
              key: const Key('weeklyRate'),
              value: shownRatePct,
              min: 0.25,
              max: effectiveRateMax,
              divisions: ((effectiveRateMax - 0.25) / 0.05).round(),
              label: '${shownRatePct.toStringAsFixed(2)} %',
              onChanged: locked ? null : (v) => setState(() => _ratePct = v),
            ),
            if (rateMax != null && rateMax < 1.0)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _goalDirection == GoalDirection.lose
                      ? '${rateOverCap ? 'Your chosen ${_ratePct.toStringAsFixed(2)} % is capped' : 'Capped'}'
                            ' at ${rateMax.toStringAsFixed(2)} % for now, based '
                            'on your current weight and height — faster loss costs '
                            'more muscle the leaner you are.'
                      : '${rateOverCap ? 'Your chosen ${_ratePct.toStringAsFixed(2)} % is capped' : 'Capped'}'
                            ' at ${rateMax.toStringAsFixed(2)} % for now, based on your '
                            'current body composition — a slower gain limits how much '
                            'is fat versus muscle.',
                  key: const Key('rateCapNote'),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            if (shownRatePct > 0.75)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'At this rate, more protein (2.0–2.2 g/kg) helps hold on '
                  'to muscle.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            Text('Protein: ${_proteinPerKg.toStringAsFixed(1)} g per kg'),
            Slider(
              key: const Key('proteinPerKg'),
              value: _proteinPerKg,
              min: 1.6,
              max: 2.2,
              divisions: 6,
              label: '${_proteinPerKg.toStringAsFixed(1)} g/kg',
              onChanged: locked
                  ? null
                  : (v) => setState(() => _proteinPerKg = v),
            ),
            DropdownButtonFormField<int>(
              key: const Key('checkInWeekday'),
              initialValue: _weekday,
              decoration: const InputDecoration(labelText: 'Check-in day'),
              items: [
                for (var d = 1; d <= 7; d++)
                  DropdownMenuItem(value: d, child: Text(_weekdays[d - 1])),
              ],
              onChanged: locked
                  ? null
                  : (d) => setState(() => _weekday = d ?? _weekday),
            ),
            ...widget.extra,
            const SizedBox(height: 16),
            if (locked)
              OutlinedButton.icon(
                key: const Key('editProfile'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _startEditing,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit'),
              )
            else if (widget.lockable && _hasExistingProfile)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('cancelEditProfile'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: _saving ? null : _cancelEditing,
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: const Key('saveProfile'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: _saving ? null : _save,
                      child: Text(widget.saveLabel),
                    ),
                  ),
                ],
              )
            else
              FilledButton(
                key: const Key('saveProfile'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _saving ? null : _save,
                child: Text(widget.saveLabel),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Exports all tables as JSON via the share sheet; shows a snackbar if the
/// export fails.
class ExportDataTile extends ConsumerStatefulWidget {
  const ExportDataTile({super.key});

  @override
  ConsumerState<ExportDataTile> createState() => _ExportDataTileState();
}

class _ExportDataTileState extends ConsumerState<ExportDataTile> {
  bool _busy = false;

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      await shareExport(ref.read(databaseProvider), ref.read(clockProvider)());
    } catch (e, s) {
      debugPrint('Export failed: $e\n$s');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Couldn't export your data"),
            action: SnackBarAction(
              label: 'Try again',
              onPressed: () {
                if (mounted) _export();
              },
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListTile(
    leading: const Icon(Icons.ios_share),
    title: const Text('Export data'),
    subtitle: const Text('Save a backup of all your data'),
    trailing: _busy
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : null,
    onTap: _busy ? null : _export,
  );
}

/// Restores a backup made with [ExportDataTile], replacing all data.
class ImportDataTile extends ConsumerStatefulWidget {
  const ImportDataTile({super.key});

  @override
  ConsumerState<ImportDataTile> createState() => _ImportDataTileState();
}

class _ImportDataTileState extends ConsumerState<ImportDataTile> {
  bool _busy = false;

  Future<void> _import() async {
    setState(() => _busy = true);
    try {
      await runImport(context, ref);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListTile(
    leading: const Icon(Icons.restore),
    title: const Text('Import data'),
    subtitle: const Text('Restore a backup; replaces everything here'),
    trailing: _busy
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : null,
    onTap: _busy ? null : _import,
  );
}
