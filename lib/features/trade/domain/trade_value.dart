/// The objective, numeric side of the trading system -- what a package
/// of players/picks is worth, and how big a mismatch a coach's
/// Management can get away with. Locked 2026-08-19 after working through
/// several real trade scenarios by hand (a plain 1:1, a star-for-phenom
/// pick-swap, a 2-for-2 sweetened with a pick) until the numbers below
/// satisfied all of them at once -- see `trading-and-hidden-gems-notes.md`
/// for the full worked cases and reasoning. This file is deliberately
/// just the value math -- it says nothing about *which* teams offer
/// *what* to whom (the still-unbuilt Trade Board/offer-generation piece).
library;

/// A draft pick's flat trade value, in [skillPoints]-style points --
/// `PlayerRatings.skillPoints`' currency, not [PlayerRatings.overall].
/// Deliberately *not* the real average overall a pick actually turns
/// into once drafted (`draft_generator.dart`'s real generated classes
/// average ~889/803/754 skill points for rounds 1/2/3) -- those numbers
/// are close enough to each other that no single pick could ever
/// meaningfully offset a real star-level value gap, and far enough
/// above a modest gap that adding one to an ordinary trade blows right
/// past it (a full pick reads as almost a whole extra player). This
/// ladder is hand-tuned instead: small enough that a pick is a real
/// sweetener rather than a headline asset, and spread widely enough
/// (a flat 120-point step between adjacent rounds, uneven above that --
/// round 1 is a bigger jump from round 2 than round 2 is from round 3,
/// matching the real generated data's own shape: 7.2 OVR-worth of gap
/// vs. 4.0) that swapping a better pick for a worse one can genuinely
/// offset a real star-for-prospect trade on its own.
const Map<int, int> kDraftPickTradeValue = {1: 290, 2: 150, 3: 50};

/// [kDraftPickTradeValue] for [round], or `0` for anything outside the
/// 3 real rounds (`draft_generator.dart`'s `kDraftRounds`) -- a
/// defensive fallback, never expected to actually matter in practice.
int draftPickTradeValue(int round) => kDraftPickTradeValue[round] ?? 0;

/// The tightest a trade's value gap can ever be forced to, regardless of
/// how poor the offering coach's Management is -- deliberately set so
/// two players who display the exact same rounded OVR can *always* be
/// traded, no matter the coach. A [PlayerRatings.overall] band is 12
/// skill points wide (e.g. every sum from 894-905 rounds to 75), so the
/// widest possible gap between two same-OVR players is 11 -- that's
/// this floor, not a round number picked by feel.
const kMinTradeSwing = 11;

/// How wide a value gap [tradeSwing] can ever produce, at every coach a
/// legal game state can actually generate -- `coach_generator.dart`'s
/// real ceiling for `CoachStats.management` is 79 (qualityCenter 50 +
/// the Program Builder archetype's +14 bias + the max +15 jitter; no
/// archetype/roll combination can exceed it), not the naive 99 the 1-99
/// rating scale alone would suggest.
const kMaxCoachManagement = 79;

/// How large a value mismatch a coach with [management] Management can
/// get a trade through with -- concave (`management² / 104`, floored at
/// [kMinTradeSwing]), locked 2026-08-19 after comparing it against
/// linear and against several worked trade scenarios at Management
/// 30/50/70: an average (50) coach handles ordinary trades and modest
/// sweetened ones but not a real blockbuster; a genuinely great (70)
/// coach can pull off real lopsided "cheat the AI a little" deals; the
/// real floor (Management 29, `coach_generator.dart`) still always
/// clears [kMinTradeSwing] thanks to the floor, so even the worst coach
/// in the game can make a same-OVR trade. Yields 11/24/47/60 at
/// Management 30/50/70/[kMaxCoachManagement].
int tradeSwing(int management) {
  final raw = ((management * management) / 104).round();
  return raw < kMinTradeSwing ? kMinTradeSwing : raw;
}

/// Whether a trade offering [offeredValue] (the sum of every asset --
/// players at [PlayerRatings.skillPoints], picks at
/// [draftPickTradeValue] -- one side is giving up) for [requestedValue]
/// (the same sum for what that side receives) fits inside a coach with
/// [management] Management's tolerance ([tradeSwing]). Symmetric -- it
/// doesn't matter which side is "getting the better end," only how far
/// apart the two totals are.
bool isTradeWithinManagementSwing({
  required int offeredValue,
  required int requestedValue,
  required int management,
}) {
  final gap = (offeredValue - requestedValue).abs();
  return gap <= tradeSwing(management);
}
