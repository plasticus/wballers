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
  int get tradeValue => playerTradeValue(
    overall: player.ratings.overall,
    potential: player.ratings.potential,
    skillPoints: player.ratings.skillPoints,
    age: player.age,
  );

  @override
  String get label => player.name;

  @override
  bool operator ==(Object other) =>
      other is PlayerTradeAsset && other.player.id == player.id;

  @override
  int get hashCode => player.id.hashCode;
}

/// A future draft pick, valued on the flat [draftPickTradeValue] ladder --
/// [round] is 1-3. [draftSeason] is which draft this is (an absolute
/// `Franchise.season` number -- the season the draft *stocks*, matching
/// `pick_ownership.dart`'s `tradeableDraftSeasons`), always one of the
/// [kTradeablePickHorizonSeasons] upcoming drafts -- there's no
/// open-ended future-pick trading. [tradeValue] doesn't discount for how
/// far out [draftSeason] is -- a deliberate simplification, same "keep
/// the numbers few and legible" posture as the flat per-round ladder
/// itself; nothing about *how far away* a pick is currently factors into
/// its value.
///
/// [originalTeamAbbreviation] is whose *natal* pick this is -- the team
/// that will actually earn this slot by standings (`DraftInProgress.order`,
/// once that draft season actually arrives) -- which may not be who
/// currently holds it: a pick already traded once can be traded again
/// (`pick_ownership.dart`'s `picksOwnedBy` is what finds every pick a
/// team currently actually has to offer, across every tradeable
/// [draftSeason]). Real ownership: accepting a trade with one of these
/// transfers it for real (`current_franchise_provider.dart`'s
/// `acceptTradeOffer`, `pick_ownership.dart`'s
/// `transferFuturePickOwnership`), and once [draftSeason] actually
/// arrives, it genuinely puts the acquiring team on the clock
/// (`DraftInProgress.onTheClock`), not just a value-only IOU.
class PickTradeAsset extends TradeAsset {
  const PickTradeAsset({
    required this.draftSeason,
    required this.round,
    required this.originalTeamAbbreviation,
  });

  final int draftSeason;
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
      other.draftSeason == draftSeason &&
      other.round == round &&
      other.originalTeamAbbreviation == originalTeamAbbreviation;

  @override
  int get hashCode =>
      Object.hash(PickTradeAsset, draftSeason, round, originalTeamAbbreviation);
}

/// The total [TradeAsset.tradeValue] across [assets].
int totalTradeValue(List<TradeAsset> assets) =>
    assets.fold(0, (sum, asset) => sum + asset.tradeValue);
