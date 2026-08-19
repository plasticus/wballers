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
