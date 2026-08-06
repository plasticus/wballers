import '../../league/domain/team.dart';
import 'played_game.dart';
import 'season_schedule.dart';
import 'standings_entry.dart';

/// Where a franchise's season currently stands: the full schedule (built
/// once, at franchise creation -- see `generateSeasonSchedule`), every
/// game played so far, and which week comes next.
///
/// Regenerating standings/box scores from [playedGames] on demand (rather
/// than storing them separately) means there's only one source of truth
/// for "what happened" -- no risk of a cached standings table drifting
/// from the actual game log.
class SeasonProgress {
  const SeasonProgress({
    required this.schedule,
    required this.playedGames,
    required this.nextWeek,
  });

  final SeasonSchedule schedule;
  final List<PlayedGame> playedGames;

  /// The next week that hasn't been simulated yet. Starts at
  /// `kPreseasonWeek` for a brand-new franchise.
  final int nextWeek;

  /// Returns a copy with [newlyPlayed] appended to [playedGames] and
  /// [nextWeek] advanced by one.
  SeasonProgress copyWithWeekPlayed(List<PlayedGame> newlyPlayed) {
    return SeasonProgress(
      schedule: schedule,
      playedGames: [...playedGames, ...newlyPlayed],
      nextWeek: nextWeek + 1,
    );
  }
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
