/// One player's stat line from a single played game, persisted -- unlike
/// `PlayerBoxScore` (`match/domain/player_box_score.dart`), which is
/// derived on demand from a full `MatchResult`'s event log and never
/// stored. `MatchResult` itself is deliberately *not* kept around past the
/// moment a game is simulated (`played_game.dart`'s lean-persistence
/// rationale -- a full event log for every game of a season would bloat
/// the save badly), so this is the compact, id-keyed summary that survives
/// instead: everything a box score display needs, none of the
/// possession-by-possession detail that produced it. Computed once, at
/// play time, via `computeBoxScore` (see `PlayedGame.fromResult`) -- never
/// derived again afterward, so there's nothing to keep in sync if the
/// derivation logic changes.
class PlayedGameStatLine {
  const PlayedGameStatLine({
    required this.minutesPlayed,
    required this.points,
    required this.fieldGoalsMade,
    required this.fieldGoalAttempts,
    required this.threePointersMade,
    required this.threePointAttempts,
    required this.freeThrowsMade,
    required this.freeThrowAttempts,
    required this.offensiveRebounds,
    required this.defensiveRebounds,
    required this.assists,
    required this.steals,
    required this.blocks,
    required this.turnovers,
    required this.personalFouls,
  });

  final double minutesPlayed;
  final int points;
  final int fieldGoalsMade;
  final int fieldGoalAttempts;
  final int threePointersMade;
  final int threePointAttempts;
  final int freeThrowsMade;
  final int freeThrowAttempts;
  final int offensiveRebounds;
  final int defensiveRebounds;
  final int assists;
  final int steals;
  final int blocks;
  final int turnovers;
  final int personalFouls;

  int get totalRebounds => offensiveRebounds + defensiveRebounds;

  double get fieldGoalPercentage =>
      fieldGoalAttempts == 0 ? 0 : fieldGoalsMade / fieldGoalAttempts;

  double get threePointPercentage =>
      threePointAttempts == 0 ? 0 : threePointersMade / threePointAttempts;

  double get freeThrowPercentage =>
      freeThrowAttempts == 0 ? 0 : freeThrowsMade / freeThrowAttempts;
}
