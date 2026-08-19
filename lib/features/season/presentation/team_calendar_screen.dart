import 'package:flutter/material.dart';

import '../../../app/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../franchise/domain/franchise.dart';
import '../../trade/domain/trade_window.dart' show kTradeDeadlineWeek;
import '../application/franchise_rosters.dart';
import '../domain/game_day.dart';
import '../domain/played_game.dart';
import '../domain/scheduled_game.dart';
import '../domain/season_progress.dart';
import '../generation/continental_cup_generator.dart'
    show continentalCupEliminationRound;
import '../generation/season_schedule_generator.dart'
    show
        kContinentalCupRound1Week,
        kContinentalCupRound2Week,
        kContinentalCupRound3Week,
        kContinentalCupRound4Week,
        kContinentalCupRound5Week,
        kPostseasonFinalsWeek,
        kPostseasonFirstRoundWeek,
        kPostseasonSemifinalsWeek,
        kRegularSeasonEndWeek,
        weekLabel;

/// Every date that matters to the GM's own club, in one place -- games,
/// bye days (and *why*, when it's a Cup elimination rather than just the
/// schedule packer's own unevenness), the end of the regular season,
/// postseason rounds, the trade deadline, and the draft -- a direct GM
/// ask (2026-08-15): "a Calendar available from my Team page... Games,
/// Bye weeks... end of regular season date, draft date, everything
/// relevant to my team."
///
/// Unlike [ScheduleScreen] (which only ever lists real [ScheduledGame]s),
/// this fills in the gaps a schedule-only view leaves: a day the league
/// plays but this team doesn't shows up explicitly as a bye rather than
/// just being absent from the list, and season-phase milestones that
/// aren't games at all (regular season end, postseason rounds, the
/// draft) get their own rows too.
class TeamCalendarScreen extends StatelessWidget {
  const TeamCalendarScreen({required this.franchise, super.key});

  final Franchise franchise;

  @override
  Widget build(BuildContext context) {
    final rows = _buildCalendarRows(franchise);
    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      body: SafeArea(
        child: rows.isEmpty
            ? const Center(child: Text('Nothing scheduled yet.'))
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: rows.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) =>
                    _rowWidget(context, franchise: franchise, row: rows[index]),
              ),
      ),
    );
  }

  Widget _rowWidget(
    BuildContext context, {
    required Franchise franchise,
    required _CalendarRow row,
  }) {
    return switch (row) {
      _GameRow() => _GameCalendarRow(franchise: franchise, row: row),
      _ByeRow() => _ByeCalendarRow(row: row),
      _MilestoneRow() => _MilestoneCalendarRow(row: row),
    };
  }
}

typedef _FixtureKey = (int week, GameDay day, String home, String away);

_FixtureKey _fixtureKey(ScheduledGame game) =>
    (game.week, game.day, game.homeTeamAbbreviation, game.awayTeamAbbreviation);

/// Same "the 2 All-Star placeholder entries show up on every team's own
/// calendar" reasoning [ScheduleScreen] already established -- neither
/// abbreviation is a real team, but the whole league sits out its normal
/// games that week, so it belongs on this club's own calendar too.
bool _isAllStarPlaceholderGame(ScheduledGame game) =>
    game.type == GameType.allStarGame ||
    game.type == GameType.skillsCompetition;

/// Which Continental Cup round a bye week's [week] corresponds to, for
/// the elimination note -- Round 1 is included even though every team
/// always has a game that week (never actually a bye) for completeness.
const _cupRoundByWeek = {
  kContinentalCupRound1Week: 1,
  kContinentalCupRound2Week: 2,
  kContinentalCupRound3Week: 3,
  kContinentalCupRound4Week: 4,
  kContinentalCupRound5Week: 5,
};

sealed class _CalendarRow {
  const _CalendarRow({required this.week, required this.day});

  final int week;

  /// `null` for a milestone that isn't pinned to one real calendar day.
  final GameDay? day;
}

class _GameRow extends _CalendarRow {
  const _GameRow({
    required super.week,
    required super.day,
    required this.game,
    required this.played,
  });

  final ScheduledGame game;
  final PlayedGame? played;
}

class _ByeRow extends _CalendarRow {
  const _ByeRow({required super.week, required super.day, this.note});

  final String? note;
}

class _MilestoneRow extends _CalendarRow {
  const _MilestoneRow({required super.week, required this.title, this.subtitle})
    : super(day: null);

  final String title;
  final String? subtitle;
}

/// Builds the full, chronologically-sorted calendar -- see the class doc
/// comment on [TeamCalendarScreen] for what each row type covers.
List<_CalendarRow> _buildCalendarRows(Franchise franchise) {
  final teamAbbreviation = franchise.team.abbreviation;
  final progress = franchise.seasonProgress;
  final schedule = progress.schedule;
  final playedByFixture = {
    for (final played in progress.playedGames) _fixtureKey(played.game): played,
  };

  final ownGames = [
    for (final game in schedule.games)
      if (game.homeTeamAbbreviation == teamAbbreviation ||
          game.awayTeamAbbreviation == teamAbbreviation ||
          _isAllStarPlaceholderGame(game))
        game,
  ];
  final ownGameDays = {for (final game in ownGames) (game.week, game.day)};

  final rows = <_CalendarRow>[
    for (final game in ownGames)
      _GameRow(
        week: game.week,
        day: game.day,
        game: game,
        played: playedByFixture[_fixtureKey(game)],
      ),
  ];

  // Bye days: every game day the league played that this team didn't --
  // real, by-design gaps (the schedule packer doesn't guarantee a game
  // every day, and a Cup elimination round only includes survivors), not
  // a bug -- but a GM report (2026-08-15) called out how confusing an
  // unexplained one reads: "I need to know why."
  final cupEliminationRound = continentalCupEliminationRound(
    progress.playedGames,
    teamAbbreviation,
  );
  for (final (week, day) in gameDaysInOrder(schedule)) {
    if (ownGameDays.contains((week, day))) continue;
    final cupRound = _cupRoundByWeek[week];
    final note = cupRound != null && cupEliminationRound != null
        ? "Continental Cup ${continentalCupRoundName(cupRound)} -- you're "
              'out (eliminated in '
              '${continentalCupRoundName(cupEliminationRound)})'
        : null;
    rows.add(_ByeRow(week: week, day: day, note: note));
  }

  // Regular season end -- a real milestone, not a game of its own.
  rows.add(
    _MilestoneRow(week: kRegularSeasonEndWeek, title: 'Regular Season Ends'),
  );

  // Trade Deadline -- locked to the end of Week kTradeDeadlineWeek
  // (2026-08-19, a direct GM call), sorted (via the `week`/`day: null`
  // tie-break below) to the very end of that week's own rows, right
  // before Week [kTradeDeadlineWeek + 1] begins.
  rows.add(
    const _MilestoneRow(
      week: kTradeDeadlineWeek,
      title: 'Trade Deadline',
      subtitle: 'Trades close once Week ${kTradeDeadlineWeek + 1} begins',
    ),
  );

  // Postseason rounds aren't pre-scheduled (`postseason_generator.dart`'s
  // own doc comment -- a series' game count isn't known ahead of time),
  // so before it's actually played this is a generic marker; once real
  // games exist for a round, those already showed up above as [_GameRow]s
  // via `ownGames`... except postseason games are never appended to
  // `schedule.games` at all (simulated straight to `playedGames`), so
  // they need their own pass here instead of coming along for free.
  const postseasonRounds = [
    (1, kPostseasonFirstRoundWeek, 'First Round'),
    (2, kPostseasonSemifinalsWeek, 'Semifinals'),
    (3, kPostseasonFinalsWeek, 'Finals'),
  ];
  for (final (round, week, name) in postseasonRounds) {
    final ownRoundGames = [
      for (final played in progress.playedGames)
        if (played.game.type == GameType.postseason &&
            played.game.postseasonRound == round &&
            (played.game.homeTeamAbbreviation == teamAbbreviation ||
                played.game.awayTeamAbbreviation == teamAbbreviation))
          played,
    ];
    if (ownRoundGames.isEmpty) {
      rows.add(
        _MilestoneRow(
          week: week,
          title: 'Postseason: $name',
          subtitle: 'If your club qualifies',
        ),
      );
    } else {
      for (final played in ownRoundGames) {
        rows.add(
          _GameRow(
            week: played.game.week,
            day: played.game.day,
            game: played.game,
            played: played,
          ),
        );
      }
    }
  }

  // The draft has no calendar week of its own -- it's triggered the
  // moment the postseason bracket resolves, not scheduled ahead of time
  // (`season_transition_advancer.dart`), so this can only ever say "after
  // the season," not a specific date.
  rows.add(
    const _MilestoneRow(
      week: kPostseasonFinalsWeek + 1,
      title: 'Draft',
      subtitle: 'Once the postseason wraps up',
    ),
  );

  rows.sort((a, b) {
    final byWeek = a.week.compareTo(b.week);
    if (byWeek != 0) return byWeek;
    return (a.day?.index ?? 99).compareTo(b.day?.index ?? 99);
  });
  return rows;
}

/// The 3-line date column every real-day row (games and byes) leads
/// with: the full fictional date, the abbreviated weekday, and the game
/// week number -- same shape `ScheduleScreen`'s own date column uses, for
/// a consistent look between the two. All-Star placeholder rows omit the
/// weekday line -- neither of its 2 placeholder [GameDay] values is a
/// real weekday worth showing (`all_star_generator.dart`'s own doc
/// comment on `kSkillsCompetitionDay`/`kAllStarGameDay`).
class _CalendarDateColumn extends StatelessWidget {
  const _CalendarDateColumn({
    required this.week,
    required this.day,
    this.showWeekday = true,
  });

  final int week;
  final GameDay day;
  final bool showWeekday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 72,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatFictionalDate(week, day),
            style: theme.textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (showWeekday)
            Text(
              day.shortLabel,
              style: theme.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          Text(
            weekLabel(week),
            style: theme.textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// A milestone row's own date column -- just the week label, since it
/// isn't pinned to a real calendar day the way a game or bye is.
class _MilestoneDateColumn extends StatelessWidget {
  const _MilestoneDateColumn({required this.week});

  final int week;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 72,
      child: Text(
        weekLabel(week),
        style: theme.textTheme.bodySmall,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

const _kAllStarMatchupLabel = 'Atlantic vs. Pacific All-Stars';

class _GameCalendarRow extends StatelessWidget {
  const _GameCalendarRow({required this.franchise, required this.row});

  final Franchise franchise;
  final _GameRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final game = row.game;
    final played = row.played;
    final isAllStar = _isAllStarPlaceholderGame(game);
    final isHome = game.homeTeamAbbreviation == franchise.team.abbreviation;

    Widget matchup;
    if (isAllStar) {
      matchup = Text(_kAllStarMatchupLabel, style: theme.textTheme.bodyMedium);
    } else {
      final opponentAbbreviation = isHome
          ? game.awayTeamAbbreviation
          : game.homeTeamAbbreviation;
      final opponent = teamByAbbreviation(franchise, opponentAbbreviation);
      matchup = Text(
        '${isHome ? 'vs' : 'at'} ${opponent.emoji} ${opponent.name}',
        style: theme.textTheme.bodyMedium,
      );
    }

    Widget status;
    if (isAllStar) {
      status = Text(
        played == null ? 'Upcoming' : 'Played',
        style: theme.textTheme.bodySmall,
      );
    } else if (played == null) {
      status = Text('Upcoming', style: theme.textTheme.bodySmall);
    } else {
      final ownScore = isHome ? played.homeScore : played.awayScore;
      final opponentScore = isHome ? played.awayScore : played.homeScore;
      final won = ownScore > opponentScore;
      status = Text(
        '${won ? 'W' : 'L'} $ownScore-$opponentScore',
        style: theme.textTheme.titleSmall?.copyWith(
          color: won ? Colors.green.shade700 : Colors.red.shade700,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    return AppCard(
      child: Row(
        children: [
          _CalendarDateColumn(
            week: game.week,
            day: game.day,
            showWeekday: !isAllStar,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                matchup,
                Text(game.typeLabel, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          status,
        ],
      ),
    );
  }
}

class _ByeCalendarRow extends StatelessWidget {
  const _ByeCalendarRow({required this.row});

  final _ByeRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Always non-null in practice -- `_buildCalendarRows` only ever
          // constructs a `_ByeRow` from a real `gameDaysInOrder` entry.
          _CalendarDateColumn(week: row.week, day: row.day!),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bye',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (row.note != null)
                  Text(row.note!, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MilestoneCalendarRow extends StatelessWidget {
  const _MilestoneCalendarRow({required this.row});

  final _MilestoneRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Row(
        children: [
          _MilestoneDateColumn(week: row.week),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (row.subtitle != null)
                  Text(row.subtitle!, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
