import '../../player/domain/player.dart';
import 'roster_status.dart';
import 'star_tier.dart';

/// Active-roster size ceiling and star-tier caps from `star_system.md`
/// (`question.md` decision 18). There's no enforced minimum — a team can
/// choose to run fewer than 12 active players; that's a self-inflicted
/// disadvantage, not something the game blocks (decision 22: we're not
/// modeling the real CBA's fill-the-roster deadlines).
const kActiveRosterSize = 12;
const kMaxFiveStarPlayers = 2;

/// Five-star and four-star combined. A roster with zero five-star players
/// can still carry up to this many four-star players — the cap doesn't
/// shrink just because no five-star slots are used.
const kMaxFourStarAndUpPlayers = 6;

/// The result of checking a proposed roster against the active-roster
/// star-tier caps and the developmental-roster rules. Reserve/Inactive
/// players are outside this entirely — see [RosterStatus.reserveInactive].
/// Exposes the raw counts (not just a pass/fail) so a future roster screen
/// can build specific validation-warning messages without this layer
/// having to know what those messages should say.
class RosterLegality {
  const RosterLegality({
    required this.activeRosterSize,
    required this.fiveStarCount,
    required this.fourStarAndUpCount,
    required this.developmentalRosterSize,
    required this.ineligibleDevelopmentalCount,
  });

  final int activeRosterSize;
  final int fiveStarCount;
  final int fourStarAndUpCount;
  final int developmentalRosterSize;
  final int ineligibleDevelopmentalCount;

  bool get hasLegalActiveRosterSize => activeRosterSize <= kActiveRosterSize;
  bool get hasLegalFiveStarCount => fiveStarCount <= kMaxFiveStarPlayers;
  bool get hasLegalFourStarAndUpCount =>
      fourStarAndUpCount <= kMaxFourStarAndUpPlayers;
  bool get hasLegalDevelopmentalRosterSize =>
      developmentalRosterSize <= kMaxDevelopmentalRosterSpots;
  bool get hasOnlyEligibleDevelopmentalPlayers =>
      ineligibleDevelopmentalCount == 0;

  bool get isLegal =>
      hasLegalActiveRosterSize &&
      hasLegalFiveStarCount &&
      hasLegalFourStarAndUpCount &&
      hasLegalDevelopmentalRosterSize &&
      hasOnlyEligibleDevelopmentalPlayers;
}

RosterLegality evaluateRosterLegality({
  required List<Player> active,
  List<Player> developmental = const [],
}) {
  final fiveStarCount = active
      .where((player) => StarTier.of(player) == StarTier.fiveStar)
      .length;
  final fourStarAndUpCount = active
      .where((player) => StarTier.of(player) != StarTier.belowFourStar)
      .length;
  final ineligibleDevelopmentalCount = developmental
      .where((player) => !isDevelopmentalEligible(player))
      .length;

  return RosterLegality(
    activeRosterSize: active.length,
    fiveStarCount: fiveStarCount,
    fourStarAndUpCount: fourStarAndUpCount,
    developmentalRosterSize: developmental.length,
    ineligibleDevelopmentalCount: ineligibleDevelopmentalCount,
  );
}
