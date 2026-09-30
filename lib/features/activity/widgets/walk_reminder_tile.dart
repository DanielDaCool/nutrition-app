// OWNER: Health Connect agent (C).
// Settings row: on/off toggle, reminder time and step threshold for the
// daily walk reminder.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../walk_reminder_providers.dart';

/// Settings row for the daily walk reminder.
class WalkReminderSettingsTile extends ConsumerStatefulWidget {
  const WalkReminderSettingsTile({super.key});

  @override
  ConsumerState<WalkReminderSettingsTile> createState() =>
      _WalkReminderSettingsTileState();
}

class _WalkReminderSettingsTileState
    extends ConsumerState<WalkReminderSettingsTile> {
  /// The threshold while the slider is being dragged, shown in place of the
  /// saved value so the UI tracks the finger; only saved once, on release
  /// (see [_onThresholdChangeEnd]). Null when not dragging.
  int? _draftThreshold;

  void _onThresholdChanged(int value) =>
      setState(() => _draftThreshold = value);

  Future<void> _onThresholdChangeEnd(
    WalkReminderSettings settings,
    double value,
  ) async {
    final controller = ref.read(walkReminderSettingsProvider.notifier);
    setState(() => _draftThreshold = null);
    await controller.save(settings.copyWith(stepThreshold: value.round()));
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(walkReminderSettingsProvider);
    final controller = ref.read(walkReminderSettingsProvider.notifier);

    return settingsAsync.when(
      loading: () => const ListTile(
        leading: Icon(Icons.directions_walk),
        title: Text('Walk reminder'),
        trailing: SizedBox.square(
          dimension: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (e, _) {
        debugPrint('Loading walk reminder settings failed: $e');
        return const ListTile(
          leading: Icon(Icons.directions_walk),
          title: Text('Walk reminder'),
          subtitle: Text("Couldn't load"),
        );
      },
      data: (settings) {
        final shownThreshold = _draftThreshold ?? settings.stepThreshold;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              key: const Key('walkReminderSwitch'),
              secondary: const Icon(Icons.directions_walk),
              title: const Text('Walk reminder'),
              subtitle: Text(
                settings.enabled
                    ? 'Nudges you at ${_time(settings)} if you\'re under '
                          '${settings.stepThreshold} steps'
                    : 'Off',
              ),
              value: settings.enabled,
              onChanged: (v) => controller.save(settings.copyWith(enabled: v)),
            ),
            if (settings.enabled) ...[
              ListTile(
                key: const Key('walkReminderTime'),
                contentPadding: const EdgeInsets.only(left: 16, right: 16),
                title: const Text('Remind me at'),
                trailing: Text(_time(settings)),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(
                      hour: settings.hour,
                      minute: settings.minute,
                    ),
                  );
                  if (picked != null) {
                    await controller.save(
                      settings.copyWith(
                        hour: picked.hour,
                        minute: picked.minute,
                      ),
                    );
                  }
                },
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('If under $shownThreshold steps'),
                    Slider(
                      key: const Key('walkReminderThreshold'),
                      value: shownThreshold.toDouble(),
                      min: 1000,
                      max: 15000,
                      divisions: 28,
                      label: '$shownThreshold',
                      onChanged: (v) => _onThresholdChanged(v.round()),
                      onChangeEnd: (v) => _onThresholdChangeEnd(settings, v),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  static String _time(WalkReminderSettings s) {
    final h = s.hour.toString().padLeft(2, '0');
    final m = s.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
