import '../../player/domain/player.dart';
import 'trade_value.dart';

/// One tradeable thing on one side of a [TradeOffer] -- a player already
/// on a roster, or a future draft pick. [tradeValue] is what
/// `trade_value.dart`'s swing math actually compares.
sealed class TradeAsset {
  const TradeAsset();

  int get tradeValue;

  /// A short label for the offer card -- "Jane Doe" for a player, "a
  /// 2nd-round pick" for a pick.
  String get label;
}

/// A real rostered [player] changing teams.
class PlayerTradeAsset extends TradeAsset {
  const PlayerTradeAsset(this.player);

  final Player player;

  @override
  int get tradeValue => player.ratings.skillPoints;

  @override
  String get label => player.name;

  @override
  bool operator ==(Object other) =>
      other is PlayerTradeAsset && other.player.id == player.id;

  @override
  int get hashCode => player.id.hashCode;
}

/// A future draft pick, valued on the flat [draftPickTradeValue] ladder --
/// [round] is 1-3, always next season's draft (there's no multi-year
/// future-pick concept). [originalTeamAbbreviation] is whose *natal*
/// pick this is -- the team that will actually earn this slot by
/// standings (`DraftInProgress.order`) -- which may not be who currently
/// holds it: a pick already traded once this season can be traded again
/// (`pick_ownership.dart`'s `picksOwnedBy` is what finds every pick a
/// team currently actually has to offer). Real ownership: accepting a
/// trade with one of these transfers it for real
/// (`current_franchise_provider.dart`'s `acceptTradeOffer`,
/// `pick_ownership.dart`'s `transferPickOwnership`), and it genuinely
/// puts the acquiring team on the clock at the next draft
/// (`DraftInProgress.onTheClock`), not just a value-only IOU.
class PickTradeAsset extends TradeAsset {
  const PickTradeAsset({
    required this.round,
    required this.originalTeamAbbreviation,
  });

  final int round;
  final String originalTeamAbbreviation;

  @override
  int get tradeValue => draftPickTradeValue(round);

  @override
  String get label => switch (round) {
    1 => '$originalTeamAbbreviation\'s 1st-round pick',
    2 => '$originalTeamAbbreviation\'s 2nd-round pick',
    3 => '$originalTeamAbbreviation\'s 3rd-round pick',
    _ => '$originalTeamAbbreviation\'s future pick',
  };

  @override
  bool operator ==(Object other) =>
      other is PickTradeAsset &&
      other.round == round &&
      other.originalTeamAbbreviation == originalTeamAbbreviation;

  @override
  int get hashCode =>
      Object.hash(PickTradeAsset, round, originalTeamAbbreviation);
}

/// The total [TradeAsset.tradeValue] across [assets].
int totalTradeValue(List<TradeAsset> assets) =>
    assets.fold(0, (sum, asset) => sum + asset.tradeValue);
