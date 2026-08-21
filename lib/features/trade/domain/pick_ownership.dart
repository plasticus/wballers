import 'trade_asset.dart';

/// How many upcoming draft classes' picks are tradeable at once -- "next
/// + one more," a direct GM call (2026-08-19): "Future picks for sure.
/// At least one season out." A franchise's very first season (internally
/// [Franchise.season] `0`) has no "own draft" to trade at all -- its
/// roster and that season's draft class are both already set at
/// creation -- so the earliest tradeable draft is always the one that
/// stocks the *next* season, matching [tradeableDraftSeasons].
const kTradeablePickHorizonSeasons = 2;

/// The [Franchise.season] numbers whose drafts are tradeable right now,
/// given the franchise's currently-live [currentSeason] -- the
/// immediately upcoming draft (`currentSeason + 1`, the one
/// `season_transition_advancer.dart`'s `beginNextSeason` is about to set
/// up) through [kTradeablePickHorizonSeasons] out. A draft "season
/// number" here always means the season it *stocks* -- the draft that
/// runs at the end of season N produces season N+1's rookies, so that
/// draft's own number is N+1, matching [DraftInProgress]'s eventual
/// `Franchise.season` once it's set up.
List<int> tradeableDraftSeasons(int currentSeason) => [
  for (
    var seasonsOut = 1;
    seasonsOut <= kTradeablePickHorizonSeasons;
    seasonsOut++
  )
    currentSeason + seasonsOut,
];

/// Which team currently owns each pick in *one* draft, keyed by round
/// then by the *natal* team (the one that will actually earn the slot by
/// standings, `DraftInProgress.order`) -- absent entries mean the natal
/// team still owns it, which is the overwhelmingly common case (most
/// teams never trade a pick). What [DraftInProgress.pickOwnershipOverrides]
/// itself is -- a single draft's frozen snapshot, baked in once that
/// draft actually starts (`season_transition_advancer.dart`'s
/// `beginNextSeason`). For the *live*, still-accumulating, multi-season
/// picture the trade window itself works with, see
/// [FuturePickOwnershipOverrides].
typedef PickOwnershipOverrides = Map<int, Map<String, String>>;

/// Who actually owns [round]'s pick that natally belongs to
/// [originalTeamAbbreviation], given one draft's [overrides] -- the
/// natal team itself, unless a trade already moved it.
String currentPickOwner(
  PickOwnershipOverrides overrides,
  int round,
  String originalTeamAbbreviation,
) => overrides[round]?[originalTeamAbbreviation] ?? originalTeamAbbreviation;

/// One draft's [overrides] with [round]'s [originalTeamAbbreviation] pick
/// now owned by [newOwnerAbbreviation]. Removes the entry entirely
/// (rather than recording a same-team override) whenever the pick lands
/// back with its own natal owner, so the map stays sparse -- absence
/// already means "the natal owner has it," a trade back to them
/// shouldn't need special handling anywhere else that reads this map.
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

/// Which team currently owns each pick across *every* still-tradeable
/// future draft, keyed by draft season (see [tradeableDraftSeasons]) then
/// [PickOwnershipOverrides] for that one draft. What
/// `Franchise.pickOwnershipOverrides` actually is -- accumulates for as
/// many seasons as a pick has been traded ahead of its own draft
/// (`current_franchise_provider.dart`'s `acceptTradeOffer` is the only
/// writer, via [transferFuturePickOwnership]). `season_transition_advancer.dart`'s
/// `beginNextSeason` slices off just the season *now* starting its draft
/// into a frozen [DraftInProgress.pickOwnershipOverrides] snapshot and
/// removes that slice here -- every other season's entries (the ones
/// still further out) carry forward untouched, they don't reset.
typedef FuturePickOwnershipOverrides = Map<int, PickOwnershipOverrides>;

/// Who actually owns [round]'s [draftSeason] pick that natally belongs to
/// [originalTeamAbbreviation], given the live, multi-season [overrides].
String currentFuturePickOwner(
  FuturePickOwnershipOverrides overrides, {
  required int draftSeason,
  required int round,
  required String originalTeamAbbreviation,
}) {
  return currentPickOwner(
    overrides[draftSeason] ?? const {},
    round,
    originalTeamAbbreviation,
  );
}

/// The live, multi-season [overrides] with [draftSeason]'s [round]
/// [originalTeamAbbreviation] pick now owned by [newOwnerAbbreviation] --
/// same sparse-map posture as [transferPickOwnership], extended with the
/// season key: a [draftSeason] with nothing left traded away from natal
/// owners is removed entirely, not left behind as an empty map.
FuturePickOwnershipOverrides transferFuturePickOwnership(
  FuturePickOwnershipOverrides overrides, {
  required int draftSeason,
  required int round,
  required String originalTeamAbbreviation,
  required String newOwnerAbbreviation,
}) {
  final updatedSlice = transferPickOwnership(
    overrides[draftSeason] ?? const {},
    round: round,
    originalTeamAbbreviation: originalTeamAbbreviation,
    newOwnerAbbreviation: newOwnerAbbreviation,
  );
  final updated = Map<int, PickOwnershipOverrides>.of(overrides);
  if (updatedSlice.isEmpty) {
    updated.remove(draftSeason);
  } else {
    updated[draftSeason] = updatedSlice;
  }
  return updated;
}

/// Every pick [teamAbbreviation] currently actually holds, across every
/// [draftSeasons] (see [tradeableDraftSeasons]) and every round from 1 to
/// [rounds] -- their own natal picks not yet traded away, plus anything
/// acquired from someone else. [allTeamAbbreviations] must cover the
/// whole league (the GM's own team plus every AI team) -- every possible
/// natal owner, since an acquired pick's [PickTradeAsset.originalTeamAbbreviation]
/// can be any of them. What `trade_offer_generator.dart` calls to find a
/// real pick either side of a prospective offer could actually put on
/// the table.
List<PickTradeAsset> picksOwnedBy(
  String teamAbbreviation,
  FuturePickOwnershipOverrides overrides,
  List<String> allTeamAbbreviations, {
  required List<int> draftSeasons,
  required int rounds,
}) {
  return [
    for (final draftSeason in draftSeasons)
      for (var round = 1; round <= rounds; round++)
        for (final natalTeam in allTeamAbbreviations)
          if (currentFuturePickOwner(
                overrides,
                draftSeason: draftSeason,
                round: round,
                originalTeamAbbreviation: natalTeam,
              ) ==
              teamAbbreviation)
            PickTradeAsset(
              draftSeason: draftSeason,
              round: round,
              originalTeamAbbreviation: natalTeam,
            ),
  ];
}

/// A short, GM-facing phrase naming which draft [draftSeason] is --
/// "Season 2," matching the same `season + 1` display convention every
/// other on-screen season number already uses (`dashboard_screen.dart`'s
/// "Season ${franchise.season + 1}", `player_detail_screen.dart`'s draft
/// year). Named the real season outright rather than relative "next
/// draft"/"the draft after" wording -- a direct GM ask (2026-08-21):
/// "don't say 'next draft' -- call it out specifically, like 3rd round
/// pick (Season 2)." [currentSeason] is unused now that the label doesn't
/// need to compare against it, kept only so callers don't all need a
/// simultaneous signature change.
String pickHorizonLabel(int draftSeason, int currentSeason) =>
    'Season ${draftSeason + 1}';
