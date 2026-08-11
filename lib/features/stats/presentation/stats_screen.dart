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
import '../../player/presentation/player_detail_screen.dart';
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
/// Every player row across all 3 tabs opens `PlayerDetailScreen` on tap
/// (2026-08-11, TODO.md: a direct GM ask -- "click on any player, from
/// any team"), own roster or not -- that screen learned to look a player
/// up anywhere in the league the same day (`_resolvePlayer`, its own doc
/// comment), which is what unblocked this.
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
              _LeadersTab(
                franchise: widget.franchise,
                playerLookup: playerLookup,
                leaders: leaders,
              ),
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
  const _LeadersTab({
    required this.franchise,
    required this.playerLookup,
    required this.leaders,
  });

  final Franchise franchise;
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
          franchise: franchise,
          title: 'MVP Race',
          entries: mvpRanking.take(5).toList(),
          playerLookup: playerLookup,
          valueFor: (t) => t.mvpScore.toStringAsFixed(1),
        ),
        for (final category in _categories) ...[
          const SizedBox(height: AppSpacing.lg),
          _LeaderSection(
            franchise: franchise,
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
    required this.franchise,
    required this.title,
    required this.entries,
    required this.playerLookup,
    required this.valueFor,
  });

  final Franchise franchise;
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
                    franchise: franchise,
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
    required this.franchise,
    required this.rank,
    required this.totals,
    required this.entry,
    required this.value,
  });

  final Franchise franchise;
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

    final row = Row(
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
    // Unknown-player rows (shouldn't happen, `entry`'s own doc comment)
    // have no id worth navigating to -- left untappable rather than
    // opening a "Player Not Found" screen.
    if (entry == null) return row;
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlayerDetailScreen(
            franchise: franchise,
            playerId: entry.player.id,
          ),
        ),
      ),
      child: row,
    );
  }
}

/// The Teams tab's stat table, rebuilt 2026-08-10 as a real [Table] rather
/// than a header [Row] floating above a separately-padded [AppCard] of
/// data [Row]s -- a direct GM bug report, with a screenshot: the two
/// never actually lined up (the header only ever sat inside `AppShell`'s
/// own outer padding, while each data row sat inside *that plus*
/// [AppCard]'s own generous `EdgeInsets.all(AppSpacing.lg)`), and every
/// stat column was an equal-flex [Expanded] with no gap between them, so
/// adjacent numbers ran together edge to edge ("4-1" against "115.0"
/// against "102.8", "DIFF" wrapping onto its own second line) the moment
/// a value's digit count varied at all.
///
/// A single [Table] puts the header and every data row through the exact
/// same column geometry by construction -- no separate alignment to keep
/// in sync. [IntrinsicColumnWidth] sizes each stat column to its own
/// widest cell (header label or any row's value, at whatever the coach's
/// text-scale setting currently renders it at -- `app_preferences.dart`),
/// so a column can never collide with its neighbor or wrap, the GM's own
/// stated priority ("giving enough room to the numbers... readability")
/// ahead of the team-name column, which gets whatever's left
/// ([FlexColumnWidth]) and ellipsizes rather than force-wrapping.
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
        Card(
          child: Padding(
            // Deliberately tighter than AppCard's own AppSpacing.lg on
            // every side -- the GM's own stated first priority ("less
            // padding on the outsides") -- a dense stat table needs its
            // width for numbers, not card margin.
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            // At a large text-scale setting, the 4 intrinsic stat
            // columns can legitimately need more width than the screen
            // has, even after the name column (FittedBox above) has
            // shrunk to nothing -- verified against a throwaway 1.8x
            // capture, DIFF was landing past the visible edge with no
            // way to reach it. LayoutBuilder + a horizontal
            // SingleChildScrollView means the table only ever grows
            // past the viewport instead of clipping: minWidth pins it
            // to exactly fill the screen (today's normal case, no
            // scrolling needed), but nothing stops it growing wider if
            // the coach's text setting demands it -- the numbers stay
            // fully visible and reachable by a sideways swipe instead
            // of silently disappearing off-screen.
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: Table(
                    columnWidths: const {
                      0: FlexColumnWidth(),
                      1: IntrinsicColumnWidth(),
                      2: IntrinsicColumnWidth(),
                      3: IntrinsicColumnWidth(),
                      4: IntrinsicColumnWidth(),
                    },
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    border: TableBorder(
                      horizontalInside: BorderSide(color: theme.dividerColor),
                    ),
                    children: [
                      TableRow(
                        children: [
                          const SizedBox.shrink(),
                          _StatHeaderCell('W-L'),
                          _StatHeaderCell('PPG'),
                          _StatHeaderCell('OPP'),
                          _StatHeaderCell('DIFF'),
                        ],
                      ),
                      for (final entry in standings)
                        _teamStatsRow(
                          context,
                          team: teamByAbbreviation(
                            franchise,
                            entry.teamAbbreviation,
                          ),
                          entry: entry,
                          isUserTeam:
                              entry.teamAbbreviation ==
                              franchise.team.abbreviation,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  TableRow _teamStatsRow(
    BuildContext context, {
    required Team team,
    required StandingsEntry entry,
    required bool isUserTeam,
  }) {
    final theme = Theme.of(context);
    final games = entry.gamesPlayed;
    final ppg = games == 0 ? 0.0 : entry.pointsFor / games;
    final oppPpg = games == 0 ? 0.0 : entry.pointsAgainst / games;
    final diff = ppg - oppPpg;

    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          // FittedBox, not just Flexible+ellipsis: the 4 intrinsic stat
          // columns are given first claim on the row's width (the GM's
          // own stated priority), which at a large text-scale setting
          // can squeeze this column down further than even the team
          // emoji alone needs -- a plain Row would hard-overflow there
          // (a real crash-adjacent RenderFlex error, verified against a
          // throwaway 1.3x-scale capture). FittedBox instead shrinks the
          // whole emoji+name group to whatever width is actually left,
          // which degrades all the way down to a tiny illegible sliver
          // before it would ever overflow -- ugly at the extreme end,
          // but never broken, and numbers (the stated priority) are
          // completely unaffected either way.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(team.emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  team.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: isUserTeam ? FontWeight.bold : null,
                  ),
                ),
              ],
            ),
          ),
        ),
        _StatDataCell(
          '${entry.wins}-${entry.losses}',
          style: theme.textTheme.bodyMedium,
        ),
        _StatDataCell(
          ppg.toStringAsFixed(1),
          style: theme.textTheme.bodyMedium,
        ),
        _StatDataCell(
          oppPpg.toStringAsFixed(1),
          style: theme.textTheme.bodyMedium,
        ),
        _StatDataCell(
          '${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(1)}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: diff >= 0 ? Colors.green.shade700 : Colors.red.shade700,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

/// A stat column's header label -- right-aligned and padded away from its
/// left neighbor, same shape every [_StatDataCell] below it uses, so a
/// column's width (sized off the widest of the two) never leaves the
/// label and its own data misaligned.
class _StatHeaderCell extends StatelessWidget {
  const _StatHeaderCell(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.sm),
      child: Text(
        label,
        style: theme.textTheme.labelSmall,
        textAlign: TextAlign.right,
      ),
    );
  }
}

class _StatDataCell extends StatelessWidget {
  const _StatDataCell(this.value, {this.style});

  final String value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.sm),
      child: Text(value, style: style, textAlign: TextAlign.right),
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
                          franchise: widget.franchise,
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
  const _RosterStatsRow({
    required this.franchise,
    required this.player,
    required this.totals,
  });

  final Franchise franchise;
  final Player player;
  final PlayerSeasonTotals? totals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final jersey = player.jerseyNumber != null
        ? '#${player.jerseyNumber} '
        : '';
    final totals = this.totals;

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              PlayerDetailScreen(franchise: franchise, playerId: player.id),
        ),
      ),
      child: Row(
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
      ),
    );
  }
}
