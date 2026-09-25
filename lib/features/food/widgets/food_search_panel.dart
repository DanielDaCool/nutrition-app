// Online food search (USDA or Open Food Facts), used by the Search tab and
// by "Search online" on the describe screen.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/remote_food.dart';
import '../food_providers.dart';

/// Which remote database the Search tab queries.
enum SearchSource { off, usda }

/// Remote search (USDA or Open Food Facts). Results survive tab switches.
class FoodSearchPanel extends ConsumerStatefulWidget {
  const FoodSearchPanel({super.key, required this.onPick, this.initialQuery});

  final Future<void> Function(RemoteFood) onPick;

  /// Prefilled query, searched right away (the user asked for it by tapping
  /// "Search online").
  final String? initialQuery;

  @override
  ConsumerState<FoodSearchPanel> createState() => _FoodSearchPanelState();
}

class _FoodSearchPanelState extends ConsumerState<FoodSearchPanel>
    with AutomaticKeepAliveClientMixin {
  late final _query = TextEditingController(text: widget.initialQuery);
  SearchSource _source = SearchSource.usda;
  AsyncValue<List<RemoteFood>>? _results;

  /// Incremented per search so a slow, older response can't overwrite a
  /// newer one.
  int _requestId = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if ((widget.initialQuery ?? '').trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _search();
      });
    }
  }

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
