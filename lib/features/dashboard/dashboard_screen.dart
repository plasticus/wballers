import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_spacing.dart';
import '../../core/widgets/ad_placement_placeholder.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/state_views.dart';
import '../franchise/application/current_franchise_provider.dart';
import '../franchise/domain/franchise.dart';
import '../franchise/onboarding/onboarding_screen.dart';
import '../league/league_screen.dart';
import '../roster/domain/roster_status.dart';

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

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final franchiseState = ref.watch(currentFranchiseProvider);

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
                switch (franchiseState) {
                  AsyncData(:final value?) => _FranchiseSummaryCard(
                    franchise: value,
                  ),
                  AsyncData() => const _NoFranchiseCard(),
                  AsyncError() => ErrorStateView(
                    message: 'Could not load your franchise save.',
                  ),
                  _ => const LoadingView(message: 'Loading your franchise…'),
                },
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

class _NoFranchiseCard extends StatelessWidget {
  const _NoFranchiseCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('No franchise yet', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Create an expansion club to receive your coach, your team identity, and a starting roster.',
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const OnboardingScreen()),
              );
            },
            child: const Text('Create Expansion Franchise'),
          ),
        ],
      ),
    );
  }
}

class _FranchiseSummaryCard extends StatelessWidget {
  const _FranchiseSummaryCard({required this.franchise});

  final Franchise franchise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeCount = franchise.roster
        .where((m) => m.status == RosterStatus.active)
        .length;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(franchise.team.name, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${franchise.team.location} · ${franchise.team.conference.name}',
          ),
          Text('Coach ${franchise.coach.name}'),
          const SizedBox(height: AppSpacing.sm),
          Text('$activeCount players on the active roster'),
        ],
      ),
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
