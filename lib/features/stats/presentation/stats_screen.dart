import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/state_views.dart';
import '../../franchise/application/current_franchise_provider.dart';
import '../../franchise/domain/franchise.dart';
import '../../franchise/onboarding/onboarding_screen.dart';
import '../../league/domain/team.dart';
import '../../player/domain/player.dart';
import '../../season/application/franchise_rosters.dart';
import '../../season/domain/league_leaders.dart';
import '../../season/domain/season_progress.dart';
import '../../season/domain/standings_entry.dart';

/// A player-plus-team pair, for anywhere the Stats tab needs to show who a
/// leaderboard entry actually is without re-deriving the lookup.
typedef _Entry = ({Player player, Team team});

/// Leaguewide statistics: who's leading in what, how every team stacks up
/// beyond win-loss, and one team's own roster stats side by side -- a
/// direct GM ask ("we're gonna need a stats screen... top performing
/// players, most points, most blocked shots, top fg%... a league mvp
/// race... look at teams from here, and see team stats, as well as
/// individual stats from the players on the team"). 3 sub-tabs cover the
/// 3 asks: Leaders (leaguewide per-category top 5s plus an MVP race),
/// Teams (a stat table beyond the League tab's plain win-loss standings),
/// and Roster (one team's players, side by side, defaulting to the GM's
/// own club). Read-only, like every other stats-adjacent screen in this
/// app -- nothing here advances or edits anything.
///
/// Deliberately doesn't link a leaderboard row into `PlayerDetailScreen`
/// the way the Team tab's roster rows do -- that screen only knows how to
/// look a player up on the GM's own `Franchise.roster`, not an AI team's,
/// and most leaders here will be AI players. A real "any player's detail
/// page" screen is future work, not a gap papered over here.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final franchiseState = ref.watch(currentFranchiseProvider);

    return switch (franchiseState) {
      AsyncData(:final value?) => _StatsView(franchise: value),
      AsyncData() => const _NoFranchiseView(),
      AsyncError() => const ErrorStateView(
        message: 'Could not load your franchise save.',
      ),
      _ => const LoadingView(message: 'Loading stats…'),
    };
  }
}

class _NoFranchiseView extends StatelessWidget {
  const _NoFranchiseView();

  @override
  Widget build(BuildContext context) {
    return EmptyStateView(
      icon: Icons.bar_chart_outlined,
      message: 'Create an expansion franchise to see league stats.',
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
}

Map<String, _Entry> _playerLookup(Franchise franchise) {
  final rosters = rostersByAbbreviation(franchise);
  return {
    for (final entry in rosters.entries)
      for (final player in entry.value)
        player.id: (
          player: player,
          team: teamByAbbreviation(franchise, entry.key),
        ),
  };
}

class _StatsView extends StatefulWidget {
  const _StatsView({required this.franchise});

  final Franchise franchise;

  @override
  State<_StatsView> createState() => _StatsViewState();
}

class _StatsViewState extends State<_StatsView>
    with SingleTickerProviderStateMixin {
  late final _tabController = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playerLookup = _playerLookup(widget.franchise);
    final leaders = computeLeagueLeaders(
      widget.franchise.seasonProgress.playedGames,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Leaders'),
            Tab(text: 'Teams'),
            Tab(text: 'Roster'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _LeadersTab(playerLookup: playerLookup, leaders: leaders),
              _TeamsTab(franchise: widget.franchise),
              _RosterTab(franchise: widget.franchise),
            ],
          ),
        ),
      ],
    );
  }
}

typedef _LeaderCategory = ({
  String label,
  double Function(PlayerSeasonTotals) selector,
  String Function(double) format,
  bool Function(PlayerSeasonTotals)? eligible,
});

String _oneDecimal(double v) => v.toStringAsFixed(1);
String _percent(double v) => '${(v * 100).round()}%';

final _categories = <_LeaderCategory>[
  (
    label: 'Points Per Game',
    selector: (t) => t.pointsPerGame,
    format: _oneDecimal,
    eligible: null,
  ),
  (
    label: 'Rebounds Per Game',
    selector: (t) => t.reboundsPerGame,
    format: _oneDecimal,
    eligible: null,
  ),
  (
    label: 'Assists Per Game',
    selector: (t) => t.assistsPerGame,
    format: _oneDecimal,
    eligible: null,
  ),
  (
    label: 'Steals Per Game',
    selector: (t) => t.stealsPerGame,
    format: _oneDecimal,
    eligible: null,
  ),
  (
    label: 'Blocks Per Game',
    selector: (t) => t.blocksPerGame,
    format: _oneDecimal,
    eligible: null,
  ),
  (
    label: 'Field Goal %',
    selector: (t) => t.fieldGoalPercentage,
    format: _percent,
    // A minimum-attempts floor so a single lucky 1-for-1 game doesn't
    // top the percentage leaderboard over a real volume shooter.
    eligible: (t) => t.fieldGoalAttempts >= 20,
  ),
];

class _LeadersTab extends StatelessWidget {
  const _LeadersTab({required this.playerLookup, required this.leaders});

  final Map<String, _Entry> playerLookup;
  final Map<String, PlayerSeasonTotals> leaders;

  @override
  Widget build(BuildContext context) {
    if (leaders.isEmpty) {
      return const EmptyStateView(
        icon: Icons.bar_chart_outlined,
        message:
            'No regular-season games played yet -- leaders show up once '
            'the season is underway.',
      );
    }

    final mvpRanking = [...leaders.values]
      ..sort((a, b) => b.mvpScore.compareTo(a.mvpScore));

    // Vertical padding only -- AppShell's own body Padding
    // (`dashboard_screen.dart`) already surrounds every tab, Stats
    // included, with `AppSpacing.lg` on every side; adding another full
    // `EdgeInsets.all` on top of that doubled the *side* margins and was
    // cramping row content into wrapping lines (a direct GM ask,
    // 2026-08-09, to fix). The vertical gap above the first section /
    // below the last is still wanted, since AppShell's own top/bottom
    // padding lands above the TabBar, not between it and this tab's
    // content.
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      children: [
        _LeaderSection(
          title: 'MVP Race',
          entries: mvpRanking.take(5).toList(),
          playerLookup: playerLookup,
          valueFor: (t) => t.mvpScore.toStringAsFixed(1),
        ),
        for (final category in _categories) ...[
          const SizedBox(height: AppSpacing.lg),
          _LeaderSection(
            title: category.label,
            entries: _topFor(category),
            playerLookup: playerLookup,
            valueFor: (t) => category.format(category.selector(t)),
          ),
        ],
      ],
    );
  }

  List<PlayerSeasonTotals> _topFor(_LeaderCategory category) {
    final eligible =
        leaders.values
            .where((t) => t.gamesPlayed > 0)
            .where((t) => category.eligible?.call(t) ?? true)
            .toList()
          ..sort(
            (a, b) => category.selector(b).compareTo(category.selector(a)),
          );
    return eligible.take(5).toList();
  }
}

class _LeaderSection extends StatelessWidget {
  const _LeaderSection({
    required this.title,
    required this.entries,
    required this.playerLookup,
    required this.valueFor,
  });

  final String title;
  final List<PlayerSeasonTotals> entries;
  final Map<String, _Entry> playerLookup;
  final String Function(PlayerSeasonTotals) valueFor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        if (entries.isEmpty)
          const AppCard(child: Text('Not enough games played yet.'))
        else
          AppCard(
            child: Column(
              children: [
                for (var i = 0; i < entries.length; i++) ...[
                  _LeaderRow(
                    rank: i + 1,
                    totals: entries[i],
                    entry: playerLookup[entries[i].playerId],
                    value: valueFor(entries[i]),
                  ),
                  if (i != entries.length - 1)
                    const Divider(height: AppSpacing.lg),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _LeaderRow extends StatelessWidget {
  const _LeaderRow({
    required this.rank,
    required this.totals,
    required this.entry,
    required this.value,
  });

  final int rank;
  final PlayerSeasonTotals totals;
  final _Entry? entry;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entry = this.entry;
    final jersey = entry?.player.jerseyNumber != null
        ? '#${entry!.player.jerseyNumber} '
        : '';
    final position = entry != null
        ? '${entry.player.primaryPosition.abbreviation} '
        : '';
    final name = entry?.player.name ?? 'Unknown Player';
    final teamLabel = entry != null
        ? '${entry.team.emoji} ${entry.team.name}'
        : '';

    return Row(
      children: [
        SizedBox(
          width: 24,
          child: Text(
            '$rank',
            style: theme.textTheme.titleSmall,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$position$jersey$name', style: theme.textTheme.bodyLarge),
              Text(teamLabel, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _TeamsTab extends StatelessWidget {
  const _TeamsTab({required this.franchise});

  final Franchise franchise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final leagueTeams = allLeagueTeams(franchise);
    final standings = currentStandings(franchise.seasonProgress, leagueTeams);

    if (standings.isEmpty) {
      return const EmptyStateView(
        icon: Icons.bar_chart_outlined,
        message:
            'No regular-season games played yet -- team stats show up '
            'once the season is underway.',
      );
    }

    // Vertical padding only -- see the Leaders tab's own comment on why
    // (`_LeadersTab.build`, above).
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      children: [
        Row(
          children: [
            const Expanded(flex: 3, child: SizedBox.shrink()),
            Expanded(
              child: Text(
                'W-L',
                style: theme.textTheme.labelSmall,
                textAlign: TextAlign.end,
              ),
            ),
            Expanded(
              child: Text(
                'PPG',
                style: theme.textTheme.labelSmall,
                textAlign: TextAlign.end,
              ),
            ),
            Expanded(
              child: Text(
                'OPP',
                style: theme.textTheme.labelSmall,
                textAlign: TextAlign.end,
              ),
            ),
            Expanded(
              child: Text(
                'DIFF',
                style: theme.textTheme.labelSmall,
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          child: Column(
            children: [
              for (var i = 0; i < standings.length; i++) ...[
                _TeamStatsRow(
                  team: teamByAbbreviation(
                    franchise,
                    standings[i].teamAbbreviation,
                  ),
                  entry: standings[i],
                  isUserTeam:
                      standings[i].teamAbbreviation ==
                      franchise.team.abbreviation,
                ),
                if (i != standings.length - 1)
                  const Divider(height: AppSpacing.lg),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TeamStatsRow extends StatelessWidget {
  const _TeamStatsRow({
    required this.team,
    required this.entry,
    required this.isUserTeam,
  });

  final Team team;
  final StandingsEntry entry;
  final bool isUserTeam;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final games = entry.gamesPlayed;
    final ppg = games == 0 ? 0.0 : entry.pointsFor / games;
    final oppPpg = games == 0 ? 0.0 : entry.pointsAgainst / games;
    final diff = ppg - oppPpg;

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Row(
            children: [
              Text(team.emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  team.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: isUserTeam ? FontWeight.bold : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Text(
            '${entry.wins}-${entry.losses}',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.end,
          ),
        ),
        Expanded(
          child: Text(
            ppg.toStringAsFixed(1),
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.end,
          ),
        ),
        Expanded(
          child: Text(
            oppPpg.toStringAsFixed(1),
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.end,
          ),
        ),
        Expanded(
          child: Text(
            '${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(1)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: diff >= 0 ? Colors.green.shade700 : Colors.red.shade700,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

class _RosterTab extends StatefulWidget {
  const _RosterTab({required this.franchise});

  final Franchise franchise;

  @override
  State<_RosterTab> createState() => _RosterTabState();
}

class _RosterTabState extends State<_RosterTab> {
  late String _selectedAbbreviation = widget.franchise.team.abbreviation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final leagueTeams = allLeagueTeams(widget.franchise)
      ..sort((a, b) => a.name.compareTo(b.name));
    final selectedTeam = teamByAbbreviation(
      widget.franchise,
      _selectedAbbreviation,
    );
    final roster = rostersByAbbreviation(
      widget.franchise,
    )[_selectedAbbreviation]!;
    final leaders = computeLeagueLeaders(
      widget.franchise.seasonProgress.playedGames,
    );
    final sortedRoster = [...roster]
      ..sort((a, b) {
        final aPpg = leaders[a.id]?.pointsPerGame ?? 0;
        final bPpg = leaders[b.id]?.pointsPerGame ?? 0;
        return bPpg.compareTo(aPpg);
      });

    // Vertical padding only -- see the Leaders tab's own comment on why
    // (`_LeadersTab.build`, above).
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _selectedAbbreviation,
            decoration: const InputDecoration(
              labelText: 'Team',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              for (final team in leagueTeams)
                DropdownMenuItem(
                  value: team.abbreviation,
                  child: Text('${team.emoji} ${team.name}'),
                ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _selectedAbbreviation = value);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '${selectedTeam.emoji} ${selectedTeam.name}',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: sortedRoster.isEmpty
                ? const Center(child: Text('No active roster.'))
                : ListView(
                    children: [
                      for (var i = 0; i < sortedRoster.length; i++) ...[
                        _RosterStatsRow(
                          player: sortedRoster[i],
                          totals: leaders[sortedRoster[i].id],
                        ),
                        if (i != sortedRoster.length - 1)
                          const Divider(height: AppSpacing.lg),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _RosterStatsRow extends StatelessWidget {
  const _RosterStatsRow({required this.player, required this.totals});

  final Player player;
  final PlayerSeasonTotals? totals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final jersey = player.jerseyNumber != null
        ? '#${player.jerseyNumber} '
        : '';
    final totals = this.totals;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            '${player.primaryPosition.abbreviation} $jersey${player.name}',
            style: theme.textTheme.bodyLarge,
          ),
        ),
        if (totals == null || totals.gamesPlayed == 0)
          Text('No games yet', style: theme.textTheme.bodySmall)
        else
          Text(
            '${_oneDecimal(totals.pointsPerGame)} PPG · '
            '${_oneDecimal(totals.reboundsPerGame)} RPG · '
            '${_oneDecimal(totals.assistsPerGame)} APG',
            style: theme.textTheme.bodySmall,
          ),
      ],
    );
  }
}
