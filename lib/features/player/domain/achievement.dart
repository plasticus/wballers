/// On-court awards a player can earn (`FLUTTER_APP_PLAN.md`'s Phase 1.5
/// "earned identity" system). Determining a winner needs a full season of
/// tracked stats -- league MVP, a scoring leaderboard, etc. -- which
/// doesn't exist until Phase 2's season simulation is built. The data
/// model, nickname suggestions, and unlock rules live here now (same
/// reasoning as `CoachStats` and most of `Trait`: define the shape before
/// the consuming system exists) so Phase 2 only has to call
/// `grantAchievement`, not design a new system on top of a season sim.
enum Achievement {
  leagueMvp,
  scoringLeader,
  defensiveMvp,
  mostDefensiveDisruptions,
}

extension AchievementLabel on Achievement {
  String get label => switch (this) {
    Achievement.leagueMvp => 'League MVP',
    Achievement.scoringLeader => 'Scoring Leader',
    Achievement.defensiveMvp => 'Defensive MVP',
    Achievement.mostDefensiveDisruptions => 'Most Defensive Disruptions',
  };
}

/// One award a player earned in a given season.
///
/// [season] is a plain zero-based counter -- Phase 2 doesn't have a real
/// season concept yet either (`Franchise` has no season/year field), so
/// this is forward-looking data with nothing wired to it, not a reference
/// into an existing season record.
class PlayerAchievementRecord {
  const PlayerAchievementRecord({
    required this.achievement,
    required this.season,
  }) : assert(season >= 0, 'season must not be negative');

  final Achievement achievement;
  final int season;
}
