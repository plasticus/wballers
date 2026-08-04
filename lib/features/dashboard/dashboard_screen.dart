import 'package:flutter/material.dart';

import '../../app/app_spacing.dart';
import '../../core/widgets/ad_placement_placeholder.dart';
import '../../core/widgets/app_card.dart';
import '../league/league_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  var _selectedIndex = 0;

  static const _titles = ['Dashboard', 'Team', 'League'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_selectedIndex])),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: switch (_selectedIndex) {
            0 => const DashboardScreen(),
            2 => const LeagueScreen(),
            _ => _ComingSoonPage(title: _titles[_selectedIndex]),
          },
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Team',
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon: Icon(Icons.emoji_events),
            label: 'League',
          ),
        ],
      ),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // The ad placeholder stays pinned outside the scroll view; only the
    // content above it scrolls. A plain Column + Spacer here would overflow
    // at large text scales instead of scrolling, so this shape is load-bearing.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Women\'s Basketball Manager',
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Build a franchise. Shape a league. Leave a legacy.',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xl),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Foundation setup',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const Text(
                        'The offline game shell is ready. Expansion franchises, rosters, and local saves are the next build targets.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        const AdPlacementPlaceholder(placement: 'Dashboard banner'),
      ],
    );
  }
}

class _ComingSoonPage extends StatelessWidget {
  const _ComingSoonPage({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('$title is coming in the franchise vertical slice.'),
    );
  }
}
