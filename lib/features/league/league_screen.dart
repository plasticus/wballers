import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_spacing.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/wbl_logo.dart';
import '../franchise/application/current_franchise_provider.dart';
import '../franchise/domain/franchise.dart';
import '../franchise/onboarding/onboarding_screen.dart';
import '../roster/domain/team_overall.dart';
import '../season/application/franchise_rosters.dart';
import '../season/domain/game_day.dart';
import '../season/domain/played_game.dart';
import '../season/domain/scheduled_game.dart';
import '../season/domain/season_progress.dart';
import '../season/domain/standings_entry.dart';
import '../season/generation/continental_cup_generator.dart';
import '../season/generation/postseason_generator.dart';
import '../season/generation/season_schedule_generator.dart'
    show
        kContinentalCupRound1Week,
        kContinentalCupRound2Week,
        kContinentalCupRound3Week,
        kContinentalCupRound4Week,
        kContinentalCupRound5Week,
        weekLabel;
import '../season/presentation/results_screen.dart';
import '../season/presentation/schedule_screen.dart';
import 'domain/league_draw.dart';
import 'domain/team.dart';
import 'team_row.dart';

/// This playthrough's 20-team league (drawn from the 40-team design pool
/// via `drawLeagueTeams`, keyed on the franchise's `simulationSeed`),
/// grouped by conference, with the GM's own club substituted in for
/// whichever drawn team it replaced (see
/// `Franchise.replacedTeamAbbreviation`) — so the league genuinely reads as
/// 19 AI teams + 1 GM team, not the replaced team plus an unrelated 21st
/// club. There's no franchise (and so no league draw) until onboarding
/// runs. Ranked by regular-season record within each conference
/// (`currentStandings`) once games have been played -- teams that haven't
/// played yet sort to the bottom of their conference, alphabetically.
///
/// 3 tabs (added 2026-08-07, a direct GM ask): Regular Season (the
/// standings this screen originally was, unchanged), Cup, and Playoffs --
/// the standings-only view left no room to actually follow the Continental
/// Cup or postseason brackets as they unfold.
class LeagueScreen extends ConsumerWidget {
  const LeagueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final franchise = ref.watch(currentFranchiseProvider).value;
    if (franchise == null) {
      return EmptyStateView(
        icon: Icons.emoji_events_outlined,
        message: 'Create an expansion franchise to see your league.',
        action: FilledButton(
          onPressed: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const OnboardingScreen()));
          },
          child: const Text('Create Expansion Franchise'),
        ),
      );
    }

    return _LeagueView(franchise: franchise);
  }
}

class _LeagueView extends StatefulWidget {
  const _LeagueView({required this.franchise});

  final Franchise franchise;

  @override
  State<_LeagueView> createState() => _LeagueViewState();
}

class _LeagueViewState extends State<_LeagueView>
    with SingleTickerProviderStateMixin {
  late final _tabController = TabController(length: 3, vsync: this)
    ..addListener(() {
      // The tab controller fires this listener throughout the swipe
      // animation, not just on settle -- setState on every tick is what
      // makes the header logo track a swipe instead of only snapping at
      // the end.
      setState(() {});
    });

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final franchise = widget.franchise;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: _tabController.index == 1
              ? const ContinentalCupLogo(size: 144)
              : const WblLogo(size: 144),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ScheduleScreen(franchise: franchise),
                    ),
                  );
                },
                icon: const Icon(Icons.calendar_month_outlined),
                label: const Text('Schedule'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ResultsScreen(franchise: franchise),
                    ),
                  );
                },
                icon: const Icon(Icons.scoreboard_outlined),
                label: const Text('Results'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Regular Season'),
            Tab(text: 'Cup'),
            Tab(text: 'Playoffs'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _RegularSeasonTab(franchise: franchise),
              _CupTab(franchise: franchise),
              _PlayoffsTab(franchise: franchise),
            ],
          ),
        ),
      ],
    );
  }
}

class _RegularSeasonTab extends StatelessWidget {
  const _RegularSeasonTab({required this.franchise});

  final Franchise franchise;

  @override
  Widget build(BuildContext context) {
    final drawnTeams = drawLeagueTeams(
      Random(franchise.simulationSeed + kLeagueDrawSeedOffset),
    );
    final teams = [
      for (final team in drawnTeams)
        if (team.abbreviation == franchise.replacedTeamAbbreviation)
          franchise.team
        else
          team,
    ];

    final atlantic = teams
        .where((team) => team.conference == Conference.atlantic)
        .toList();
    final pacific = teams
        .where((team) => team.conference == Conference.pacific)
        .toList();
    final userTeamAbbreviation = franchise.team.abbreviation;
    final standings = currentStandings(franchise.seasonProgress, teams);
    final rosters = rostersByAbbreviation(franchise);
    final overallByAbbreviation = {
      for (final entry in rosters.entries)
        entry.key: teamOverallForPlayers(entry.value),
    };

    return ListView(
      children: [
        _ConferenceSection(
          title: Conference.atlantic.label,
          teams: _rankedByStandings(atlantic, standings),
          standings: standings,
          userTeamAbbreviation: userTeamAbbreviation,
          overallByAbbreviation: overallByAbbreviation,
        ),
        const SizedBox(height: AppSpacing.lg),
        _ConferenceSection(
          title: Conference.pacific.label,
          teams: _rankedByStandings(pacific, standings),
          standings: standings,
          userTeamAbbreviation: userTeamAbbreviation,
          overallByAbbreviation: overallByAbbreviation,
        ),
      ],
    );
  }
}

/// [conferenceTeams] sorted best-to-worst by [standings]' order -- teams
/// with no entry there (no regular-season games played yet) sort after
/// every ranked team, alphabetically among themselves.
List<Team> _rankedByStandings(
  List<Team> conferenceTeams,
  List<StandingsEntry> standings,
) {
  final rankIndex = {
    for (var i = 0; i < standings.length; i++) standings[i].teamAbbreviation: i,
  };
  final sorted = [...conferenceTeams];
  sorted.sort((a, b) {
    final aRank = rankIndex[a.abbreviation] ?? standings.length;
    final bRank = rankIndex[b.abbreviation] ?? standings.length;
    final byRank = aRank.compareTo(bRank);
    if (byRank != 0) return byRank;
    return a.abbreviation.compareTo(b.abbreviation);
  });
  return sorted;
}

class _ConferenceSection extends StatelessWidget {
  const _ConferenceSection({
    required this.title,
    required this.teams,
    required this.standings,
    required this.userTeamAbbreviation,
    required this.overallByAbbreviation,
  });

  final String title;
  final List<Team> teams;
  final List<StandingsEntry> standings;
  final String? userTeamAbbreviation;
  final Map<String, int> overallByAbbreviation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          child: Column(
            children: [
              for (var i = 0; i < teams.length; i++) ...[
                TeamRow(
                  team: teams[i],
                  isUserTeam: teams[i].abbreviation == userTeamAbbreviation,
                  rank: i + 1,
                  record: recordFor(teams[i].abbreviation, standings),
                  overall: overallByAbbreviation[teams[i].abbreviation],
                ),
                if (i != teams.length - 1) const Divider(height: AppSpacing.lg),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

typedef _FixtureKey = (int week, GameDay day, String home, String away);

_FixtureKey _fixtureKey(ScheduledGame game) =>
    (game.week, game.day, game.homeTeamAbbreviation, game.awayTeamAbbreviation);

/// A plain, centered banner announcing a champion -- shared by the Cup and
/// Playoffs tabs, same 🏆-prefixed text style the Dashboard's own season
/// card already uses.
class _ChampionBanner extends StatelessWidget {
  const _ChampionBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Text(
        text,
        style: theme.textTheme.titleMedium,
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// The Continental Cup bracket, Round 1 through the Final -- a direct GM
/// ask ("the Cup screen should probably also list upcoming round
/// matches"). Rounds 2-5 don't exist in `SeasonProgress.schedule` until
/// the round before them actually finishes (`season_advancer.dart`'s
/// `_growContinentalCup` generates each one on demand, since pairings
/// depend on real results -- margin-of-victory seeding for Round 2, random
/// draws after that) -- so a round with no games yet just says so, rather
/// than guessing at a matchup that doesn't exist.
class _CupTab extends StatelessWidget {
  const _CupTab({required this.franchise});

  final Franchise franchise;

  @override
  Widget build(BuildContext context) {
    final progress = franchise.seasonProgress;
    final champion = continentalCupChampion(progress.playedGames);
    final playedByFixture = {
      for (final played in progress.playedGames)
        _fixtureKey(played.game): played,
    };

    return ListView(
      children: [
        if (champion != null) ...[
          _ChampionBanner(
            text:
                '🏆 ${teamByAbbreviation(franchise, champion).name} are the '
                'Continental Cup champions!',
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        for (var round = 1; round <= 5; round++) ...[
          _CupRoundSection(
            franchise: franchise,
            round: round,
            games: [
              for (final game in progress.schedule.games)
                if (game.type == GameType.continentalCup &&
                    game.continentalCupRound == round)
                  game,
            ],
            playedByFixture: playedByFixture,
          ),
          if (round != 5) const SizedBox(height: AppSpacing.lg),
        ],
      ],
    );
  }
}

/// The fixed game week a Continental Cup [round] falls on -- a compile-time
/// constant regardless of whether that round's games have actually been
/// generated yet (`_growContinentalCup` only creates them once the round
/// before finishes), so [_CupRoundSection] can show it in the header even
/// for a not-yet-set round (a direct GM ask, 2026-08-15: "we should add
/// what game week those rounds are happening").
int continentalCupRoundWeek(int round) => switch (round) {
  1 => kContinentalCupRound1Week,
  2 => kContinentalCupRound2Week,
  3 => kContinentalCupRound3Week,
  4 => kContinentalCupRound4Week,
  5 => kContinentalCupRound5Week,
  _ => throw ArgumentError.value(round, 'round', 'must be 1-5'),
};

class _CupRoundSection extends StatelessWidget {
  const _CupRoundSection({
    required this.franchise,
    required this.round,
    required this.games,
    required this.playedByFixture,
  });

  final Franchise franchise;
  final int round;
  final List<ScheduledGame> games;
  final Map<_FixtureKey, PlayedGame> playedByFixture;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${continentalCupRoundName(round)} '
          '(${weekLabel(continentalCupRoundWeek(round))})',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (games.isEmpty)
          AppCard(
            child: Text(
              'Set once ${continentalCupRoundName(round - 1)} finishes.',
              style: theme.textTheme.bodyMedium,
            ),
          )
        else
          for (var i = 0; i < games.length; i++) ...[
            _CupGameRow(
              franchise: franchise,
              game: games[i],
              played: playedByFixture[_fixtureKey(games[i])],
            ),
            if (i != games.length - 1) const SizedBox(height: AppSpacing.sm),
          ],
      ],
    );
  }
}

class _CupGameRow extends StatelessWidget {
  const _CupGameRow({
    required this.franchise,
    required this.game,
    required this.played,
  });

  final Franchise franchise;
  final ScheduledGame game;
  final PlayedGame? played;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final homeTeam = teamByAbbreviation(franchise, game.homeTeamAbbreviation);
    final awayTeam = teamByAbbreviation(franchise, game.awayTeamAbbreviation);
    final played = this.played;

    final row = Row(
      children: [
        Expanded(
          child: Text(
            '${awayTeam.emoji} ${awayTeam.name} @ '
            '${homeTeam.emoji} ${homeTeam.name}',
            style: theme.textTheme.bodyMedium,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        if (played == null)
          Text(
            formatFictionalDate(game.week, game.day),
            style: theme.textTheme.bodySmall,
          )
        else
          Text(
            '${played.awayScore}-${played.homeScore}',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    );

    if (played == null) return AppCard(child: row);
    return AppCard(
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  PlayedGameDetailScreen(franchise: franchise, played: played),
            ),
          );
        },
        child: row,
      ),
    );
  }
}

/// The postseason bracket, First Round through the Finals. Unlike the
/// Continental Cup, the whole bracket resolves in one shot the moment the
/// GM taps "Simulate Postseason" on the Dashboard (`postseason_generator.dart`'s
/// `simulatePostseason` -- a series' length isn't known ahead of time, so
/// there's nothing to pre-schedule one round at a time), so this tab only
/// really has 2 states: nothing played yet (every round shows a projected
/// matchup) or fully decided.
class _PlayoffsTab extends StatelessWidget {
  const _PlayoffsTab({required this.franchise});

  final Franchise franchise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = franchise.seasonProgress;

    if (!progress.isComplete) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            'Playoffs begin once the regular season and Continental Cup '
            'wrap up.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final bracket = reconstructPostseasonBracket(
      progress,
      leagueTeams: allLeagueTeams(franchise),
    );
    if (bracket == null) {
      return Center(
        child: Text(
          'Standings still developing.',
          style: theme.textTheme.bodyMedium,
        ),
      );
    }

    final champion = seasonChampion(progress.playedGames);

    return ListView(
      children: [
        if (champion != null) ...[
          _ChampionBanner(
            text:
                '🏆 ${teamByAbbreviation(franchise, champion).name} are the '
                'champions!',
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        for (var round = 1; round <= 3; round++) ...[
          _PostseasonRoundSection(
            franchise: franchise,
            round: round,
            series: bracket[round - 1],
          ),
          if (round != 3) const SizedBox(height: AppSpacing.lg),
        ],
      ],
    );
  }
}

class _PostseasonRoundSection extends StatelessWidget {
  const _PostseasonRoundSection({
    required this.franchise,
    required this.round,
    required this.series,
  });

  final Franchise franchise;
  final int round;
  final List<PostseasonSeriesView> series;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(postseasonRoundName(round), style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        if (series.isEmpty)
          AppCard(
            child: Text(
              'Set once ${postseasonRoundName(round - 1)} finishes.',
              style: theme.textTheme.bodyMedium,
            ),
          )
        else
          for (var i = 0; i < series.length; i++) ...[
            _PostseasonSeriesRow(franchise: franchise, series: series[i]),
            if (i != series.length - 1) const SizedBox(height: AppSpacing.sm),
          ],
      ],
    );
  }
}

class _PostseasonSeriesRow extends StatelessWidget {
  const _PostseasonSeriesRow({required this.franchise, required this.series});

  final Franchise franchise;
  final PostseasonSeriesView series;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final higher = teamByAbbreviation(franchise, series.higherSeedAbbreviation);
    final lower = teamByAbbreviation(franchise, series.lowerSeedAbbreviation);
    final winner = series.winnerAbbreviation;

    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${higher.emoji} ${higher.name}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: winner == series.higherSeedAbbreviation
                        ? FontWeight.bold
                        : null,
                  ),
                ),
                Text(
                  '${lower.emoji} ${lower.name}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: winner == series.lowerSeedAbbreviation
                        ? FontWeight.bold
                        : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            series.games.isEmpty
                ? 'Upcoming'
                : '${series.higherSeedWins}-${series.lowerSeedWins}',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
