// Root widget: MaterialApp theme and the bottom-navigation shell that hosts
// the four top-level screens.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_features.dart';
import '../core/day_key.dart';
import '../features/activity/activity_providers.dart';
import '../features/dashboard/dashboard_providers.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/recipes/recipes_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/settings/setup_screen.dart';
import '../features/targets/targets_providers.dart';
import '../features/today/today_screen.dart';
import '../features/weight/weight_providers.dart';
import '../features/weight/weight_screen.dart';
import 'install_hint_banner.dart';
import 'providers.dart';
import 'theme.dart';
import 'update_available_banner.dart';

/// Root `MaterialApp`: dark only (see theme.dart), whatever the phone's
/// setting.
class NutritionApp extends StatelessWidget {
  const NutritionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nutrition',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: buildAppTheme(),
      home: const HomeShell(),
    );
  }
}

/// Bottom-navigation shell. Also triggers a Health Connect sync on start and
/// whenever the app returns to the foreground, opens the "Get started" setup
/// once per app start while there is no profile, badges Settings when a
/// check-in is due, and jumps Today back to today when its tab is re-tapped.
/// The Recipes tab is left out while its feature gate is off.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

/// The top-level tabs. The selection is tracked by tab, not by position, so
/// it stays put when a tab's feature gate goes off.
enum _Tab { today, weight, dashboard, recipes, settings }

class _HomeShellState extends ConsumerState<HomeShell>
    with WidgetsBindingObserver {
  _Tab _tab = _Tab.today;

  /// One key per tab, so a page keeps its State (scroll position, Settings'
  /// inner tab) when another tab is added or removed and it changes position.
  /// Global keys because IndexedStack wraps its children in unkeyed widgets,
  /// so a plain ValueKey on the page would not be matched across positions.
  final _pageKeys = {
    for (final t in _Tab.values) t: GlobalKey(debugLabel: 'page-${t.name}'),
  };

  /// Setup was already offered in this app session (don't nag after Later).
  bool _setupOffered = false;

  /// Day key as of the last check, so a date change while backgrounded is
  /// caught even on screens (Weight, Dashboard) that don't rebuild on their
  /// own once the app resumes.
  late String _lastDayKey;

  Widget _page(_Tab tab) {
    final key = _pageKeys[tab];
    return switch (tab) {
      _Tab.today => TodayScreen(key: key),
      _Tab.weight => WeightScreen(key: key),
      _Tab.dashboard => DashboardScreen(key: key),
      _Tab.recipes => RecipesScreen(key: key),
      _Tab.settings => SettingsScreen(key: key),
    };
  }

  NavigationDestination _destination(_Tab tab, {required bool checkInDue}) {
    return switch (tab) {
      _Tab.today => const NavigationDestination(
        icon: Icon(Icons.today),
        label: 'Today',
      ),
      _Tab.weight => const NavigationDestination(
        icon: Icon(Icons.monitor_weight_outlined),
        label: 'Weight',
      ),
      _Tab.dashboard => const NavigationDestination(
        icon: Icon(Icons.insights_outlined),
        label: 'Dashboard',
      ),
      _Tab.recipes => const NavigationDestination(
        icon: Icon(Icons.restaurant_menu),
        label: 'Recipes',
      ),
      _Tab.settings => NavigationDestination(
        icon: Badge(
          key: const Key('settingsBadge'),
          isLabelVisible: checkInDue,
          child: const Icon(Icons.settings_outlined),
        ),
        tooltip: checkInDue ? 'Settings, check-in ready' : null,
        label: 'Settings',
      ),
    };
  }

  @override
  void initState() {
    super.initState();
    _lastDayKey = dayKeyOf(ref.read(clockProvider)());
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
    ref.listenManual(profileProvider, (_, next) {
      if (next case AsyncData(value: null)) _offerSetup();
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkDayRollover();
      _sync();
    }
  }

  /// If the calendar day moved on while the app was in the background,
  /// refreshes the providers that cache "today" for as long as they run
  /// (Weight's trend, the Dashboard's window). Today's own day switch is
  /// handled by TodayScreen; this only covers the other tabs.
  void _checkDayRollover() {
    final now = dayKeyOf(ref.read(clockProvider)());
    if (now == _lastDayKey) return;
    _lastDayKey = now;
    ref.invalidate(weightTrendProvider);
    ref.invalidate(dashboardWindowProvider);
  }

  void _sync() {
    if (!mounted) return;
    // No Health Connect on web.
    if (ref.read(isWebProvider)) return;
    ref.read(healthSyncProvider.notifier).syncNow();
  }

  void _offerSetup() {
    if (_setupOffered) return;
    _setupOffered = true;
    // Not during build: listeners can fire while the tree is building.
    scheduleMicrotask(() {
      if (mounted) openSetup(context);
    });
  }

  void _select(_Tab tab) {
    if (tab == _Tab.today && _tab == _Tab.today) {
      ref.read(selectedDayProvider.notifier).today();
    }
    setState(() => _tab = tab);
  }

  @override
  Widget build(BuildContext context) {
    final checkInDue = ref.watch(checkInDueProvider).value ?? false;
    final showRecipes = ref.watch(featureEnabledProvider(AppFeature.recipes));
    final tabs = [
      for (final t in _Tab.values)
        if (t != _Tab.recipes || showRecipes) t,
    ];
    // The selected tab's gate went off: fall back to Today for good, so it
    // doesn't jump back when the tab returns.
    if (!tabs.contains(_tab)) _tab = _Tab.today;
    final index = tabs.indexOf(_tab);
    Widget body = IndexedStack(
      index: index,
      children: [for (final t in tabs) _page(t)],
    );
    // Banners sit above the status bar inset instead of inside it, so the
    // screens below (each with their own AppBar/SafeArea) must not also
    // apply that inset, or it would be counted twice.
    final banners = <Widget>[
      if (ref.watch(showInstallHintProvider)) const InstallHintBanner(),
      if (ref.watch(updateAvailableTagProvider) != null)
        const UpdateAvailableBanner(),
    ];
    if (banners.isNotEmpty) {
      body = SafeArea(
        bottom: false,
        child: Column(
          children: [
            ...banners,
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: body,
              ),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => _select(tabs[i]),
        destinations: [
          for (final t in tabs) _destination(t, checkInDue: checkInDue),
        ],
      ),
    );
  }
}
