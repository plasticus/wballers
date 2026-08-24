import 'trade_asset.dart';

/// A light, honest descriptor of what an offer's own numbers actually
/// produced -- not a real team-strategy simulation (`trading-and-hidden-
/// gems-notes.md`'s Trade Board section flags the fuller "contention
/// window"/"situational" signal-driven version as still-undesigned).
/// [TradeOfferGenerator] decides this *after* building an offer, by
/// reading what actually resulted (an age gap, how much of the coach's
/// swing got used), rather than deliberately targeting it -- a
/// description, not a plan.
enum TradeOfferCharacter {
  /// A close-to-even trade, nothing dramatic either direction.
  value,

  /// The team offering is giving up meaningfully younger/higher-upside
  /// value for a proven, ready-now piece -- reads like a win-now push.
  winNow,

  /// The team offering is giving up a proven piece for meaningfully
  /// younger/higher-upside value -- reads like a rebuild.
  rebuilding,

  /// Uses nearly all of the offering coach's Management-driven swing --
  /// a real, deliberately lopsided ask, still numerically legal.
  aggressive,
}

/// A GM-chosen filter for what the Trade Board tries to show, on top of
/// (not instead of) putting a specific player on the block -- a direct
/// GM ask (2026-08-23): "Could we have some further options on the
/// trade board? Like... Give me some toggles or something. I'm looking
/// to get rid of draft picks, get more draft picks, looking to offload
/// some depth to improve quality, looking to lose some quality to get
/// younger, or 'anything'." `trade_offer_generator.dart`'s
/// `generateTradeOffersForIntent` is what actually builds a matching
/// board; each non-[anything] value has its own exact real-world
/// meaning spelled out there.
enum TradeBoardIntent {
  /// No filter -- the ordinary board, exactly what
  /// [TradeBoardIntent.anything] not existing already meant.
  anything,

  /// The GM sends away a real pick in the deal.
  shedPicks,

  /// The GM receives a real pick in the deal.
  gainPicks,

  /// The GM sends more players than they receive -- consolidating depth
  /// into fewer, better roster spots.
  offloadDepth,

  /// The GM sends an older player (or players) for a younger return.
  getYounger,

  /// The GM chases one real star -- an 88+ overall player, or a real
  /// upper-80s riser with the age/potential to get there -- paying with
  /// a real package of draft picks and/or a young high-potential
  /// prospect. A direct GM ask (2026-08-24, after
  /// `tools/trade_study/`'s own standalone version of this same idea):
  /// "there should probably also be a tag for like... going big, or big
  /// splash... tough to do, usually requires more draft picks or youngs
  /// w/ big potential."
  goingBig,
}

/// "Shed Picks" / "Gain Picks" / "Offload Depth" / "Get Younger" /
/// "Going Big" / "Anything" -- the Trade Board's own toggle labels for
/// [TradeBoardIntent].
String tradeBoardIntentLabel(TradeBoardIntent intent) => switch (intent) {
  TradeBoardIntent.anything => 'Anything',
  TradeBoardIntent.shedPicks => 'Shed Picks',
  TradeBoardIntent.gainPicks => 'Gain Picks',
  TradeBoardIntent.offloadDepth => 'Offload Depth',
  TradeBoardIntent.getYounger => 'Get Younger',
  TradeBoardIntent.goingBig => 'Going Big',
};

/// One AI team's trade proposal -- accept or decline, no negotiation
/// (`trading-and-hidden-gems-notes.md`: "no player-initiated trades," a
/// deliberate scope cut). [offeredToYou] is what the GM would receive;
/// [askedFromYou] is what the GM would give up in return. Both sides'
/// assets can be any mix of players and picks.
class TradeOffer {
  const TradeOffer({
    required this.id,
    required this.offeringTeamAbbreviation,
    required this.offeredToYou,
    required this.askedFromYou,
    required this.character,
  });

  /// Stable and deterministic for a given (team, assets) combination --
  /// two calls to the generator with the same inputs produce the same
  /// id, which is what lets [Franchise.resolvedTradeOfferIds] recognize
  /// "this exact offer was already accepted/declined this turn" across
  /// a screen reopen without persisting the offer itself.
  final String id;

  final String offeringTeamAbbreviation;
  final List<TradeAsset> offeredToYou;
  final List<TradeAsset> askedFromYou;
  final TradeOfferCharacter character;

  int get offeredValue => totalTradeValue(offeredToYou);
  int get askedValue => totalTradeValue(askedFromYou);
}
