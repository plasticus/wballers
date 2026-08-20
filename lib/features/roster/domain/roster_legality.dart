import '../../player/domain/player.dart';
import 'roster_status.dart';
import 'star_tier.dart';

/// Active-roster size ceiling and star-tier caps from `star_system.md`
/// (`question.md` decision 18). There's no enforced minimum — a team can
/// choose to run fewer than 12 active players; that's a self-inflicted
/// disadvantage, not something the game blocks (decision 22: we're not
/// modeling the real CBA's fill-the-roster deadlines).
const kActiveRosterSize = 12;

/// Revised 2026-08-10 (`season2roadmap.md` answer 1) alongside [StarTier]'s
/// own tier shift -- was `kMaxFiveStarPlayers`, cap unchanged at 2, just
/// renamed to match the new top tier's name.
const kMaxFourStarPlayers = 2;

/// Three-star and four-star combined. A roster with zero four-star players
/// can still carry up to this many three-star players — the cap doesn't
/// shrink just because no four-star slots are used. Was
/// `kMaxFourStarAndUpPlayers`, cap unchanged at 6, renamed for the same
/// reason as [kMaxFourStarPlayers].
const kMaxThreeStarAndUpPlayers = 6;

/// The result of checking a proposed roster against the active-roster
/// star-tier caps and the developmental-roster rules. Reserve/Inactive
/// players are outside this entirely — see [RosterStatus.reserveInactive].
/// Exposes the raw counts (not just a pass/fail) so a future roster screen
/// can build specific validation-warning messages without this layer
/// having to know what those messages should say.
class RosterLegality {
  const RosterLegality({
    required this.activeRosterSize,
    required this.fourStarCount,
    required this.threeStarAndUpCount,
    required this.developmentalRosterSize,
    required this.ineligibleDevelopmentalCount,
  });

  final int activeRosterSize;
  final int fourStarCount;
  final int threeStarAndUpCount;
  final int developmentalRosterSize;
  final int ineligibleDevelopmentalCount;

  bool get hasLegalActiveRosterSize => activeRosterSize <= kActiveRosterSize;
  bool get hasLegalFourStarCount => fourStarCount <= kMaxFourStarPlayers;
  bool get hasLegalThreeStarAndUpCount =>
      threeStarAndUpCount <= kMaxThreeStarAndUpPlayers;
  bool get hasLegalDevelopmentalRosterSize =>
      developmentalRosterSize <= kMaxDevelopmentalRosterSpots;
  bool get hasOnlyEligibleDevelopmentalPlayers =>
      ineligibleDevelopmentalCount == 0;

  bool get isLegal =>
      hasLegalActiveRosterSize &&
      hasLegalFourStarCount &&
      hasLegalThreeStarAndUpCount &&
      hasLegalDevelopmentalRosterSize &&
      hasOnlyEligibleDevelopmentalPlayers;

  /// One plain-English sentence per violation, empty when [isLegal] --
  /// exactly the "future roster screen can build specific
  /// validation-warning messages" use this class's own doc comment
  /// already anticipated (2026-08-20, a direct GM ask: "I think we need
  /// to build in more notifications of roster legality... haven't seen
  /// anything about legality"). Shared by `TeamRosterScreen`'s own
  /// warning banner and `RosterLegalityMailItem`'s Assistant GM
  /// message, so the two surfaces can never say something different.
  List<String> get violationMessages {
    return [
      if (!hasLegalActiveRosterSize)
        'Your active roster has $activeRosterSize players -- the max is '
            '$kActiveRosterSize.',
      if (!hasLegalFourStarCount)
        'You\'re carrying $fourStarCount four-star players -- the max is '
            '$kMaxFourStarPlayers.',
      if (!hasLegalThreeStarAndUpCount)
        'You\'re carrying $threeStarAndUpCount three-star-or-better '
            'players -- the max is $kMaxThreeStarAndUpPlayers.',
      if (!hasLegalDevelopmentalRosterSize)
        'Your developmental roster has $developmentalRosterSize players '
            '-- the max is $kMaxDevelopmentalRosterSpots.',
      if (!hasOnlyEligibleDevelopmentalPlayers)
        '$ineligibleDevelopmentalCount developmental player'
            '${ineligibleDevelopmentalCount == 1 ? '' : 's'} '
            'no longer qualif${ineligibleDevelopmentalCount == 1 ? 'ies' : 'y'} '
            'for that spot.',
    ];
  }
}

RosterLegality evaluateRosterLegality({
  required List<Player> active,
  List<Player> developmental = const [],
}) {
  final fourStarCount = active
      .where((player) => StarTier.of(player) == StarTier.fourStar)
      .length;
  final threeStarAndUpCount = active
      .where(
        (player) =>
            StarTier.of(player) == StarTier.fourStar ||
            StarTier.of(player) == StarTier.threeStar,
      )
      .length;
  final ineligibleDevelopmentalCount = developmental
      .where((player) => !isDevelopmentalEligible(player))
      .length;

  return RosterLegality(
    activeRosterSize: active.length,
    fourStarCount: fourStarCount,
    threeStarAndUpCount: threeStarAndUpCount,
    developmentalRosterSize: developmental.length,
    ineligibleDevelopmentalCount: ineligibleDevelopmentalCount,
  );
}
