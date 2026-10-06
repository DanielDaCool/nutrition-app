// OWNER: engine agent (A).
// First-run "Get started" flow: profile, first weigh-in and Health Connect on
// one screen, opened by the home shell while there is no profile yet.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/app_features.dart';
import '../../core/day_key.dart';
import '../activity/widgets/health_connect_tile.dart';
import '../weight/weight_logic.dart';
import '../weight/weight_providers.dart';
import 'import_flow.dart';
import 'settings_screen.dart';

/// Opens [SetupScreen] as a full-screen page.
Future<void> openSetup(BuildContext context) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => const SetupScreen(),
  ),
);

/// Full-screen first-run setup. "Save and start" stores the profile (through
/// [ProfileForm], so validation is shared) and today's weigh-in (through the
/// weight feature's repository); "Restore from a backup" imports an export
/// instead; "Later" just closes it.
class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final _weightKg = TextEditingController();

  @override
  void dispose() {
    _weightKg.dispose();
    super.dispose();
  }

  bool get _hasWeighIn => ref.read(weighInsProvider).value?.isNotEmpty ?? false;

  String? _validateWeight(String? text) {
    if ((text ?? '').trim().isEmpty) {
      return _hasWeighIn ? null : 'Enter your weight to get your targets';
    }
    return validateWeightKg(text);
  }

  /// Runs after the profile is stored. The weigh-in is saved and its failure
  /// reported on its own: the profile is already saved at this point, so a
  /// weigh-in error must not read as "Couldn't save your profile". On a
  /// weigh-in error the screen stays open so it can be retried.
  Future<void> _afterProfileSaved() async {
    final weightKg = parseWeightKg(_weightKg.text);
    if (weightKg != null) {
      try {
        final today = dayKeyOf(ref.read(clockProvider)());
        await ref.read(weightRepositoryProvider).upsert(today, weightKg);
      } catch (e, s) {
        debugPrint('Saving first weigh-in failed: $e\n$s');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              "Profile saved, but your weight couldn't be saved",
            ),
            action: SnackBarAction(
              label: 'Try again',
              onPressed: () {
                if (mounted) _afterProfileSaved();
              },
            ),
          ),
        );
        return;
      }
    }
    if (!mounted) return;
    final ready = weightKg != null || _hasWeighIn;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ready
              ? "You're all set. Your calorie target is on Today."
              : 'Profile saved. Log your weight on Today to get your '
                    'targets.',
        ),
      ),
    );
    Navigator.of(context).maybePop();
  }

  /// Moving to a new phone: restore the old one's export instead of
  /// starting over. Closes setup once the profile is back.
  Future<void> _restore() async {
    final restored = await runImport(context, ref);
    if (restored && mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    ref.watch(weighInsProvider); // keeps _hasWeighIn current
    return Scaffold(
      appBar: AppBar(
        title: const Text('Get started'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            key: const Key('setupLater'),
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('Later'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Welcome! Fill in a few details to get a daily calorie '
              'target that adapts as you go.',
              style: theme.textTheme.bodyLarge,
            ),
          ),
          ProfileForm(
            saveLabel: 'Save and start',
            onSaved: _afterProfileSaved,
            extra: [
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('setupWeightKg'),
                controller: _weightKg,
                decoration: InputDecoration(
                  labelText: "Today's weight",
                  hintText: 'e.g. 82.4',
                  suffixText: 'kg',
                  helperText: _hasWeighIn
                      ? 'Optional, you already logged a weigh-in'
                      : 'Needed for your first target',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.done,
                validator: _validateWeight,
              ),
              // Health Connect is Android-only.
              if (!ref.watch(isWebProvider)) ...[
                const SizedBox(height: 16),
                Text(
                  'Steps and workouts (optional)',
                  style: theme.textTheme.titleSmall,
                ),
                const HealthConnectSettingsTile(),
              ],
            ],
          ),
          if (ref.watch(featureEnabledProvider(AppFeature.backup)))
            Center(
              child: TextButton.icon(
                key: const Key('setupRestore'),
                onPressed: _restore,
                icon: const Icon(Icons.restore),
                label: const Text('Restore from a backup'),
              ),
            ),
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              style: TextButton.styleFrom(minimumSize: const Size(160, 48)),
              child: const Text("I'll do this later"),
            ),
          ),
        ],
      ),
    );
  }
}
