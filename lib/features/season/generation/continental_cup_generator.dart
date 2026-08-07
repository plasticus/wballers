import 'dart:math';

import '../domain/game_result.dart';
import '../domain/played_game.dart';
import '../domain/scheduled_game.dart';
import 'season_schedule_generator.dart';

/// The Continental Cup champion, derived from the Final's (Round 5) result
/// in [playedGames] -- `null` until that single game has actually been
/// played. Unlike [seasonChampion]'s (`postseason_generator.dart`)
/// best-of-N Finals, the Cup Final is just one game, so "played" and
/// "decided" are the same moment -- no partial-series ambiguity to worry
/// about.
String? continentalCupChampion(List<PlayedGame> playedGames) {
  for (final played in playedGames) {
    if (played.game.type == GameType.continentalCup &&
        played.game.continentalCupRound == 5) {
      return played.winningTeamAbbreviation;
    }
  }
  return null;
}

/// How many of Round 1's 10 winners skip Round 2 entirely on a
/// margin-of-victory bye. Round 1 (20 teams) produces 10 winners, but the
/// Quarterfinals (Round 3) need a clean 8 -- 6 byes + the 2 winners of a
/// 2-game Round 2 among the remaining 4 gets there. Round 3 onward is
/// already power-of-two (8 -> 4 -> 2 -> champion), so this bye only ever
/// happens once, at this one junction.
const _round2ByeCount = 6;

/// Continental Cup Round 2: the 4 Round 1 winners with the smallest
/// margins of victory play a random-draw pairing to fill the last 2 of 8
/// Quarterfinal spots; the other 6 (biggest margins) get a bye straight to
/// the Quarterfinals. Returns both the 2 scheduled games and the list of
/// bye teams -- [generateContinentalCupRound3] needs the byes again to
/// know who else is in the Quarterfinal field alongside Round 2's
/// winners.
({List<ScheduledGame> games, List<String> byeTeamAbbreviations})
generateContinentalCupRound2(List<GameResult> round1Results, Random random) {
  assert(
    round1Results.length == 10,
    'Continental Cup Round 1 always produces 10 winners',
  );

  // Sort by margin descending, then abbreviation as a deterministic
  // tiebreaker (margins can tie; sort order must not depend on incoming
  // list order for a given [random] stream to stay reproducible).
  final byMargin = [...round1Results]
    ..sort((a, b) {
      final byMarginDesc = b.winningMargin.compareTo(a.winningMargin);
      if (byMarginDesc != 0) return byMarginDesc;
      return a.winningTeamAbbreviation.compareTo(b.winningTeamAbbreviation);
    });

  final byeTeams = byMargin
      .take(_round2ByeCount)
      .map((r) => r.winningTeamAbbreviation)
      .toList();
  final survivors =
      byMargin
          .skip(_round2ByeCount)
          .map((r) => r.winningTeamAbbreviation)
          .toList()
        ..shuffle(random);

  final games = <ScheduledGame>[
    for (var i = 0; i < survivors.length; i += 2)
      ScheduledGame(
        week: kContinentalCupRound2Week,
        day: kContinentalCupGameDay,
        homeTeamAbbreviation: survivors[i],
        awayTeamAbbreviation: survivors[i + 1],
        type: GameType.continentalCup,
        continentalCupRound: 2,
      ),
  ];
  return (games: games, byeTeamAbbreviations: byeTeams);
}

/// Continental Cup Round 3 (Quarterfinals): the 6 Round 2 byes plus
/// Round 2's 2 winners, randomly paired into 4 games.
List<ScheduledGame> generateContinentalCupRound3(
  List<String> round1ByeTeamAbbreviations,
  List<GameResult> round2Results,
  Random random,
) {
  assert(
    round1ByeTeamAbbreviations.length == _round2ByeCount,
    'expects the 6 byes generateContinentalCupRound2 produced',
  );
  assert(round2Results.length == 2, 'Continental Cup Round 2 is 2 games');

  final field = [
    ...round1ByeTeamAbbreviations,
    for (final result in round2Results) result.winningTeamAbbreviation,
  ]..shuffle(random);

  return [
    for (var i = 0; i < field.length; i += 2)
      ScheduledGame(
        week: kContinentalCupRound3Week,
        day: kContinentalCupGameDay,
        homeTeamAbbreviation: field[i],
        awayTeamAbbreviation: field[i + 1],
        type: GameType.continentalCup,
        continentalCupRound: 3,
      ),
  ];
}

/// Continental Cup Round 4 (Semifinals): the 4 Quarterfinal winners,
/// randomly paired into 2 games.
List<ScheduledGame> generateContinentalCupRound4(
  List<GameResult> round3Results,
  Random random,
) {
  assert(round3Results.length == 4, 'Continental Cup Round 3 is 4 games');

  final field = [
    for (final result in round3Results) result.winningTeamAbbreviation,
  ]..shuffle(random);

  return [
    for (var i = 0; i < field.length; i += 2)
      ScheduledGame(
        week: kContinentalCupRound4Week,
        day: kContinentalCupGameDay,
        homeTeamAbbreviation: field[i],
        awayTeamAbbreviation: field[i + 1],
        type: GameType.continentalCup,
        continentalCupRound: 4,
      ),
  ];
}

/// Continental Cup Round 5 (the Final): the 2 Semifinal winners play a
/// single game for the championship.
List<ScheduledGame> generateContinentalCupRound5(
  List<GameResult> round4Results,
  Random random,
) {
  assert(round4Results.length == 2, 'Continental Cup Round 4 is 2 games');

  final field = [
    for (final result in round4Results) result.winningTeamAbbreviation,
  ]..shuffle(random);

  return [
    ScheduledGame(
      week: kContinentalCupRound5Week,
      day: kContinentalCupGameDay,
      homeTeamAbbreviation: field[0],
      awayTeamAbbreviation: field[1],
      type: GameType.continentalCup,
      continentalCupRound: 5,
    ),
  ];
}
