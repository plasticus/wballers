import '../../league/domain/team.dart';
import 'game_day.dart';
import 'played_game.dart';
import 'scheduled_game.dart';
import 'season_schedule.dart';
import 'standings_entry.dart';

/// Where a franchise's season currently stands: the full schedule (built
/// once, at franchise creation -- see `generateSeasonSchedule`), every
/// game played so far, and which game day comes next.
///
/// Regenerating standings/box scores from [playedGames] on demand (rather
/// than storing them separately) means there's only one source of truth
/// for "what happened" -- no risk of a cached standings table drifting
/// from the actual game log.
class SeasonProgress {
  const SeasonProgress({
    required this.schedule,
    required this.playedGames,
    required this.nextGameDayIndex,
  });

  final SeasonSchedule schedule;
  final List<PlayedGame> playedGames;

  /// Index into [gameDaysInOrder] of `schedule` -- the next (week, day)
  /// with at least one scheduled game that hasn't been simulated yet.
  /// Starts at 0 for a brand-new franchise. Advancing games one real
  /// calendar day at a time (rather than a whole week, which can hold 2+
  /// game days) is what `season_advancer.dart`'s `advanceToNextGameDay`
  /// is for -- see that file for why: with only 2-3 games scheduled a
  /// week, a week-at-a-time "Advance Week" action would blow past
  /// individual games the GM wants to actually play through.
  final int nextGameDayIndex;

  /// True once every game day in [schedule] has been played.
  bool get isComplete => nextGameDayIndex >= gameDaysInOrder(schedule).length;

  /// Returns a copy with [newlyPlayed] appended to [playedGames] and
  /// [nextGameDayIndex] advanced by one. [updatedSchedule], if given,
  /// replaces [schedule] wholesale -- how `season_advancer.dart` folds a
  /// newly-generated Continental Cup round back in the moment the round
  /// before it finishes.
  SeasonProgress copyWithGameDayPlayed(
    List<PlayedGame> newlyPlayed, {
    SeasonSchedule? updatedSchedule,
  }) {
    return SeasonProgress(
      schedule: updatedSchedule ?? schedule,
      playedGames: [...playedGames, ...newlyPlayed],
      nextGameDayIndex: nextGameDayIndex + 1,
    );
  }
}

/// Every distinct (week, day) combination in [schedule] with at least one
/// scheduled game, in chronological order. This -- not the raw list of
/// weeks -- is what "advance to the next game day" iterates over: a bye
/// week (or a week/day combination nothing is scheduled on) simply never
/// appears, so every advance always has something to simulate until the
/// season's actually done.
List<(int week, GameDay day)> gameDaysInOrder(SeasonSchedule schedule) {
  final distinctDays = {
    for (final game in schedule.games) (game.week, game.day),
  }.toList();
  distinctDays.sort((a, b) {
    final byWeek = a.$1.compareTo(b.$1);
    if (byWeek != 0) return byWeek;
    return a.$2.index.compareTo(b.$2.index);
  });
  return distinctDays;
}

/// The highest schedule week for which *every* one of that week's game
/// days has already been played -- i.e. the most recent week that's
/// fully wrapped up. `null` if no week is fully done yet (including
/// "nothing's been played at all"). `features/training/`'s weekly
/// resolution is gated on this: a week only becomes eligible for
/// training once every game day in it (a regular season week can have
/// up to 2) has actually happened, not just the first of them.
///
/// Because [gameDaysInOrder] is already globally sorted by week then day,
/// and [SeasonProgress.nextGameDayIndex] is a monotonic pointer into it,
/// this reduces to one check: the most recently played game day's week is
/// complete exactly when the *next* unplayed game day (if any) belongs to
/// a later week.
int? lastFullyCompletedWeek(SeasonProgress progress) {
  if (progress.nextGameDayIndex == 0) return null;
  final gameDays = gameDaysInOrder(progress.schedule);
  final lastPlayedWeek = gameDays[progress.nextGameDayIndex - 1].$1;
  final nextUnplayedWeek = progress.nextGameDayIndex < gameDays.length
      ? gameDays[progress.nextGameDayIndex].$1
      : null;
  if (nextUnplayedWeek == lastPlayedWeek) return null; // still mid-week
  return lastPlayedWeek;
}

/// The standings table so far this season, derived fresh from
/// [SeasonProgress.playedGames] every time it's asked for -- see the class
/// doc comment on why this isn't cached anywhere.
List<StandingsEntry> currentStandings(
  SeasonProgress progress,
  List<Team> leagueTeams,
) {
  return computeStandings([
    for (final played in progress.playedGames) played.toGameResult(),
  ], leagueTeams: leagueTeams);
}

/// Which [GameType]s have at least one game scheduled on [progress]'s
/// very next game day -- unlike [nextOwnGame], this doesn't care whether
/// the GM's own team is playing that day at all, since a Continental Cup
/// round still simulates for the rest of the league even after the GM's
/// own team is out (2026-08-10, TODO.md item 12: the Dashboard's Season
/// card needs to know "is this a Cup day" independent of "is it *my* Cup
/// game"). Empty once the season's fully played out.
Set<GameType> nextGameDayTypes(SeasonProgress progress) {
  final gameDays = gameDaysInOrder(progress.schedule);
  if (progress.nextGameDayIndex >= gameDays.length) return {};
  final (week, day) = gameDays[progress.nextGameDayIndex];
  return {
    for (final game in progress.schedule.games)
      if (game.week == week && game.day == day) game.type,
  };
}

/// [teamAbbreviation]'s game on [progress]'s very next game day, if they
/// have one -- `null` on a bye day (the next game day has games scheduled,
/// just none involving this team). `null` too once the season's fully
/// played out ([SeasonProgress.isComplete]). What a "preview this game
/// before it simulates" flow (`MatchPreviewScreen`) needs to know before
/// deciding whether there's anything to preview at all, ahead of calling
/// `advanceToNextGameDay`.
ScheduledGame? nextOwnGame(SeasonProgress progress, String teamAbbreviation) {
  final gameDays = gameDaysInOrder(progress.schedule);
  if (progress.nextGameDayIndex >= gameDays.length) return null;
  final (week, day) = gameDays[progress.nextGameDayIndex];
  for (final game in progress.schedule.games) {
    if (game.week == week &&
        game.day == day &&
        (game.homeTeamAbbreviation == teamAbbreviation ||
            game.awayTeamAbbreviation == teamAbbreviation)) {
      return game;
    }
  }
  return null;
}

/// The next [limit] games on [teamAbbreviation]'s calendar that haven't
/// been played yet, in chronological order -- what a GM-facing "Upcoming
/// Games" list shows (the Dashboard's Season card). Matches a played
/// result back to its fixture by (week, day, home, away) rather than
/// object identity, since a reloaded save deserializes fresh
/// `ScheduledGame` instances -- a team plays at most one game per game
/// day, so that tuple is a unique key without needing type/round in it.
List<ScheduledGame> upcomingGamesFor(
  SeasonProgress progress,
  String teamAbbreviation, {
  int limit = 3,
}) {
  final playedFixtures = {
    for (final played in progress.playedGames) _fixtureKey(played.game),
  };
  final ownGames =
      progress.schedule.games
          .where(
            (game) =>
                game.homeTeamAbbreviation == teamAbbreviation ||
                game.awayTeamAbbreviation == teamAbbreviation,
          )
          .where((game) => !playedFixtures.contains(_fixtureKey(game)))
          .toList()
        ..sort(_byWeekThenDay);
  return ownGames.take(limit).toList();
}

/// The result of [teamAbbreviation]'s last [limit] played games, oldest
/// first -- what the "Matchup Analysis" screen's form-streak dots read
/// left to right. `true` = a win. Any [GameType] counts (unlike
/// [currentStandings], which only tallies regular-season results toward
/// the official record) -- this is about recent form, so a Continental
/// Cup or postseason result belongs in it too. Shorter than [limit] early
/// in a season, once [teamAbbreviation] has played fewer games than that
/// so far.
List<bool> recentResultsFor(
  SeasonProgress progress,
  String teamAbbreviation, {
  int limit = 5,
}) {
  final ownGames =
      progress.playedGames
          .where(
            (played) =>
                played.game.homeTeamAbbreviation == teamAbbreviation ||
                played.game.awayTeamAbbreviation == teamAbbreviation,
          )
          .toList()
        ..sort((a, b) => _byWeekThenDay(b.game, a.game)); // most recent first
  return [
    for (final played in ownGames.take(limit).toList().reversed)
      played.toGameResult().winningTeamAbbreviation == teamAbbreviation,
  ];
}

typedef _FixtureKey = (int week, GameDay day, String home, String away);

_FixtureKey _fixtureKey(ScheduledGame game) =>
    (game.week, game.day, game.homeTeamAbbreviation, game.awayTeamAbbreviation);

int _byWeekThenDay(ScheduledGame a, ScheduledGame b) {
  final byWeek = a.week.compareTo(b.week);
  if (byWeek != 0) return byWeek;
  return a.day.index.compareTo(b.day.index);
}
