/// On-court awards a player can earn (`FLUTTER_APP_PLAN.md`'s Phase 1.5
/// "earned identity" system). [allStarMvp] resolves mid-season
/// (`all_star_advancer.dart`); every other value here resolves once a
/// season ends (`season_awards_advancer.dart`'s `resolveSeasonAwards`,
/// 2026-08-11, `0D_Season_2_Roadmap.md`'s Presentation stage).
enum Achievement {
  leagueMvp,
  scoringLeader,

  /// Real steals+blocks disruption composite, league-wide --
  /// `SeasonAwardsAnswers.md` #1: "Most Defensive Disruptions" was
  /// dropped as a separate award and folded into this one, since
  /// "Disruption" was always just the GM's own internal shorthand for
  /// exactly this composite, never meant to be a second, player-facing
  /// award of its own.
  defensiveMvp,

  /// The first [Achievement] actually wired to a real resolver
  /// (2026-08-10, `all_star_advancer.dart`'s `resolveAllStarGame`) --
  /// every other value here waited on a full season's stats to determine
  /// a winner, which `season_awards_advancer.dart`'s `resolveSeasonAwards`
  /// (2026-08-11, `0D_Season_2_Roadmap.md`'s Presentation stage) now
  /// provides for the rest.
  allStarMvp,

  /// Best #6-by-minutes player across every team's active roster --
  /// `SeasonAwardsAnswers.md` #3.
  sixthManOfTheYear,

  /// Biggest overall-rating gain this season, off `resolveSeasonAwards`'s
  /// own season-start snapshot -- see that function's doc comment for
  /// the "same player would also win Rookie of the Year" overlap rule
  /// (`SeasonAwardsAnswers.md` #6).
  mostImprovedPlayer,

  /// Best season composite among every player with 0 years of
  /// professional service -- `SeasonAwardsAnswers.md` #6, which also
  /// locks in that this always wins the tiebreak over
  /// [mostImprovedPlayer] when both would otherwise point at the same
  /// player.
  rookieOfTheYear,
}

extension AchievementLabel on Achievement {
  String get label => switch (this) {
    Achievement.leagueMvp => 'League MVP',
    Achievement.scoringLeader => 'Scoring Leader',
    Achievement.defensiveMvp => 'Defensive MVP',
    Achievement.allStarMvp => 'All-Star Game MVP',
    Achievement.sixthManOfTheYear => 'Sixth Player of the Year',
    Achievement.mostImprovedPlayer => 'Most Improved Player',
    Achievement.rookieOfTheYear => 'Rookie of the Year',
  };
}

/// One award a player earned in a given season.
///
/// [season] is a plain zero-based counter, matching `Franchise.season`'s
/// own convention -- the same value that was current when the award was
/// granted, not re-derived later.
class PlayerAchievementRecord {
  const PlayerAchievementRecord({
    required this.achievement,
    required this.season,
  }) : assert(season >= 0, 'season must not be negative');

  final Achievement achievement;
  final int season;
}
