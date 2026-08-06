import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_spacing.dart';
import '../../core/widgets/ad_placement_placeholder.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/wbl_logo.dart';
import '../franchise/application/current_franchise_provider.dart';
import '../franchise/domain/franchise.dart';
import '../franchise/onboarding/onboarding_screen.dart';
import '../franchise/presentation/team_roster_screen.dart';
import '../league/domain/team.dart';
import '../league/league_screen.dart';
import '../roster/domain/roster_status.dart';
import '../season/application/franchise_rosters.dart';
import '../season/domain/game_day.dart';
import '../season/domain/game_result.dart';
import '../season/domain/season_progress.dart';
import '../season/domain/standings_entry.dart';
import '../season/presentation/game_result_screen.dart';

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
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.all(AppSpacing.xs),
          child: WblLogo(size: 32),
        ),
        title: Text(_titles[_selectedIndex]),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: switch (_selectedIndex) {
            0 => const DashboardScreen(),
            1 => const TeamRosterScreen(),
            2 => const LeagueScreen(),
            _ => const SizedBox.shrink(),
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
                const Center(child: WblLogo(size: 96)),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Women\'s Basketball Manager',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Build a franchise. Shape a league. Leave a legacy.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xl),
                switch (franchiseState) {
                  AsyncData(:final value?) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _FranchiseSummaryCard(franchise: value),
                      const SizedBox(height: AppSpacing.lg),
                      _SeasonAdvanceCard(franchise: value),
                    ],
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
            '${franchise.team.location} · ${franchise.team.conference.label}',
          ),
          Text('GM ${franchise.gmName}'),
          Text('Head Coach ${franchise.coach.name}'),
          const SizedBox(height: AppSpacing.sm),
          Text('$activeCount players on the active roster'),
        ],
      ),
    );
  }
}

/// Season status plus the one action that actually moves it forward:
/// [Franchise.seasonProgress]'s record so far, a preview of the next game
/// day (who the GM's own team plays, if anyone that day), and the
/// "Advance to Next Game Day" button itself. Deliberately day-granular,
/// not week-granular -- see `season_advancer.dart`'s doc comment on why
/// an "Advance Week" action would blow past individual games.
///
/// If the GM's own team is part of the game day just advanced, this hands
/// off to [GameResultScreen] for that one game's box score instead of
/// letting it disappear silently into the standings like every other
/// team's -- everything else in the day still gets simulated exactly the
/// same way (`advanceGameDay`'s doc comment).
class _SeasonAdvanceCard extends ConsumerStatefulWidget {
  const _SeasonAdvanceCard({required this.franchise});

  final Franchise franchise;

  @override
  ConsumerState<_SeasonAdvanceCard> createState() => _SeasonAdvanceCardState();
}

class _SeasonAdvanceCardState extends ConsumerState<_SeasonAdvanceCard> {
  var _isAdvancing = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final franchise = widget.franchise;
    final progress = franchise.seasonProgress;
    final leagueTeams = [
      franchise.team,
      for (final aiTeam in franchise.league.aiTeams) aiTeam.team,
    ];
    final record = _ownRecord(franchise, leagueTeams);
    final gameDays = gameDaysInOrder(progress.schedule);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Season', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text('${record.wins}-${record.losses}'),
          const SizedBox(height: AppSpacing.sm),
          if (progress.isComplete)
            const Text('Season complete.')
          else ...[
            Text(_nextGameDayLabel(franchise, gameDays)),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: _isAdvancing ? null : _advance,
              child: _isAdvancing
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Advance to Next Game Day'),
            ),
          ],
        ],
      ),
    );
  }

  StandingsEntry _ownRecord(Franchise franchise, List<Team> leagueTeams) {
    final standings = currentStandings(franchise.seasonProgress, leagueTeams);
    for (final entry in standings) {
      if (entry.teamAbbreviation == franchise.team.abbreviation) return entry;
    }
    return StandingsEntry(
      teamAbbreviation: franchise.team.abbreviation,
      wins: 0,
      losses: 0,
      pointsFor: 0,
      pointsAgainst: 0,
    );
  }

  String _nextGameDayLabel(
    Franchise franchise,
    List<(int week, GameDay day)> gameDays,
  ) {
    final (week, day) = gameDays[franchise.seasonProgress.nextGameDayIndex];
    final todaysGames = franchise.seasonProgress.schedule.games.where(
      (g) => g.week == week && g.day == day,
    );

    for (final game in todaysGames) {
      final isHome = game.homeTeamAbbreviation == franchise.team.abbreviation;
      final isAway = game.awayTeamAbbreviation == franchise.team.abbreviation;
      if (isHome || isAway) {
        final opponentAbbreviation = isHome
            ? game.awayTeamAbbreviation
            : game.homeTeamAbbreviation;
        final opponent = teamByAbbreviation(franchise, opponentAbbreviation);
        final vsAt = isHome ? 'vs' : 'at';
        return 'Next: ${day.label}, Week $week -- $vsAt ${opponent.name}';
      }
    }

    return 'Next: ${day.label}, Week $week -- your team has a bye';
  }

  Future<void> _advance() async {
    setState(() => _isAdvancing = true);
    final results = await ref
        .read(currentFranchiseProvider.notifier)
        .advanceGameDay();
    if (!mounted) return;
    setState(() => _isAdvancing = false);
    if (results == null) return;

    final ownAbbreviation = widget.franchise.team.abbreviation;
    GameResult? ownGame;
    for (final result in results) {
      if (result.game.homeTeamAbbreviation == ownAbbreviation ||
          result.game.awayTeamAbbreviation == ownAbbreviation) {
        ownGame = result;
        break;
      }
    }

    if (!mounted) return;
    final updatedFranchise = ref.read(currentFranchiseProvider).value;
    if (updatedFranchise == null) return;

    if (ownGame != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              GameResultScreen(franchise: updatedFranchise, result: ownGame!),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${results.length} game${results.length == 1 ? '' : 's'} '
            'simulated across the league.',
          ),
        ),
      );
    }
  }
}
