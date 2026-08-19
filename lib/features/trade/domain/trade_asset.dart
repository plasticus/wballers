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
/// [round] is 1-3. Deliberately doesn't track *which* future draft this
/// pick belongs to, or carry real cross-season ownership once traded --
/// see `trading-and-hidden-gems-notes.md`'s Trade Board section for why
/// that's a bigger, still-open piece of work. A traded pick is real for
/// the purposes of balancing *this* offer's value, not yet a persisted
/// promise that changes who's actually on the clock next draft.
class PickTradeAsset extends TradeAsset {
  const PickTradeAsset(this.round);

  final int round;

  @override
  int get tradeValue => draftPickTradeValue(round);

  @override
  String get label => switch (round) {
    1 => 'a 1st-round pick',
    2 => 'a 2nd-round pick',
    3 => 'a 3rd-round pick',
    _ => 'a future pick',
  };

  @override
  bool operator ==(Object other) =>
      other is PickTradeAsset && other.round == round;

  @override
  int get hashCode => Object.hash(PickTradeAsset, round);
}

/// The total [TradeAsset.tradeValue] across [assets].
int totalTradeValue(List<TradeAsset> assets) =>
    assets.fold(0, (sum, asset) => sum + asset.tradeValue);
