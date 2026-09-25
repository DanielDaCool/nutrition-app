// Root widget: MaterialApp theme and the bottom-navigation shell that hosts
// the four top-level screens.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/activity/activity_providers.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/settings/setup_screen.dart';
import '../features/targets/targets_providers.dart';
import '../features/today/today_screen.dart';
import '../features/weight/weight_screen.dart';
import 'providers.dart';

/// Root `MaterialApp`: dark only (green Material 3), whatever the phone's
/// setting.
class NutritionApp extends StatelessWidget {
  const NutritionApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF2E7D5B);
    return MaterialApp(
      title: 'Nutrition',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeShell(),
    );
  }
}

/// Bottom-navigation shell. Also triggers a Health Connect sync on start and
/// whenever the app returns to the foreground, opens the "Get started" setup
/// once per app start while there is no profile, badges Settings when a
/// check-in is due, and jumps Today back to today when its tab is re-tapped.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell>
    with WidgetsBindingObserver {
  int _index = 0;

  /// Setup was already offered in this app session (don't nag after Later).
  bool _setupOffered = false;

  static const _pages = <Widget>[
    TodayScreen(),
    WeightScreen(),
    DashboardScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
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
    if (state == AppLifecycleState.resumed) _sync();
  }

  void _sync() {
    if (!mounted) return;
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

  void _select(int i) {
    if (i == 0 && _index == 0) {
      ref.read(selectedDayProvider.notifier).today();
    }
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final checkInDue = ref.watch(checkInDueProvider).value ?? false;
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: [
          const NavigationDestination(icon: Icon(Icons.today), label: 'Today'),
          const NavigationDestination(
            icon: Icon(Icons.monitor_weight_outlined),
            label: 'Weight',
          ),
          const NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Badge(
              key: const Key('settingsBadge'),
              isLabelVisible: checkInDue,
              child: const Icon(Icons.settings_outlined),
            ),
            tooltip: checkInDue ? 'Settings, check-in ready' : null,
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
