import 'scheduled_game.dart';

/// The full slate of games generated for one season -- see
/// `generateSeasonSchedule`. Only what can be determined ahead of time is
/// included at franchise creation: the preseason, the full regular season,
/// and the Continental Cup's Round 1 (a straight random draw, per
/// `0B_Planned.md`). Continental Cup Rounds 2-5 depend on earlier rounds'
/// actual results, so they don't exist yet at creation time -- `season_advancer.dart`
/// appends each one to [games] the moment the round before it finishes.
class SeasonSchedule {
  const SeasonSchedule({required this.games, this.continentalCupRound1Byes});

  final List<ScheduledGame> games;

  /// The 6 teams Round 1's biggest margins-of-victory sent straight to
  /// the Quarterfinals, bypassing Round 2 entirely (`generateContinentalCupRound2`'s
  /// doc comment explains why). `null` until Round 2 has actually been
  /// generated (i.e. Round 1 is complete) -- `generateContinentalCupRound3`
  /// needs this list again once Round 2 finishes, since Round 2's own
  /// results don't mention the teams that skipped it.
  final List<String>? continentalCupRound1Byes;

  /// Returns a copy with [newGames] appended to [games], and
  /// [continentalCupRound1Byes] set if given (once set, it's never
  /// cleared -- there's nothing to reset it to).
  SeasonSchedule copyWithAppendedGames(
    List<ScheduledGame> newGames, {
    List<String>? continentalCupRound1Byes,
  }) {
    return SeasonSchedule(
      games: [...games, ...newGames],
      continentalCupRound1Byes:
          continentalCupRound1Byes ?? this.continentalCupRound1Byes,
    );
  }
}
