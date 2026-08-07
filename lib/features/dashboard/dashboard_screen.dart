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
import '../market/presentation/player_market_screen.dart';
import '../news/presentation/news_screen.dart';
import '../player/domain/position.dart';
import '../roster/domain/roster_legality.dart';
import '../roster/domain/roster_status.dart';
import '../season/application/franchise_rosters.dart';
import '../season/domain/game_day.dart';
import '../season/domain/game_result.dart';
import '../season/domain/scheduled_game.dart';
import '../season/domain/season_progress.dart';
import '../season/domain/standings_entry.dart';
import '../season/generation/postseason_generator.dart' show seasonChampion;
import '../season/presentation/game_result_screen.dart';
import '../season/presentation/match_preview_screen.dart';
import '../season/presentation/season_recap_screen.dart';
import '../stats/presentation/stats_screen.dart';
import '../training/domain/training_report.dart';
import '../training/presentation/training_report_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  var _selectedIndex = 0;

  static const _titles = ['Dashboard', 'Team', 'League', 'Stats', 'News'];

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
            3 => const StatsScreen(),
            4 => const NewsScreen(),
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
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Stats',
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
                      if (_activeRosterCount(value) < kActiveRosterSize) ...[
                        const SizedBox(height: AppSpacing.lg),
                        _AssistantGmMailCard(franchise: value),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      _SeasonAdvanceCard(franchise: value),
                      if (_isTrainingReportReady(value)) ...[
                        const SizedBox(height: AppSpacing.lg),
                        _TrainingReadyCard(franchise: value),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      _RecentNewsCard(franchise: value),
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

int _activeRosterCount(Franchise franchise) =>
    franchise.roster.where((m) => m.status == RosterStatus.active).length;

/// "You need to hire a free agent before we can advance" -- a direct GM
/// ask for a real Day-0 hook: a fresh expansion roster starts one player
/// short of [kActiveRosterSize] on purpose
/// (`roster/generation/starting_roster_generator.dart`'s doc comment),
/// and the season genuinely can't advance until that gap is filled
/// (`CurrentFranchiseNotifier.advanceGameDay`'s own guard). Shown
/// whenever [_activeRosterCount] is under the cap -- in practice that's
/// only ever Day 0 today, since nothing else currently shrinks the active
/// roster below 12 once it's been filled once, but the card reads the
/// live count rather than hardcoding "Day 0" so it'd still make sense if
/// that ever changed.
///
/// Names the actual best pickup in `Franchise.freeAgents` by finding
/// whoever has the highest `potential` -- the one deliberately-planted
/// "decent" free agent every pool gets
/// (`roster/generation/free_agent_pool_generator.dart`) stands out from
/// the filler by a wide margin, so no explicit "this is the one" flag is
/// needed on the player itself.
class _AssistantGmMailCard extends StatelessWidget {
  const _AssistantGmMailCard({required this.franchise});

  final Franchise franchise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prospect = franchise.freeAgents.isEmpty
        ? null
        : franchise.freeAgents.reduce(
            (a, b) => a.ratings.potential > b.ratings.potential ? a : b,
          );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.mail_outline, color: theme.colorScheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'From Your Assistant GM',
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Boss -- we\'re one player short of a full active roster. We '
            'need to sign a free agent before we can advance the season. '
            'Our starting five is already set, so I\'d skip the safe '
            'veterans and bet on upside.'
            '${prospect == null ? '' : ' Take a look at ${prospect.name} '
                      '(${prospect.primaryPosition.abbreviation}) -- that '
                      'ceiling is worth the roster spot.'}',
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PlayerMarketScreen(franchise: franchise),
                ),
              );
            },
            icon: const Icon(Icons.storefront_outlined),
            label: const Text('Open Player Market'),
          ),
        ],
      ),
    );
  }
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

/// A quiet preview of the News feed -- the 2 most recent training reports,
/// each tappable straight to its full report, plus a link to the full
/// `NewsScreen` archive. Deliberately placed at the very bottom of the
/// Dashboard's scroll, below the actionable Season/Training cards -- news
/// is something to catch up on, not something competing with "what do I
/// need to do right now."
class _RecentNewsCard extends StatelessWidget {
  const _RecentNewsCard({required this.franchise});

  final Franchise franchise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recent = [...franchise.trainingReports]
      ..sort((a, b) => b.week.compareTo(a.week));
    final preview = recent.take(2).toList();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('News', style: theme.textTheme.titleMedium)),
              TextButton(
                onPressed: () {
                  Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const NewsScreen()));
                },
                child: const Text('View All'),
              ),
            ],
          ),
          if (preview.isEmpty)
            const Text(
              'No news yet -- check back once your team starts '
              'training and playing games.',
            )
          else
            for (final report in preview)
              _RecentNewsRow(franchise: franchise, report: report),
        ],
      ),
    );
  }
}

class _RecentNewsRow extends StatelessWidget {
  const _RecentNewsRow({required this.franchise, required this.report});

  final Franchise franchise;
  final TrainingReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final changedCount = report.results.length;

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                TrainingReportScreen(franchise: franchise, report: report),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            Icon(
              Icons.fitness_center_outlined,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                changedCount == 0
                    ? 'Week ${report.week} Training Report -- no one moved '
                          'the needle.'
                    : 'Week ${report.week} Training Report -- $changedCount '
                          'player${changedCount == 1 ? '' : 's'} changed.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
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
            if (_activeRosterCount(franchise) < kActiveRosterSize)
              // The Assistant GM mail card above already explains why and
              // links to Player Market -- this just confirms there's
              // genuinely nothing to press here yet, not a dead end.
              Text(
                'Sign a free agent to fill your roster before advancing.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              )
            else
              FilledButton(
                onPressed: _isAdvancing ? null : _advanceOrPreview,
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

  /// Routes to `MatchPreviewScreen` when the GM's own team is scheduled to
  /// play on the very next game day (`nextOwnGame`) -- a direct GM ask for
  /// "some kind of splash before my games, not just straight to the
  /// result." A bye day (no own game today, even if games are scheduled
  /// for every other team) skips straight to [_advance] exactly like
  /// before -- there's nothing of the GM's own to preview.
  void _advanceOrPreview() {
    final franchise = widget.franchise;
    final ownGame = nextOwnGame(
      franchise.seasonProgress,
      franchise.team.abbreviation,
    );
    if (ownGame == null) {
      _advance();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MatchPreviewScreen(franchise: franchise, game: ownGame),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (game.type == GameType.preseason) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: 1,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'PRESEASON',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          Expanded(
            child: Text(
              '$cupBadge${formatFictionalDate(game.week, game.day)} '
              '${isHome ? 'vs' : '@'} ${opponent.emoji} ${opponent.name} '
              '(${opponentRecord.wins}-${opponentRecord.losses})',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
