import 'game_day.dart';

/// Which part of the season calendar a game belongs to
/// (`0B_Planned.md`'s season calendar table). Only [regularSeason] games
/// count toward standings.
enum GameType { preseason, regularSeason, continentalCup, postseason }

/// One game on the calendar: two teams (by `Team.abbreviation`), a week
/// number (1-24, `0B_Planned.md`'s season calendar), a [GameDay] within
/// that week, and what kind of game it is. No score/result yet -- that's
/// the not-yet-built deterministic simulator's job (`0B_Planned.md`).
///
/// [week] + [day] together are a game's chronological position -- see
/// `season_progress.dart`'s `gameDaysInOrder`, which is what "advance to
/// the next game day" actually iterates over.
class ScheduledGame {
  const ScheduledGame({
    required this.week,
    required this.day,
    required this.homeTeamAbbreviation,
    required this.awayTeamAbbreviation,
    required this.type,
    this.continentalCupRound,
    this.postseasonRound,
  }) : assert(
         homeTeamAbbreviation != awayTeamAbbreviation,
         'a team cannot play itself',
       ),
       assert(
         (type == GameType.continentalCup) == (continentalCupRound != null),
         'continentalCupRound must be set if and only if type is '
         'continentalCup',
       ),
       assert(
         (type == GameType.postseason) == (postseasonRound != null),
         'postseasonRound must be set if and only if type is postseason',
       );

  final int week;
  final GameDay day;
  final String homeTeamAbbreviation;
  final String awayTeamAbbreviation;
  final GameType type;

  /// 1 (Round 1) through 5 (the Championship) -- only set for
  /// [GameType.continentalCup] games.
  final int? continentalCupRound;

  /// 1 (First Round, best-of-3) through 3 (Finals, best-of-7) -- only set
  /// for [GameType.postseason] games. See `postseason_generator.dart`.
  final int? postseasonRound;
}
