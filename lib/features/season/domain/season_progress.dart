import '../../league/domain/team.dart';
import 'game_day.dart';
import 'played_game.dart';
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
