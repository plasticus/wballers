import '../../player/domain/player.dart';

/// The star-rating bucket a player's overall falls into, per
/// `star_system.md`. This is a roster-legality concept, not a player
/// attribute — see the deferred-fields note on [Player].
///
/// Revised 2026-08-10 (GM decision, `season2roadmap.md` answer 1, closing
/// the judgment call `TODO.md`'s star-quality-indicator item had been
/// waiting on): the top tier is now 4-star, not 5-star — every band
/// shifted down one rather than adding a real 5th tier. [noStars] is new
/// too; the old system only ever named its top two tiers and lumped
/// everything else into one undefined "3-star & below" bucket.
enum StarTier {
  fourStar,
  threeStar,
  twoStar,
  oneStar,
  noStars;

  static StarTier of(Player player) {
    final overall = player.ratings.overall;
    if (overall >= 90) return StarTier.fourStar;
    if (overall >= 80) return StarTier.threeStar;
    if (overall >= 70) return StarTier.twoStar;
    if (overall >= 60) return StarTier.oneStar;
    return StarTier.noStars;
  }
}
