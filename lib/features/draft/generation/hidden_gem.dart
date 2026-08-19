/// A coach's Management stat occasionally finding real value in a draft
/// pick nobody else saw -- locked 2026-08-19, alongside the trading
/// system's own value math (`trade_value.dart`), since both share the
/// same "what's a coach's Management actually worth" question. See
/// `trading-and-hidden-gems-notes.md` for the full back-and-forth.
library;

import '../../../core/ratings/rating_scale.dart';
import '../../player/domain/player.dart';
import '../../training/domain/player_rating_field.dart';

/// Below this Management, a "Hidden Gem" bonus is exactly zero, every
/// round -- a genuinely below-average coach doesn't find anything a
/// blind draft wouldn't have. 30, not [kMinRating] (1) or the real
/// generation floor (29, `coach_generator.dart`'s worst-case Program--
/// no, worst-case *Players Coach* archetype) -- close enough to that
/// real floor to mean "this only ever matters for a coach who's at
/// least middling," not a curve that technically starts moving at 1 but
/// never actually reaches a real player until deep into the 30s anyway.
const kHiddenGemManagementFloor = 30;

/// The real ceiling `CoachStats.management` can ever reach
/// (`coach_generator.dart`: qualityCenter 50 + the Program Builder
/// archetype's +14 bias + the max +15 jitter) -- same constant
/// `trade_value.dart` uses for the same reason, duplicated rather than
/// imported since these 2 files are otherwise independent and neither
/// should have to import the other just for one shared number.
const kHiddenGemManagementCeiling = 79;

/// The skill-points bonus a [kHiddenGemManagementCeiling]-Management
/// coach's pick gets, by round -- 12 skill points per round number (12
/// is exactly 1 [PlayerRatings.overall] point), so a round-3 gem tops
/// out at +36 (3 OVR-equivalent, "fun," a direct GM reaction) while a
/// round-1 gem tops out at a more modest +12 -- finding a steal in the
/// 3rd round is a bigger coaching feat than in the 1st, where the whole
/// league already broadly agrees on who's good.
const Map<int, int> kHiddenGemCeilingBonus = {1: 12, 2: 24, 3: 36};

/// The skill-points bonus a coach with [management] gets for drafting in
/// [round] -- 0 at or below [kHiddenGemManagementFloor], linearly up to
/// [kHiddenGemCeilingBonus]'s number at [kHiddenGemManagementCeiling],
/// nothing beyond the ceiling since it's not reachable anyway. Locked
/// linear over the concave alternative that was also on the table -- "if
/// you went [concave], you only get a couple bonuses at specific times,"
/// a direct GM call preferring a steadier payoff across the whole
/// above-floor range.
int hiddenGemBonus({required int round, required int management}) {
  final ceilingBonus = kHiddenGemCeilingBonus[round];
  if (ceilingBonus == null) return 0;
  if (management <= kHiddenGemManagementFloor) return 0;
  final span = kHiddenGemManagementCeiling - kHiddenGemManagementFloor;
  final progress = (management - kHiddenGemManagementFloor).clamp(0, span);
  return ((ceilingBonus * progress) / span).round();
}

/// Applies [bonus] skill points to [player], spread one point at a time
/// across her 12 core rating fields in a fixed round-robin order --
/// simple and fully deterministic (no `Random` needed, matching
/// `draft_advancer.dart`'s own "nothing here rolls anything" posture for
/// every other pick-resolution step), skipping any field already at
/// [kMaxRating] rather than wasting a point there. A no-op for
/// [bonus] <= 0, so a caller never needs to check first.
Player applyHiddenGemBonus(Player player, int bonus) {
  if (bonus <= 0) return player;

  var ratings = player.ratings;
  var remaining = bonus;
  var fieldsSkippedInARow = 0;
  var index = 0;
  while (remaining > 0 &&
      fieldsSkippedInARow < PlayerRatingField.values.length) {
    final field =
        PlayerRatingField.values[index % PlayerRatingField.values.length];
    final current = ratings.valueOf(field);
    if (current < kMaxRating) {
      ratings = ratings.copyWithField(field, current + 1);
      remaining--;
      fieldsSkippedInARow = 0;
    } else {
      fieldsSkippedInARow++;
    }
    index++;
  }
  return player.copyWithRatings(ratings);
}
