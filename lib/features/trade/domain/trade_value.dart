/// The objective, numeric side of the trading system -- what a package
/// of players/picks is worth, and how big a mismatch a coach's
/// Management can get away with. Locked 2026-08-19 after working through
/// several real trade scenarios by hand (a plain 1:1, a star-for-phenom
/// pick-swap, a 2-for-2 sweetened with a pick) until the numbers below
/// satisfied all of them at once -- see `trading-and-hidden-gems-notes.md`
/// for the full worked cases and reasoning. This file is deliberately
/// just the value math -- it says nothing about *which* teams offer
/// *what* to whom (the still-unbuilt Trade Board/offer-generation piece).
///
/// [playerTradeValue]'s potential/age terms and the [kDraftPickTradeValue]
/// ladder were re-tuned 2026-08-23 against `tools/trade_study/`'s real
/// dataset -- 25 hand-rated generated trades, a direct GM ask ("let's try
/// it, and later if I don't like it, we'll collect more ratings. build it
/// in."). The original [PlayerRatings.skillPoints]-only value ignored
/// potential and age entirely, which the GM's own notes flagged
/// repeatedly and consistently as the single biggest source of
/// "egregious" trades (a near-max-potential 20-year-old traded for a
/// similar-overall 28-year-old registered as fine; the reverse never
/// showed up as the blowout it should have been). Fitting the new terms'
/// weights against the 25 real ratings (Pearson correlation between
/// signed value gap and the GM's own -5..+5 rating) took the fit from
/// 0.20 (skillPoints alone) to ~0.86 -- see the tool's own `ratings.json`
/// for the underlying data if these ever need re-tuning.
library;

/// Current ability at or below this contributes no [playerTradeValue]
/// upside premium or age-risk discount at all, and only
/// [kTradeValueReplacementFloorFraction] of skillPoints itself -- real
/// generated junk regardless of birth year or ceiling, per several
/// independent notes from the same trade study: "Nakamura is junk and
/// doesn't factor in," "who cares at mid-50s," "sub-50 OVR should just
/// quit and get a job." Gated on `max(overall, potential)`, not overall
/// alone -- an undeveloped high-ceiling prospect (low current OVR, high
/// potential) is exactly who this system exists to credit, not exclude
/// on a technicality (an early tuning pass zeroed out a 59 OVR/89 POT
/// 20-year-old this way by mistake).
const kTradeValueReplacementOverall = 60;

/// [playerTradeValue]'s upside premium and age-risk discount apply at
/// full strength once `max(overall, potential)` reaches this --
/// "unambiguously a real, current rotation-quality piece." Linear ramp
/// between [kTradeValueReplacementOverall] and here.
const kTradeValueFullWeightOverall = 75;

/// Skill points of [playerTradeValue] credited per point [potential]
/// exceeds [overall] by, once [_tradeValueQualityRamp] has scaled it in.
/// Roughly a third of a guaranteed current-overall point's own weight
/// (12 skill points per [PlayerRatings.overall] point) -- unrealized
/// potential is a real asset but a discounted one, not a sure thing.
const kTradeValueUpsideWeight = 4;

/// Skill points of [playerTradeValue] discounted per point of
/// [_tradeValueAgeRiskFactor] (0.0-1.0), scaled by the player's own
/// [overall] so the discount stays proportionate -- an aging star has
/// more real value at stake than an aging bench piece with an identical
/// birth year.
const kTradeValueAgeRiskWeight = 1.5;

/// 0.0 (no real decline risk yet) to 1.0 (deep into it) -- shares its
/// band boundaries with `training_advancer.dart`'s own private
/// `_ageCurveFactor` (peak at 27, real decline underway by 30, steep by
/// 33+) so trade value and the actual growth/decline simulation agree on
/// roughly the same aging story, without [playerTradeValue] importing
/// that file's unrelated weekly-growth internals.
double _tradeValueAgeRiskFactor(int age) {
  if (age <= 26) return 0.0;
  if (age <= 27) return 0.1;
  if (age <= 29) return 0.3;
  if (age <= 32) return 0.6;
  return 1.0;
}

/// 0.0 at/below [kTradeValueReplacementOverall], 1.0 at/above
/// [kTradeValueFullWeightOverall], linear between -- how much of
/// [playerTradeValue]'s upside premium and age-risk discount actually
/// apply. [gate] should be `max(overall, potential)`, never overall
/// alone (see [kTradeValueReplacementOverall]'s doc comment).
double _tradeValueQualityRamp(int gate) {
  if (gate <= kTradeValueReplacementOverall) return 0.0;
  if (gate >= kTradeValueFullWeightOverall) return 1.0;
  return (gate - kTradeValueReplacementOverall) /
      (kTradeValueFullWeightOverall - kTradeValueReplacementOverall);
}

/// How much of a player's raw [PlayerRatings.skillPoints] still counts
/// toward [playerTradeValue] once quality has ramped all the way down to
/// [kTradeValueReplacementOverall] or below -- a real, if minimal, floor
/// (not literally 0; a below-replacement player still occupies a real
/// roster spot), scaling up to the full, undiscounted skillPoints once
/// [_tradeValueQualityRamp] reaches 1.0 *and* [_tradeValueNoUpsideEscapeRamp]
/// also clears her (see that one's own doc comment for why quality alone
/// isn't the whole story above replacement either).
///
/// Added 2026-08-24 -- `tools/trade_study/`'s real dataset kept flagging
/// the same gap across 3 different Trade Board toggles at once: a
/// 50-65 OVR, often 30+-year-old player with no real potential could
/// still fetch a real 1st-round pick outright, or 2 of them could "sum"
/// on paper to match a genuinely good young player plus a pick. Direct
/// GM notes, verbatim: "50ovr has zero value... it's offensive,"
/// "58ovr age 32 isn't worth a 3rd. Disgusting," "[she] shouldn't be on
/// a roster, much less worth a 1st," "INSANE... one of the worst trades
/// you've shown me," "A first round pick is equivalent to like... a
/// 20yo 75/89ish, I bet." [kTradeValueUpsideWeight]/
/// [kTradeValueAgeRiskWeight] only ever add or subtract a bonus/penalty
/// on top of the *full* skillPoints term -- skillPoints itself, the
/// dominant term by far, was never actually discounted, so a
/// replacement-level veteran never read as anywhere close to worthless
/// the way the GM's own gut consistently said she should. Verified
/// against that same dataset before shipping: every one of the
/// above-quoted trades, and every other trade this fix was aimed at,
/// now genuinely fails its own [tradeSwing]/tolerance check instead of
/// reading as legal.
///
/// Lowered 0.1 -> 0.04 the next day, after `tools/trade_study/`'s new
/// direct "Name Your Price" mode named several 70-79 OVR/minimal-upside
/// veterans as worth roughly a 3rd-round pick or less, verbatim: "not
/// worth a draft pick, ever," "too crappy to even be called a
/// sweetener," "WEAK 3rd, if anything" -- these were already gated by
/// [_tradeValueNoUpsideEscapeRamp] (added the same day as the original
/// 0.1), but still computed to 2-5x too much (84-254 instead of ~0-50)
/// purely because 0.1 of a real overall's skillPoints is still a real
/// number. See [_tradeValueUpsideRunwayRamp]'s own doc comment for the
/// other half of this same fix.
const kTradeValueReplacementFloorFraction = 0.04;

/// Potential-over-overall gap at/above which a player reads as a real
/// prospect with genuine runway left -- full credit toward
/// [_tradeValueNoUpsideEscapeRamp], tapering to none at gap 0 (a player
/// who's already every bit of who she's ever going to be).
const kTradeValueNoUpsideRunwayGap = 15;

/// Overall at/above which a player is unambiguously elite regardless of
/// remaining potential gap -- full credit toward
/// [_tradeValueNoUpsideEscapeRamp] even with zero runway left, since
/// being capped *at a genuine star level* is exactly what a star is.
/// Matches [StarTier.fourStar]'s own 90+ threshold on purpose -- the
/// same real-quality line the rest of the game already draws. Tapers in
/// from [kTradeValueEliteOverallStart].
const kTradeValueEliteOverallFull = 90;

/// Where [kTradeValueEliteOverallFull]'s credit starts phasing in --
/// see that constant's own doc comment.
const kTradeValueEliteOverallStart = 85;

/// 0.0 at zero potential-over-overall gap, 1.0 at
/// [kTradeValueNoUpsideRunwayGap] or above -- squared, not linear, so a
/// small real gap (2-5 points, essentially "she might tick up a little")
/// still reads as close to zero credit rather than a meaningfully
/// diluted discount. Squared 2026-08-24 -- a linear ramp let even a
/// 3-point gap (e.g. 72 OVR/75 POT) claim a real 20% credit, which
/// combined with a large skillPoints base still computed to several
/// times what a direct "Name Your Price" answer named for that exact
/// shape ("maybe a 3rd rounder... take it without question," engine
/// said 254). A genuine riser (a double-digit gap) is barely affected
/// either way -- (11/15) vs (11/15)² only differs by about 27%; it's
/// specifically the near-zero-gap end this was ever about.
double _tradeValueUpsideRunwayRamp(int overall, int potential) {
  final gap = potential > overall ? potential - overall : 0;
  final ratio = gap / kTradeValueNoUpsideRunwayGap;
  if (ratio >= 1.0) return 1.0;
  return ratio * ratio;
}

/// 0.0 at/below [kTradeValueEliteOverallStart], 1.0 at/above
/// [kTradeValueEliteOverallFull], linear between.
double _tradeValueEliteRamp(int overall) {
  if (overall <= kTradeValueEliteOverallStart) return 0.0;
  if (overall >= kTradeValueEliteOverallFull) return 1.0;
  return (overall - kTradeValueEliteOverallStart) /
      (kTradeValueEliteOverallFull - kTradeValueEliteOverallStart);
}

/// How much of [playerTradeValue]'s skillPoints [_tradeValueQualityRamp]
/// alone would still credit actually survives -- the higher of "she has
/// real runway left" ([_tradeValueUpsideRunwayRamp]) or "she's already
/// unambiguously elite" ([_tradeValueEliteRamp]). Neither alone is the
/// right gate: a player already at an elite overall doesn't need *more*
/// upside to justify her price (a 90 OVR/90 POT veteran is still a real
/// star), and a real riser doesn't need to already be elite (that's the
/// entire premise of a riser). But a merely-good, already-capped
/// veteran -- decent overall, potential barely above it, nowhere near
/// elite either -- gets neither escape hatch, on purpose.
///
/// Added 2026-08-24, a second wave of `tools/trade_study/` ratings after
/// [kTradeValueReplacementFloorFraction] shipped: [kTradeValueFullWeightOverall]
/// alone (75) let a 67-90 OVR player with essentially zero remaining
/// potential gap still price at full, undiscounted skillPoints, which
/// kept reading as a real blowout for the Shed Picks toggle specifically
/// (spend picks, buy a player) -- unanimous, emphatic GM notes: "If
/// Reeves is worth a pick, it's a 3rd" (73 OVR/75 POT), "I would take a
/// 2nd for odom. Absolutely not worth a 1st" (80 OVR/80 POT), "a 2 star
/// player is sometimes worth a 3rd, never this" (76 OVR/76 POT). The
/// contrast that pinned down *why*: a 90 OVR/90 POT veteran read as
/// "Reasonable" for the same asking price a 85 OVR/86 POT one got
/// "Stupid" for, and a real 20-year-old riser (86 OVR/97 POT) got "I
/// like that" at a price a same-overall, no-upside 24-year-old (85
/// OVR/86 POT) got torched for -- current overall alone
/// ([kTradeValueFullWeightOverall]) was never the actual gate; it's
/// "real remaining upside, or already a genuine star" that is.
double _tradeValueNoUpsideEscapeRamp(int overall, int potential) {
  final runway = _tradeValueUpsideRunwayRamp(overall, potential);
  final elite = _tradeValueEliteRamp(overall);
  return runway > elite ? runway : elite;
}

/// What one player is worth in a trade -- [PlayerRatings.skillPoints]
/// (current ability, the original and still-dominant term, though no
/// longer counted in full below replacement quality, or without real
/// upside/elite status above it --
/// [kTradeValueReplacementFloorFraction]/[_tradeValueNoUpsideEscapeRamp])
/// plus a real premium for unrealized [PlayerRatings.potential] and a
/// real discount for age-related decline/retirement risk, both ramped
/// to zero for anyone who isn't a real prospect or a real current piece
/// either way (see [kTradeValueReplacementOverall]). Takes the raw
/// ratings/age rather than a [Player] directly so callers
/// (`trade_asset.dart`, the standalone `tools/trade_study/` PHP port)
/// don't need the whole domain object.
int playerTradeValue({
  required int overall,
  required int potential,
  required int skillPoints,
  required int age,
}) {
  final ramp = _tradeValueQualityRamp(
    overall > potential ? overall : potential,
  );
  final escapeRamp = _tradeValueNoUpsideEscapeRamp(overall, potential);
  final skillPointsMultiplier =
      kTradeValueReplacementFloorFraction +
      (1 - kTradeValueReplacementFloorFraction) * ramp * escapeRamp;
  final upside =
      kTradeValueUpsideWeight *
      (potential > overall ? potential - overall : 0) *
      ramp;
  final ageRisk =
      kTradeValueAgeRiskWeight * _tradeValueAgeRiskFactor(age) * overall * ramp;
  final raw = skillPoints * skillPointsMultiplier + upside - ageRisk;
  return raw < 0 ? 0 : raw.round();
}

/// A draft pick's flat trade value, in [playerTradeValue]-style skill
/// points. Deliberately *not* the real average overall a pick actually
/// turns into once drafted (`draft_generator.dart`'s real generated
/// classes average ~889/803/754 skill points for rounds 1/2/3) -- this
/// ladder is hand-tuned so a pick reads as a real, substantial asset
/// (the 2026-08-23 re-tuning pass's whole point -- the GM's own notes on
/// the original 290/150/50 ladder: "you don't trade a first for a 77/80
/// and a 75/75," "1st round pick is worth more than [two mediocre
/// veterans] combined") without swamping every ordinary trade (a full
/// 1st-rounder is still well short of what a real current star is worth
/// under [playerTradeValue]). Re-fit against the same 25-trade dataset
/// [playerTradeValue]'s weights were -- round 1 moved the least of the
/// three (the original number was already close to right once player
/// values stopped being the bigger error source); round 2 moved the
/// most (a full 47% bump, the clearest signal in the data); round 3 has
/// only one real data point so far and was left alone rather than
/// over-fit to it. Round 1 is still deliberately kept a bigger jump from
/// round 2 than round 2 is from round 3 (180 vs. 170, matching the
/// original ladder's own shape/reasoning), even though round 2's move
/// alone would have inverted that.
const Map<int, int> kDraftPickTradeValue = {1: 400, 2: 220, 3: 50};

/// [kDraftPickTradeValue] for [round], or `0` for anything outside the
/// 3 real rounds (`draft_generator.dart`'s `kDraftRounds`) -- a
/// defensive fallback, never expected to actually matter in practice.
int draftPickTradeValue(int round) => kDraftPickTradeValue[round] ?? 0;

/// The tightest a trade's value gap can ever be forced to, regardless of
/// how poor the offering coach's Management is -- originally set so two
/// players who display the exact same rounded OVR could *always* be
/// traded, no matter the coach (a [PlayerRatings.overall] band is 12
/// skill points wide -- e.g. every sum from 894-905 rounds to 75 -- so
/// the widest possible [PlayerRatings.skillPoints] gap between two
/// same-OVR players is 11). [playerTradeValue]'s potential/age terms
/// (2026-08-23) mean that guarantee no longer strictly holds once two
/// same-OVR players genuinely differ in potential or age -- deliberately
/// so, since treating a same-OVR 20-year-old phenom and 33-year-old
/// journeyman as automatically interchangeable is exactly the blind spot
/// that re-tuning fixed. This floor stays as the general "never
/// impossibly tight" guarantee for ordinary, similar players -- not a
/// same-OVR-specific promise anymore.
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
/// in the game can make an ordinary, similar-players trade. Yields
/// 11/24/47/60 at
/// Management 30/50/70/[kMaxCoachManagement].
int tradeSwing(int management) {
  final raw = ((management * management) / 104).round();
  return raw < kMinTradeSwing ? kMinTradeSwing : raw;
}

/// Whether a trade offering [offeredValue] (the sum of every asset --
/// players at [playerTradeValue], picks at [draftPickTradeValue] -- one
/// side is giving up) for [requestedValue]
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
