import '../../player/domain/player.dart';
import 'star_tier.dart';

/// Active-roster size and star-tier caps from `star_system.md`
/// (`question.md` decision 18). Reserve/injured-reserve players are outside
/// this count entirely — [evaluateRosterLegality] only ever looks at
/// whoever is currently on the active roster.
const kActiveRosterSize = 12;
const kMaxFiveStarPlayers = 2;

/// Five-star and four-star combined. A roster with zero five-star players
/// can still carry up to this many four-star players — the cap doesn't
/// shrink just because no five-star slots are used.
const kMaxFourStarAndUpPlayers = 6;

/// The result of checking a proposed active roster against the star-tier
/// caps. Exposes the raw counts (not just a pass/fail) so a future roster
/// screen can build specific validation-warning messages without this
/// layer having to know what those messages should say.
class RosterLegality {
  const RosterLegality({
    required this.rosterSize,
    required this.fiveStarCount,
    required this.fourStarAndUpCount,
  });

  final int rosterSize;
  final int fiveStarCount;
  final int fourStarAndUpCount;

  bool get hasLegalRosterSize => rosterSize == kActiveRosterSize;
  bool get hasLegalFiveStarCount => fiveStarCount <= kMaxFiveStarPlayers;
  bool get hasLegalFourStarAndUpCount =>
      fourStarAndUpCount <= kMaxFourStarAndUpPlayers;

  bool get isLegal =>
      hasLegalRosterSize && hasLegalFiveStarCount && hasLegalFourStarAndUpCount;
}

RosterLegality evaluateRosterLegality(List<Player> roster) {
  final fiveStarCount = roster
      .where((player) => StarTier.of(player) == StarTier.fiveStar)
      .length;
  final fourStarAndUpCount = roster
      .where((player) => StarTier.of(player) != StarTier.belowFourStar)
      .length;

  return RosterLegality(
    rosterSize: roster.length,
    fiveStarCount: fiveStarCount,
    fourStarAndUpCount: fourStarAndUpCount,
  );
}
