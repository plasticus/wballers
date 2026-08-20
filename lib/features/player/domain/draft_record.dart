/// Where and when a player was drafted -- a direct GM ask (2026-08-19):
/// "After the first season, when you click on a player who was drafted,
/// we should see what season, round, and pick they were drafted." `null`
/// on [Player.draftRecord] means never drafted at all -- an initial
/// expansion-roster/free-agent-pool player, or a player generated
/// standalone (most test fixtures), has no real draft behind them.
class PlayerDraftRecord {
  const PlayerDraftRecord({
    required this.season,
    required this.round,
    required this.pickNumber,
  }) : assert(season >= 0, 'season must not be negative'),
       assert(round >= 1, 'round must be at least 1'),
       assert(pickNumber >= 1, 'pickNumber must be at least 1');

  /// `Franchise.season` this draft's class belonged to -- zero-based,
  /// same "0 for a franchise's first season" convention
  /// `PlayerAchievementRecord.season` already uses.
  final int season;

  final int round;

  /// Overall pick across the whole draft, not reset each round -- same
  /// field `DraftPick.pickNumber` already is.
  final int pickNumber;
}
