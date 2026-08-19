import 'trade_asset.dart';

/// Which team currently owns each draft pick this season, keyed by
/// round then by the *natal* team (the one that will actually earn the
/// slot by standings, `DraftInProgress.order`) -- absent entries mean
/// the natal team still owns it, which is the overwhelmingly common
/// case (most teams never trade a pick). Only ever tracks the single
/// upcoming draft's picks -- there's no multi-year future-pick concept
/// in this game, so this map always starts fresh (empty) at the top of
/// each season's trade window.
///
/// Lives on `Franchise.pickOwnershipOverrides`, where it accumulates for
/// one season's trade window at a time
/// (`current_franchise_provider.dart`'s `acceptTradeOffer` is the only
/// writer, via [transferPickOwnership]), gets baked into a frozen
/// snapshot on the next `DraftInProgress` at season transition
/// (`season_transition_advancer.dart`'s `beginNextSeason`), and is then
/// reset back to empty for the new season's own trade window.
typedef PickOwnershipOverrides = Map<int, Map<String, String>>;

/// Who actually owns [round]'s pick that natally belongs to
/// [originalTeamAbbreviation], given [overrides] -- the natal team
/// itself, unless a trade already moved it.
String currentPickOwner(
  PickOwnershipOverrides overrides,
  int round,
  String originalTeamAbbreviation,
) => overrides[round]?[originalTeamAbbreviation] ?? originalTeamAbbreviation;

/// [overrides] with [round]'s [originalTeamAbbreviation] pick now owned
/// by [newOwnerAbbreviation]. Removes the entry entirely (rather than
/// recording a same-team override) whenever the pick lands back with its
/// own natal owner, so the map stays sparse -- absence already means
/// "the natal owner has it," a trade back to them shouldn't need special
/// handling anywhere else that reads this map.
PickOwnershipOverrides transferPickOwnership(
  PickOwnershipOverrides overrides, {
  required int round,
  required String originalTeamAbbreviation,
  required String newOwnerAbbreviation,
}) {
  final roundMap = Map<String, String>.of(overrides[round] ?? const {});
  if (newOwnerAbbreviation == originalTeamAbbreviation) {
    roundMap.remove(originalTeamAbbreviation);
  } else {
    roundMap[originalTeamAbbreviation] = newOwnerAbbreviation;
  }

  final updated = Map<int, Map<String, String>>.of(overrides);
  if (roundMap.isEmpty) {
    updated.remove(round);
  } else {
    updated[round] = roundMap;
  }
  return updated;
}

/// Every pick [teamAbbreviation] currently actually holds, across every
/// round from 1 to [rounds] -- their own natal picks not yet traded
/// away, plus anything acquired from someone else this season.
/// [allTeamAbbreviations] must cover the whole league (the GM's own team
/// plus every AI team) -- every possible natal owner, since an acquired
/// pick's [PickTradeAsset.originalTeamAbbreviation] can be any of them.
/// What `trade_offer_generator.dart` calls to find a real pick either
/// side of a prospective offer could actually put on the table.
List<PickTradeAsset> picksOwnedBy(
  String teamAbbreviation,
  PickOwnershipOverrides overrides,
  List<String> allTeamAbbreviations, {
  required int rounds,
}) {
  return [
    for (var round = 1; round <= rounds; round++)
      for (final natalTeam in allTeamAbbreviations)
        if (currentPickOwner(overrides, round, natalTeam) == teamAbbreviation)
          PickTradeAsset(round: round, originalTeamAbbreviation: natalTeam),
  ];
}
