// Food picker for one meal: tabs for recent, favorite, custom and searched
// foods, plus barcode scan and "new food" actions.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/database.dart';
import '../../../domain/models.dart';
import '../data/barcode_lookup.dart';
import '../data/remote_food.dart';
import '../food_providers.dart';
import '../widgets/food_format.dart';
import 'barcode_scan_screen.dart';
import 'custom_food_screen.dart';
import 'portion_screen.dart';

/// Pick a food for one meal: Recent, Favorites, My foods, Search, or scan.
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
    final food = await ref.read(foodRepositoryProvider).upsertRemote(remote);
    if (mounted) await _openPortion(food);
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
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    switch (result) {
      case BarcodeFound(:final food):
        await _openPortion(food);
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
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Add to ${mealLabel(widget.meal)}'),
          actions: [
            IconButton(
              key: const Key('scan-button'),
              tooltip: 'Scan barcode',
              icon: const Icon(Icons.qr_code_scanner),
              onPressed: _busy ? null : _scan,
            ),
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
            Expanded(
              child: TabBarView(
                children: [
                  _FoodList(
                    provider: recentFoodsProvider,
                    empty: 'Foods you log will show up here.',
                    onTap: _openPortion,
                  ),
                  _FoodList(
                    provider: favoriteFoodsProvider,
                    empty: 'Tap the star on a food to keep it here.',
                    onTap: _openPortion,
                  ),
                  _FoodList(
                    provider: customFoodsProvider,
                    empty:
                        'Foods you create, e.g. from a label, show up '
                        'here. Tap + to add one.',
                    onTap: _openPortion,
                    onEdit: _editFood,
                  ),
                  _SearchTab(onPick: _pickRemote),
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
/// button instead of the favorite star.
class _FoodList extends ConsumerWidget {
  const _FoodList({
    required this.provider,
    required this.empty,
    required this.onTap,
    this.onEdit,
  });

  final StreamProvider<List<Food>> provider;
  final String empty;
  final void Function(Food) onTap;
  final void Function(Food)? onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(provider)) {
      AsyncData(:final value) when value.isEmpty => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(empty, textAlign: TextAlign.center),
        ),
      ),
      AsyncData(:final value) => ListView.builder(
        itemCount: value.length,
        itemBuilder: (context, i) {
          final f = value[i];
          return ListTile(
            title: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              foodSubtitle(f),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: onEdit == null
                ? (f.isFavorite ? const Icon(Icons.star, size: 18) : null)
                : IconButton(
                    tooltip: 'Edit',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => onEdit!(f),
                  ),
            onTap: () => onTap(f),
          );
        },
      ),
      AsyncError(:final error) => Center(child: Text('Error: $error')),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

/// Which remote database the Search tab queries.
enum SearchSource { off, usda }

/// Remote search (USDA or Open Food Facts). Results survive tab switches.
class _SearchTab extends ConsumerStatefulWidget {
  const _SearchTab({required this.onPick});

  final Future<void> Function(RemoteFood) onPick;

  @override
  ConsumerState<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends ConsumerState<_SearchTab>
    with AutomaticKeepAliveClientMixin {
  final _query = TextEditingController();
  SearchSource _source = SearchSource.usda;
  AsyncValue<List<RemoteFood>>? _results;

  /// Incremented per search so a slow, older response can't overwrite a
  /// newer one.
  int _requestId = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  /// Runs only when the user submits (API rate limits).
  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    final id = ++_requestId;
    setState(() => _results = const AsyncLoading());
    final result = await AsyncValue.guard(
      () => switch (_source) {
        SearchSource.off => ref.read(offClientProvider).search(q),
        SearchSource.usda => ref.read(usdaClientProvider).search(q),
      },
    );
    if (mounted && id == _requestId) setState(() => _results = result);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SegmentedButton<SearchSource>(
            segments: const [
              ButtonSegment(
                value: SearchSource.usda,
                label: Text('USDA (generic)'),
              ),
              ButtonSegment(
                value: SearchSource.off,
                label: Text('Open Food Facts'),
              ),
            ],
            selected: {_source},
            onSelectionChanged: (s) => setState(() {
              _source = s.first;
              _results = null;
            }),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            key: const Key('search-field'),
            controller: _query,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: _source == SearchSource.usda
                  ? 'e.g. chicken breast, rice, egg'
                  : 'Product or brand',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                key: const Key('search-button'),
                tooltip: 'Search',
                icon: const Icon(Icons.search),
                onPressed: _search,
              ),
            ),
            onSubmitted: (_) => _search(),
          ),
        ),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _body() {
    final r = _results;
    if (r == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Type a food and press Search.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return switch (r) {
      AsyncData(:final value) when value.isEmpty => const Center(
        child: Text('No results.'),
      ),
      AsyncData(:final value) => ListView.builder(
        itemCount: value.length,
        itemBuilder: (context, i) {
          final f = value[i];
          final kcal = f.kcalPer100g;
          return ListTile(
            title: Text(f.name, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              [
                if (f.brand != null) f.brand!,
                kcal == null
                    ? 'No nutrition data (enter from label)'
                    : '${kcal.round()} kcal/100 g',
              ].join(' · '),
            ),
            onTap: () => widget.onPick(f),
          );
        },
      ),
      AsyncError(:final error) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            error is FoodApiException ? error.message : 'Search failed.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}
