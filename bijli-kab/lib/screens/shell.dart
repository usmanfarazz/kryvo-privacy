import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import 'forecast_screen.dart';
import 'home_screen.dart';
import 'map_screen.dart';
import 'more_screen.dart';
import 'stats_screen.dart';

/// Bottom navigation: Home · Map · Forecast · Stats · More.
class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(onOpenTab: (i) => setState(() => _tab = i)),
      const MapScreen(),
      const ForecastScreen(),
      const StatsScreen(),
      const MoreScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        height: 68,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.bolt_outlined),
            selectedIcon: const Icon(Icons.bolt_rounded),
            label: tr('Home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.map_outlined),
            selectedIcon: const Icon(Icons.map_rounded),
            label: tr('Map'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.schedule_outlined),
            selectedIcon: const Icon(Icons.schedule_rounded),
            label: tr('Forecast'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.insights_outlined),
            selectedIcon: const Icon(Icons.insights_rounded),
            label: tr('Stats'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.grid_view_outlined),
            selectedIcon: const Icon(Icons.grid_view_rounded),
            label: tr('More'),
          ),
        ],
      ),
    );
  }
}
