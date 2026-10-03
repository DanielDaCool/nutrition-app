// Food picker for one meal: "Describe what you ate", tabs for recent,
// favorite, custom and searched foods, plus barcode scan and "new food".

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/app_features.dart';
import '../../../core/day_key.dart';
import '../../../data/db/database.dart';
import '../../../domain/models.dart';
import '../../settings/feature_flags.dart';
import '../data/barcode_lookup.dart';
import '../data/food_repository.dart';
import '../data/remote_food.dart';
import '../describe/builtin_foods.dart';
import '../describe/food_matcher.dart';
import '../food_providers.dart';
import '../nutrition_math.dart';
import '../widgets/error_retry.dart';
import '../widgets/food_format.dart';
import '../widgets/food_search_panel.dart';
import '../widgets/undo_snack.dart';
import 'barcode_scan_screen.dart';
import 'custom_food_screen.dart';
import 'describe_food_screen.dart';
import 'portion_screen.dart';

/// Pick a food for one meal: describe it in words, Recent, Favorites, My
/// foods, Search, or scan.
class AddFoodScreen extends ConsumerStatefulWidget {
  const AddFoodScreen({super.key, required this.dayKey, required this.meal});

  final String dayKey;
  final Meal meal;

  @override
  ConsumerState<AddFoodScreen> createState() => _AddFoodScreenState();
}

class _AddFoodScreenState extends ConsumerState<AddFoodScreen> {
  bool _busy = false;

  /// Opens the portion screen; closes this screen once the food is logged.
  Future<void> _openPortion(Food food) async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            PortionScreen(food: food, dayKey: widget.dayKey, meal: widget.meal),
      ),
    );
    if (added == true && mounted) Navigator.of(context).pop();
  }

  /// Opens "Describe what you ate" for the same day and meal; closes this
  /// screen once it added something.
  Future<void> _describe() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            DescribeFoodScreen(dayKey: widget.dayKey, meal: widget.meal),
      ),
    );
    if (added == true && mounted) Navigator.of(context).pop();
  }

  /// Opens the custom food form (prefilled from [barcode]/[draft]) and, once
  /// saved, goes on to the portion screen.
  Future<void> _createFood({String? barcode, RemoteFood? draft}) async {
    final food = await Navigator.of(context).push<Food>(
      MaterialPageRoute(
        builder: (_) => CustomFoodScreen(barcode: barcode, draft: draft),
      ),
    );
    if (food != null && mounted) await _openPortion(food);
  }

  Future<void> _editFood(Food food) => Navigator.of(context).push<Food>(
    MaterialPageRoute(builder: (_) => CustomFoodScreen(existing: food)),
  );

  /// Saves a search result locally and opens the portion screen. Results
  /// without energy go to the custom food form instead.
  Future<void> _pickRemote(RemoteFood remote) async {
    if (!remote.isComplete) {
      await _createFood(draft: remote);
      return;
    }
    final Food food;
    try {
      food = await ref.read(foodRepositoryProvider).upsertRemote(remote);
    } catch (e, st) {
      _showError('Could not save it.', e, st);
      return;
    }
    if (mounted) await _openPortion(food);
  }

  /// Opens the portion screen for a saved or built-in food from the Search
  /// tab. A built-in food is saved first.
  Future<void> _pickLocal(FoodCandidate c) async {
    final repo = ref.read(foodRepositoryProvider);
    final Food food;
    try {
      final id = c.foodId;
      final builtin = c.builtinKey == null ? null : builtinByKey(c.builtinKey!);
      if (id != null) {
        food = await repo.foodById(id);
      } else if (builtin != null) {
        food = await repo.saveBuiltin(builtin);
      } else {
        throw StateError('Food ${c.key} is neither saved nor built in');
      }
    } catch (e, st) {
      _showError('Could not open that food.', e, st);
      return;
    }
    if (mounted) await _openPortion(food);
  }

  /// Logs [grams] of [food] right away (the amount from last time) and
  /// confirms with Undo. Stays open to add more.
  Future<void> _quickAdd(Food food, double grams) async {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(foodRepositoryProvider);
    try {
      final id = await repo.logFood(
        dayKey: widget.dayKey,
        meal: widget.meal,
        foodId: food.id,
        grams: grams,
      );
      showAddedSnack(
        messenger,
        repo,
        addedMessage(
          food.name,
          grams,
          macrosForGrams(per100gOf(food), grams).kcal,
          widget.meal,
        ),
        [id],
      );
    } catch (e, st) {
      _showError('Could not add it.', e, st);
    }
  }

  void _showError(String what, Object error, StackTrace st) {
    final message = friendlyError(error, st);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$what $message')));
  }

  Future<void> _scan() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScanScreen()),
    );
    if (code == null || !mounted) return;
    await lookupBarcode(code);
  }

  /// Local foods, then Open Food Facts, then "Add from label".
  Future<void> lookupBarcode(String code) async {
    setState(() => _busy = true);
    final BarcodeResult result;
    try {
      result = await ref.read(barcodeLookupProvider).lookup(code);
    } catch (e, st) {
      _showError('Could not look up that barcode.', e, st);
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    switch (result) {
      case BarcodeFound(:final food):
        await _openPortion(food);
      case BarcodeFailed(:final message, :final canRetry):
        // No answer (offline, rate-limited) or not a product code: offering
        // "Add from label" here would make a food that shadows the real
        // product later, so offer to try again or scan again instead.
        final again = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              canRetry ? 'Could not look it up' : 'Not a product barcode',
            ),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const Key('barcode-again'),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(canRetry ? 'Try again' : 'Scan again'),
              ),
            ],
          ),
        );
        if (again == true && mounted) {
          if (canRetry) {
            await lookupBarcode(code);
          } else {
            await _scan();
          }
        }
      case BarcodeNeedsLabel(:final message, :final draft):
        final add = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Not found'),
            content: Text(
              '$message\n\nAdd it from the nutrition label? '
              'It will be saved for next time.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Add from label'),
              ),
            ],
          ),
        );
        if (add == true && mounted) {
          await _createFood(barcode: result.barcode, draft: draft);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Scanning can be switched off in Settings → Feature hub.
    final scanEnabled = ref.watch(
      featureEnabledProvider(AppFeature.barcodeScan),
    );
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            withDay(
              'Add to ${mealLabel(widget.meal)}',
              widget.dayKey,
              dayKeyOf(ref.read(clockProvider)()),
            ),
          ),
          actions: [
            IconButton(
              key: const Key('new-food-button'),
              tooltip: 'New food',
              icon: const Icon(Icons.add),
              onPressed: _busy ? null : () => _createFood(),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Recent'),
              Tab(text: 'Favorites'),
              Tab(text: 'My foods'),
              Tab(text: 'Search'),
            ],
          ),
        ),
        body: Column(
          children: [
            if (_busy) const LinearProgressIndicator(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              // The two main ways to add: type it out or scan it. Without
              // scanning, "Type it" takes the full width.
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      key: const Key('describe-button'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      onPressed: _busy ? null : _describe,
                      icon: const Icon(Icons.edit_note),
                      label: const Text('Type it'),
                    ),
                  ),
                  if (scanEnabled) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        key: const Key('scan-button'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                        onPressed: _busy ? null : _scan,
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Scan'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _FoodList(
                    provider: recentFoodsProvider,
                    empty: 'Foods you log will show up here.',
                    emptyAction: ('Type what you ate', _describe),
                    onTap: _openPortion,
                    onQuickAdd: _quickAdd,
                  ),
                  _FoodList(
                    provider: favoriteFoodsProvider,
                    empty:
                        'Tap the star on a food to keep it here for '
                        'quick adding.',
                    onTap: _openPortion,
                    onQuickAdd: _quickAdd,
                  ),
                  _FoodList(
                    provider: customFoodsProvider,
                    empty: 'Foods you create, e.g. from a label, show up here.',
                    emptyAction: ('New food', () => _createFood()),
                    onTap: _openPortion,
                    onEdit: _editFood,
                  ),
                  FoodSearchPanel(onPick: _pickRemote, onPickLocal: _pickLocal),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A list of local foods from [provider]. With [onEdit], rows show an edit
/// button; with [onQuickAdd], foods logged before show their last amount and
/// a button that logs it again at once.
class _FoodList extends ConsumerWidget {
  const _FoodList({
    required this.provider,
    required this.empty,
    this.emptyAction,
    required this.onTap,
    this.onEdit,
    this.onQuickAdd,
  });

  final StreamProvider<List<Food>> provider;
  final String empty;

  /// Button shown under [empty] that fixes the empty state.
  final (String, VoidCallback)? emptyAction;
  final void Function(Food) onTap;
  final void Function(Food)? onEdit;
  final void Function(Food, double grams)? onQuickAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final lastGrams = onQuickAdd == null
        ? const <int, double>{}
        : ref.watch(lastGramsByFoodProvider).value ?? const <int, double>{};
    return switch (ref.watch(provider)) {
      AsyncData(:final value) when value.isEmpty => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(empty, textAlign: TextAlign.center),
              if (emptyAction case (final label, final onPressed)) ...[
                const SizedBox(height: 16),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                  onPressed: onPressed,
                  child: Text(label),
                ),
              ],
            ],
          ),
        ),
      ),
      AsyncData(:final value) => ListView.builder(
        itemCount: value.length,
        itemBuilder: (context, i) {
          final f = value[i];
          final last = lastGrams[f.id];
          return ListTile(
            minTileHeight: 56,
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    f.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (f.isFavorite && onEdit == null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(Icons.star, size: 16, color: scheme.primary),
                  ),
              ],
            ),
            subtitle: Text(
              last == null ? foodSubtitle(f) : lastTimeLine(f, last),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: onEdit != null
                ? IconButton(
                    tooltip: 'Edit',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => onEdit!(f),
                  )
                : last == null
                ? null
                : IconButton(
                    key: Key('quick-add-${f.id}'),
                    tooltip: 'Add ${fmtNum(last)} g',
                    icon: Icon(Icons.add_circle, color: scheme.primary),
                    onPressed: () => onQuickAdd!(f, last),
                  ),
            onTap: () => onTap(f),
          );
        },
      ),
      AsyncError(:final error, :final stackTrace) => ErrorRetry(
        error: error,
        stackTrace: stackTrace,
        message: 'Could not load your foods.',
        onRetry: () => ref.invalidate(provider),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}
