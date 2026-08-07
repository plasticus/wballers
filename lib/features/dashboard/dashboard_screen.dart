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
import '../news/presentation/news_screen.dart';
import '../roster/domain/roster_status.dart';
import '../season/application/franchise_rosters.dart';
import '../season/domain/game_day.dart';
import '../season/domain/game_result.dart';
import '../season/domain/scheduled_game.dart';
import '../season/domain/season_progress.dart';
import '../season/domain/standings_entry.dart';
import '../season/generation/postseason_generator.dart' show seasonChampion;
import '../season/presentation/game_result_screen.dart';
import '../season/presentation/season_recap_screen.dart';
import '../training/presentation/training_report_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  var _selectedIndex = 0;

  static const _titles = ['Dashboard', 'Team', 'League', 'News'];

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
            3 => const NewsScreen(),
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
          NavigationDestination(
            icon: Icon(Icons.newspaper_outlined),
            selectedIcon: Icon(Icons.newspaper),
            label: 'News',
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
    final hasFranchise =
        franchiseState is AsyncData<Franchise?> && franchiseState.value != null;

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
                // The title-screen hero only makes sense before a franchise
                // exists -- once the GM is actually managing a club, it just
                // pushes everything else down like a splash screen that
                // never went away.
                if (!hasFranchise) ...[
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
                ],
                switch (franchiseState) {
                  AsyncData(:final value?) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _FranchiseSummaryCard(franchise: value),
                      const SizedBox(height: AppSpacing.lg),
                      _SeasonAdvanceCard(franchise: value),
                      if (_isTrainingReportReady(value)) ...[
                        const SizedBox(height: AppSpacing.lg),
                        _TrainingReadyCard(franchise: value),
                      ],
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
          Row(
            children: [
              // The chosen emoji standing in for a real team crest -- no
              // custom-logo-upload system exists, so this is the closest
              // thing the club has to one.
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: franchise.team.colors.primary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  franchise.team.emoji,
                  style: const TextStyle(fontSize: 26),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  franchise.team.name,
                  style: theme.textTheme.titleLarge,
                ),
              ),
            ],
          ),
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

/// Whether a new weekly training result is waiting to be resolved -- true
/// once [lastFullyCompletedWeek] has moved past [Franchise.nextTrainingWeek],
/// the same guard [runTraining] itself uses. Checked here (rather than
/// just trying [runTrainingAndPersist] and seeing what comes back) so the
/// Dashboard only shows the affordance when there's actually something to
/// resolve.
bool _isTrainingReportReady(Franchise franchise) {
  final week = lastFullyCompletedWeek(franchise.seasonProgress);
  return week != null && week >= franchise.nextTrainingWeek;
}

/// "Your training staff has feedback" -- the actionable prompt for a
/// training result that hasn't been resolved yet. Resolves training on
/// tap and hands off to [TrainingReportScreen] for the surfaced moment,
/// same "here's your transient window" deal [_SeasonAdvanceCard] gives a
/// game result. Distinct from `NewsScreen`, which is the passive archive
/// of every report once it's been resolved -- this card is what actually
/// produces the entry `NewsScreen` will go on to list.
class _TrainingReadyCard extends ConsumerStatefulWidget {
  const _TrainingReadyCard({required this.franchise});

  final Franchise franchise;

  @override
  ConsumerState<_TrainingReadyCard> createState() => _TrainingReadyCardState();
}

class _TrainingReadyCardState extends ConsumerState<_TrainingReadyCard> {
  var _isResolving = false;

  Future<void> _resolveTraining() async {
    setState(() => _isResolving = true);
    final report = await ref
        .read(currentFranchiseProvider.notifier)
        .runTrainingAndPersist();
    if (!mounted) return;
    setState(() => _isResolving = false);
    if (report == null) return;

    final updatedFranchise = ref.read(currentFranchiseProvider).value;
    if (updatedFranchise == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            TrainingReportScreen(franchise: updatedFranchise, report: report),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Training Report Ready', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          const Text('Your training staff has feedback on the roster.'),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: _isResolving ? null : _resolveTraining,
            child: _isResolving
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('View Training Report'),
          ),
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
    final record = recordFor(
      franchise.team.abbreviation,
      currentStandings(progress, leagueTeams),
    );

    final champion = seasonChampion(progress.playedGames);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Season', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text('${record.wins}-${record.losses}'),
          const SizedBox(height: AppSpacing.sm),
          if (champion != null) ...[
            Text(
              '🏆 ${teamByAbbreviation(franchise, champion).name} are the '
              'champions!',
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SeasonRecapScreen(franchise: franchise),
                  ),
                );
              },
              child: const Text('View Season Recap'),
            ),
          ] else if (progress.isComplete) ...[
            const Text('Regular season complete.'),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: _isAdvancing ? null : _simulatePostseason,
              child: _isAdvancing
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Simulate Postseason'),
            ),
          ] else ...[
            _UpcomingGamesList(franchise: franchise),
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

  /// Runs the whole postseason bracket in one shot. If the GM's own team
  /// played in the Finals-clinching game, hands off to [GameResultScreen]
  /// for that one (same "surface the GM's own moment" treatment
  /// [_advance] gives a regular game day) -- otherwise just announces the
  /// champion, since the "Season" card above already grows a permanent
  /// champion banner once this persists.
  Future<void> _simulatePostseason() async {
    setState(() => _isAdvancing = true);
    final results = await ref
        .read(currentFranchiseProvider.notifier)
        .simulatePostseasonAndPersist();
    if (!mounted) return;
    setState(() => _isAdvancing = false);
    if (results == null || results.isEmpty) return;

    final ownAbbreviation = widget.franchise.team.abbreviation;
    GameResult? clinchingFinalsGame;
    for (final result in results) {
      if (result.game.postseasonRound == 3) clinchingFinalsGame = result;
    }

    final updatedFranchise = ref.read(currentFranchiseProvider).value;
    if (updatedFranchise == null) return;

    final ownGameInFinals =
        clinchingFinalsGame != null &&
        (clinchingFinalsGame.game.homeTeamAbbreviation == ownAbbreviation ||
            clinchingFinalsGame.game.awayTeamAbbreviation == ownAbbreviation);

    if (!mounted) return;
    if (ownGameInFinals) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GameResultScreen(
            franchise: updatedFranchise,
            result: clinchingFinalsGame!,
          ),
        ),
      );
    } else {
      final champion = seasonChampion(
        updatedFranchise.seasonProgress.playedGames,
      );
      final championTeam = champion == null
          ? null
          : teamByAbbreviation(updatedFranchise, champion);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            championTeam == null
                ? 'The postseason is complete.'
                : '🏆 ${championTeam.name} are the champions!',
          ),
        ),
      );
    }
  }
}

/// The GM's next few games, not just the very next one -- date, home/away,
/// opponent (with their own emoji, same "reads like a real scoreboard"
/// spirit as [_FranchiseSummaryCard]'s crest), and their current record.
class _UpcomingGamesList extends StatelessWidget {
  const _UpcomingGamesList({required this.franchise});

  final Franchise franchise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final games = upcomingGamesFor(
      franchise.seasonProgress,
      franchise.team.abbreviation,
    );
    if (games.isEmpty) {
      return const Text('No games left on the schedule.');
    }

    final leagueTeams = [
      franchise.team,
      for (final aiTeam in franchise.league.aiTeams) aiTeam.team,
    ];
    final standings = currentStandings(franchise.seasonProgress, leagueTeams);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Upcoming Games', style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        for (final game in games)
          _UpcomingGameRow(
            franchise: franchise,
            game: game,
            standings: standings,
          ),
      ],
    );
  }
}

class _UpcomingGameRow extends StatelessWidget {
  const _UpcomingGameRow({
    required this.franchise,
    required this.game,
    required this.standings,
  });

  final Franchise franchise;
  final ScheduledGame game;
  final List<StandingsEntry> standings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isHome = game.homeTeamAbbreviation == franchise.team.abbreviation;
    final opponentAbbreviation = isHome
        ? game.awayTeamAbbreviation
        : game.homeTeamAbbreviation;
    final opponent = teamByAbbreviation(franchise, opponentAbbreviation);
    final opponentRecord = recordFor(opponentAbbreviation, standings);

    final cupBadge = game.type == GameType.continentalCup ? '🏆 ' : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        '$cupBadge${formatFictionalDate(game.week, game.day)} '
        '${isHome ? 'vs' : '@'} ${opponent.emoji} ${opponent.name} '
        '(${opponentRecord.wins}-${opponentRecord.losses})',
        style: theme.textTheme.bodyMedium,
      ),
    );
  }
}
