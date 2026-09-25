// OWNER: engine agent (A). Contract stub: keep the class name and constructor.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../data/db/database.dart';
import '../../domain/models.dart';
import '../activity/widgets/health_connect_tile.dart';
import '../targets/checkin_screen.dart';
import '../targets/engine/explain.dart';
import '../targets/targets_providers.dart';
import '../weight/weight_providers.dart';
import 'data_export.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: const [
          CurrentTargetsCard(),
          CheckInTile(),
          Divider(),
          _SectionHeader('Profile'),
          ProfileForm(),
          Divider(),
          HealthConnectSettingsTile(),
          ExportDataTile(),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
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
          error: (e, _) => Text('Could not load targets: $e'),
          data: (t) {
            if (t == null) {
              return const Text(
                'No targets yet. Save your profile below and log a weigh-in '
                'to get your daily targets.',
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

class CheckInTile extends ConsumerWidget {
  const CheckInTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = ref.watch(checkInDueProvider).value ?? false;
    return ListTile(
      leading: Icon(due ? Icons.notification_important : Icons.event_repeat),
      title: const Text('Weekly check-in'),
      subtitle: Text(
        due
            ? 'A new recommendation is waiting'
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

/// Profile & goal settings, saved to the single Profiles row (id = 1).
class ProfileForm extends ConsumerStatefulWidget {
  const ProfileForm({super.key});

  @override
  ConsumerState<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<ProfileForm> {
  final _formKey = GlobalKey<FormState>();
  final _height = TextEditingController();
  final _goal = TextEditingController();
  Sex _sex = Sex.male;
  DateTime? _birthDate;
  ActivityLevel _activity = ActivityLevel.light;
  double _ratePct = 0.5;
  double _proteinPerKg = 2.0;
  int _weekday = DateTime.sunday;
  bool _loaded = false;
  bool _saving = false;
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
    _sex = Sex.values[p.sex];
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
      helpText: 'Birth date',
    );
    if (picked != null) {
      setState(() {
        _birthDate = picked;
        _birthError = null;
      });
    }
  }

  Future<void> _save() async {
    final formOk = _formKey.currentState!.validate();
    if (_birthDate == null) {
      setState(() => _birthError = 'Pick your birth date');
    }
    if (!formOk || _birthDate == null) return;
    setState(() => _saving = true);
    try {
      await ref
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
          );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Profile saved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
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
    final profile = ref.watch(profileProvider);
    if (profile.isLoading && !_loaded) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: LinearProgressIndicator(),
      );
    }
    if (profile.hasError && !_loaded) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Could not load profile: ${profile.error}'),
      );
    }
    _load(profile.value);

    final trendKg = ref.watch(weightTrendProvider).value?.lastOrNull?.trendKg;
    final rateKg = trendKg == null ? null : trendKg * _ratePct / 100;
    final theme = Theme.of(context);

    return Form(
      key: _formKey,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            SegmentedButton<Sex>(
              segments: const [
                ButtonSegment(value: Sex.male, label: Text('Male')),
                ButtonSegment(value: Sex.female, label: Text('Female')),
              ],
              selected: {_sex},
              onSelectionChanged: (s) => setState(() => _sex = s.first),
            ),
            ListTile(
              key: const Key('birthDate'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Birth date'),
              subtitle: Text(
                _birthError ??
                    (_birthDate == null
                        ? 'Not set'
                        : DateFormat.yMMMd('en_US').format(_birthDate!)),
                style: _birthError == null
                    ? null
                    : TextStyle(color: theme.colorScheme.error),
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickBirthDate,
            ),
            TextFormField(
              key: const Key('heightCm'),
              controller: _height,
              decoration: const InputDecoration(
                labelText: 'Height',
                suffixText: 'cm',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
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
              onChanged: (a) => setState(() => _activity = a ?? _activity),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _activityText[_activity]!.$2,
                style: theme.textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('goalWeightKg'),
              controller: _goal,
              decoration: const InputDecoration(
                labelText: 'Goal weight',
                suffixText: 'kg',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: _range('goal weight', 30, 300),
            ),
            const SizedBox(height: 16),
            Text(
              'Weekly loss rate: ${_ratePct.toStringAsFixed(2)} % per week'
              '${rateKg == null ? '' : ' (≈ ${rateKg.toStringAsFixed(2)} kg/week)'}',
            ),
            Slider(
              key: const Key('weeklyRate'),
              value: _ratePct,
              min: 0.25,
              max: 1.0,
              divisions: 15,
              label: '${_ratePct.toStringAsFixed(2)} %',
              onChanged: (v) => setState(() => _ratePct = v),
            ),
            Text('Protein: ${_proteinPerKg.toStringAsFixed(1)} g per kg'),
            Slider(
              key: const Key('proteinPerKg'),
              value: _proteinPerKg,
              min: 1.6,
              max: 2.2,
              divisions: 6,
              label: '${_proteinPerKg.toStringAsFixed(1)} g/kg',
              onChanged: (v) => setState(() => _proteinPerKg = v),
            ),
            DropdownButtonFormField<int>(
              key: const Key('checkInWeekday'),
              initialValue: _weekday,
              decoration: const InputDecoration(labelText: 'Check-in day'),
              items: [
                for (var d = 1; d <= 7; d++)
                  DropdownMenuItem(value: d, child: Text(_weekdays[d - 1])),
              ],
              onChanged: (d) => setState(() => _weekday = d ?? _weekday),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('saveProfile'),
              onPressed: _saving ? null : _save,
              child: const Text('Save profile'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListTile(
    leading: const Icon(Icons.ios_share),
    title: const Text('Export data'),
    subtitle: const Text('All your data as a JSON file'),
    trailing: _busy
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : null,
    onTap: _busy ? null : _export,
  );
}
