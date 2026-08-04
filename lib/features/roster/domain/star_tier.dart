import '../../player/domain/player.dart';

/// The star-rating bucket a player's overall falls into, per
/// `star_system.md`. This is a roster-legality concept, not a player
/// attribute — see the deferred-fields note on [Player].
enum StarTier {
  fiveStar,
  fourStar,
  belowFourStar;

  static StarTier of(Player player) {
    final overall = player.ratings.overall;
    if (overall >= 90) return StarTier.fiveStar;
    if (overall >= 78) return StarTier.fourStar;
    return StarTier.belowFourStar;
  }
}
