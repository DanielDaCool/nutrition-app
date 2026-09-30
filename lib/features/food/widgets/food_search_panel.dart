// Food search: the Search tab (saved and common foods as you type, online
// on demand) and "Search online" on the describe screen (online only).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/remote_food.dart';
import '../describe/food_matcher.dart';
import '../food_providers.dart';
import 'error_retry.dart';

/// Which remote database the Search tab queries.
enum SearchSource { off, usda }

/// Food search. With [onPickLocal], saved and built-in foods are listed as
/// you type under "Your foods" and online search (USDA or Open Food Facts)
/// runs from a button; without it, only online search. Results survive tab
/// switches.
class FoodSearchPanel extends ConsumerStatefulWidget {
  const FoodSearchPanel({
    super.key,
    required this.onPick,
    this.onPickLocal,
    this.initialQuery,
  });

  /// An online result was picked.
  final Future<void> Function(RemoteFood) onPick;

  /// A saved or built-in food was picked (enables local search).
  final Future<void> Function(FoodCandidate)? onPickLocal;

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
  ///
  /// USDA covers only generic foods and OFF only branded ones (see
  /// [UsdaClient]), so a real product like "Nutella" gets no results from
  /// whichever source the picker happens to be on. When the selected source
  /// comes back empty, try the other one before giving up, and flip the
  /// picker to match so it's clear where the results came from.
  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    final id = ++_requestId;
    setState(() => _results = const AsyncLoading());
    var source = _source;
    var result = await AsyncValue.guard(() => _searchWith(source, q));
    if (mounted && id == _requestId) {
      if (result case AsyncData(:final value) when value.isEmpty) {
        source = _otherSource(source);
        result = await AsyncValue.guard(() => _searchWith(source, q));
      }
      if (mounted && id == _requestId) {
        setState(() {
          _results = result;
          if (result is AsyncData<List<RemoteFood>> && result.value.isNotEmpty) {
            _source = source;
          }
        });
      }
    }
  }

  Future<List<RemoteFood>> _searchWith(SearchSource source, String q) =>
      switch (source) {
        SearchSource.off => ref.read(offClientProvider).search(q),
        SearchSource.usda => ref.read(usdaClientProvider).search(q),
      };

  SearchSource _otherSource(SearchSource source) =>
      source == SearchSource.usda ? SearchSource.off : SearchSource.usda;

  bool get _local => widget.onPickLocal != null;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final q = _query.text.trim();
    return Column(
      children: [
        if (!_local)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _sourcePicker(),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            key: const Key('search-field'),
            controller: _query,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: _local
                  ? 'e.g. banana, cottage cheese, rice'
                  : _source == SearchSource.usda
                  ? 'e.g. chicken breast, rice, egg'
                  : 'Product or brand',
              prefixIcon: _local ? const Icon(Icons.search) : null,
              border: const OutlineInputBorder(),
              suffixIcon: _local
                  ? (q.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear',
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() {
                              _query.clear();
                              _results = null;
                            }),
                          ))
                  : IconButton(
                      key: const Key('search-button'),
                      tooltip: 'Search',
                      icon: const Icon(Icons.search),
                      onPressed: _search,
                    ),
            ),
            // Typing only filters local foods; online search needs a tap
            // (API rate limits).
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _search(),
          ),
        ),
        Expanded(child: _local ? _localBody(q) : _remoteOnlyBody()),
      ],
    );
  }

  Widget _sourcePicker() => SegmentedButton<SearchSource>(
    segments: const [
      ButtonSegment(value: SearchSource.usda, label: Text('USDA (generic)')),
      ButtonSegment(value: SearchSource.off, label: Text('Open Food Facts')),
    ],
    selected: {_source},
    onSelectionChanged: (s) => setState(() {
      _source = s.first;
      _results = null;
    }),
  );

  /// Search tab: saved and common foods as you type, then online on demand.
  Widget _localBody(String q) {
    final theme = Theme.of(context);
    if (q.isEmpty && _results == null) {
      return const _Hint(
        'Type a food to find it in your foods and common foods. '
        'Not there? Search online.',
      );
    }
    final engine = ref.watch(describeEngineProvider);
    final matches = q.isEmpty
        ? const <FoodMatch>[]
        : engine.value?.search(q, limit: 10) ?? const <FoodMatch>[];
    final label = theme.textTheme.titleSmall?.copyWith(
      color: theme.colorScheme.primary,
    );
    return ListView(
      children: [
        if (q.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text('Your foods', style: label),
          ),
          if (engine.isLoading && engine.value == null)
            const LinearProgressIndicator()
          else if (matches.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('Nothing saved matches. Try searching online.'),
            ),
          for (final m in matches)
            ListTile(
              key: Key('local-${m.candidate.key}'),
              minTileHeight: 56,
              title: Text(
                m.candidate.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(_candidateLine(m.candidate)),
              onTap: () => widget.onPickLocal!(m.candidate),
            ),
          const SizedBox(height: 8),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text('Online', style: label),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: _sourcePicker(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: FilledButton.tonalIcon(
            key: const Key('search-online-button'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: q.isEmpty ? null : _search,
            icon: const Icon(Icons.travel_explore),
            label: Text(q.isEmpty ? 'Search online' : 'Search online for "$q"'),
          ),
        ),
        ..._remoteRows(),
      ],
    );
  }

  /// "Search online" page: the source picker is above, results fill it.
  Widget _remoteOnlyBody() {
    if (_results == null) {
      return const _Hint('Type a food and press Search.');
    }
    return ListView(children: _remoteRows());
  }

  List<Widget> _remoteRows() {
    final r = _results;
    if (r == null) return const [];
    return switch (r) {
      AsyncData(:final value) when value.isEmpty => const [
        _Hint('No results online. Try other words.'),
      ],
      AsyncData(:final value) => [
        for (final f in value)
          ListTile(
            minTileHeight: 56,
            title: Text(f.name, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              [
                if (f.brand != null) f.brand!,
                f.kcalPer100g == null
                    ? 'No nutrition data (enter from label)'
                    : '${f.kcalPer100g!.round()} kcal/100 g',
              ].join(' · '),
            ),
            onTap: () => widget.onPick(f),
          ),
      ],
      AsyncError(:final error, :final stackTrace) => [
        ErrorRetry(
          error: error,
          stackTrace: stackTrace,
          message: 'Search didn\'t work.',
          onRetry: _search,
        ),
      ],
      _ => const [
        Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
    };
  }
}

String _candidateLine(FoodCandidate c) => [
  if (c.brand != null) c.brand!,
  '${c.per100g.kcal.round()} kcal/100 g',
  if (c.isBuiltin)
    'typical values'
  else if (c.isOwn)
    'my food'
  else if (c.isFavorite)
    'favorite',
].join(' · ');

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Text(text, textAlign: TextAlign.center),
  );
}
