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
