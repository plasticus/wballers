import 'dart:math';

import '../../draft/generation/draft_generator.dart' show kDraftRounds;
import '../../franchise/domain/franchise.dart';
import '../../franchise/domain/franchise_legality.dart';
import '../../league/domain/ai_team_roster.dart';
import '../../player/domain/player.dart';
import '../../roster/domain/roster_legality.dart';
import '../../roster/domain/roster_status.dart';
import '../../roster/domain/star_tier.dart';
import '../domain/pick_ownership.dart';
import '../domain/trade_asset.dart';
import '../domain/trade_offer.dart';
import '../domain/trade_value.dart';

/// Seed offset for the Trade Board's own random stream -- keeps it off
/// every other per-season generator's stream. Next free number after
/// `draft_advancer.dart`'s `kDraftFinalizeSeedOffset` (21).
const kTradeOfferSeedOffset = 22;

/// How many offers the Trade Board shows at once
/// (`trading-and-hidden-gems-notes.md`). 6th slot added 2026-08-21 (a
/// direct GM ask, see [kConsolidationOfferSlotIndex]).
const kTradeOfferCount = 6;

/// The one slot [generateTradeOffers] always tries as a 2-for-1
/// "consolidation" offer -- 2 of the GM's own bench-tier players for 1
/// upgraded player back (`_tryBuildConsolidationOffer`'s own doc
/// comment). A direct GM ask (2026-08-21): "I have a super deep bench,
/// but I want to transition that to a better player... show me an option
/// for that as a 6th trade slot." Always the *last* slot -- every other
/// index keeps the exact same trade-block-targeting behavior it already
/// had, so this purely adds on top rather than reshuffling what the
/// first [kTradeOfferCount] - 1 slots already meant.
const kConsolidationOfferSlotIndex = kTradeOfferCount - 1;

/// Of [kTradeOfferCount] offers, how many should try to involve
/// [Franchise.tradeBlockPlayerId] when one is set -- "the trade board
/// should TRY to have 3 (out of the 5) involve that player," a direct GM
/// ask. "Try" because there's no guarantee some AI team's own roster
/// happens to have a matching-value asset to offer for her. The first of
/// these 3 slots is stronger than "try," though --
/// [_tryBuildGuaranteedTradeBlockPickOffer] specifically aims for a real
/// 2-for-2 trade with a pick thrown in (2026-08-19, a direct GM ask: "I
/// want to see at least one trade that's a 2:2 and involved a draft
/// pick"), falling back to the same "try" shape as the other 2 slots only
/// if that specific offer genuinely can't be built.
const kTradeBlockTargetedOfferCount = 3;

/// Extra Trade Board slots [generateTradeOffers] adds on top of
/// [kTradeOfferCount] whenever the GM's active roster is oversized
/// (`RosterLegality.hasLegalActiveRosterSize`) -- half sell-for-picks
/// ([_tryBuildSellForPicksOffer]), half an extra 2-for-1 consolidation
/// ([_tryBuildConsolidationOffer], same shape the fixed slot already
/// uses). A direct GM ask (2026-08-23): "if your roster is illegal with
/// too many players, other teams are more likely to offer you picks for
/// players, and 2:1 trades where you get rid of two players for one
/// incoming. The other team recognizes that you're trying to sell off
/// players, so they'll make offers."
const kOversizedRosterExtraSlots = 4;

/// Extra Trade Board slots [generateTradeOffers] adds on top of
/// [kTradeOfferCount] whenever the GM's active roster is over either
/// star-tier cap (`RosterLegality.hasLegalFourStarCount`/
/// `hasLegalThreeStarAndUpCount`) -- each one specifically asks for one
/// of the GM's own 3-star-or-better players
/// ([_starTierOverflowCandidates]), same real-return shape
/// [_tryBuildOffer] already builds for a trade-block-targeted slot, just
/// forced onto a star instead. Same GM ask as
/// [kOversizedRosterExtraSlots]: "if your roster is illegal based on
/// having too many star-tier, you should find yourself getting more
/// offers that'd help you get out of that situation."
const kTooManyStarsExtraSlots = 3;

/// A years-of-age gap past which an offer's headline players read as a
/// deliberate youth-for-experience swap, for [TradeOfferCharacter]
/// labeling purposes only -- see that enum's own doc comment on why this
/// is a description of what resulted, not a target the generator aims
/// for.
const _kCharacterAgeGapThreshold = 4;

/// The [kTradeOfferCount] real trade offers on the board right now --
/// deterministic for a given [franchise] state (same "regenerate fresh
/// every time, nothing to persist" posture `player_market_preview_generator.dart`
/// already uses for its own preview tabs), seeded off
/// [Franchise.seasonSeed]/[kTradeOfferSeedOffset]/[SeasonProgress.nextGameDayIndex]
/// so the same offers stay stable for as long as the GM's still on the
/// same game day, and change the moment a new one is advanced into. This
/// function itself is still called fresh every time, but
/// `player_market_screen.dart`'s `_TradeBoardTabState` only actually
/// calls it once per screen visit and locally prunes from there --
/// re-calling it after an accept would read the just-changed roster and
/// silently reshuffle every other slot too, not just drop the accepted
/// one (2026-08-21, a direct GM spec).
///
/// Each offer comes from a distinct AI team where possible (shuffles
/// [League.aiTeams] first) -- can repeat once every eligible team's had
/// a turn, for a league smaller than [kTradeOfferCount] would allow (never
/// actually happens at 19 AI teams, but keeps this correct rather than
/// assuming). A team with fewer than [Franchise.tradeBlockPlayerId]'s own
/// GM-side headcount of active players to trade, or no coach data, is
/// simply skipped for that slot.
///
/// Every offer keeps player counts equal on both sides (1-for-1, or
/// occasionally 2-for-2) -- picks only ever adjust *value*, never
/// headcount -- except the one dedicated [kConsolidationOfferSlotIndex]
/// slot, deliberately 2-for-1 (`_tryBuildConsolidationOffer`'s own doc
/// comment). That's the one shape that can leave the AI side over
/// [kActiveRosterSize] active players; `current_franchise_provider.dart`'s
/// `acceptTradeOffer` is what actually keeps that safe (waives the AI's
/// own weakest pre-existing player back to free agency if accepting
/// would push them over), not anything checked here at generation time.
/// Going *under* [kActiveRosterSize] active players is always fine
/// either way -- there's no enforced minimum (`roster_legality.dart`'s
/// own doc comment). Any pick used to balance
/// an offer is real, currently-held draft equity -- either of the
/// [tradeableDraftSeasons] horizon (2026-08-19, "at least one season
/// out"), never conjured from thin air (`pick_ownership.dart`'s
/// `picksOwnedBy`).
List<TradeOffer> generateTradeOffers(Franchise franchise) {
  final random = Random(
    franchise.seasonSeed +
        kTradeOfferSeedOffset +
        franchise.seasonProgress.nextGameDayIndex,
  );

  final ownActive = [
    for (final m in franchise.roster)
      if (m.status == RosterStatus.active) m.player,
  ];
  if (ownActive.isEmpty) return const [];

  Player? tradeBlockPlayer;
  if (franchise.tradeBlockPlayerId != null) {
    for (final p in ownActive) {
      if (p.id == franchise.tradeBlockPlayerId) {
        tradeBlockPlayer = p;
        break;
      }
    }
  }

  final aiTeams = List<AiTeamRoster>.of(franchise.league.aiTeams)
    ..shuffle(random);

  final allTeamAbbreviations = [
    franchise.team.abbreviation,
    for (final aiTeam in franchise.league.aiTeams) aiTeam.team.abbreviation,
  ];
  final draftSeasons = tradeableDraftSeasons(franchise.season);

  // How much more desperate the board should look -- see
  // [kOversizedRosterExtraSlots]/[kTooManyStarsExtraSlots]'s own doc
  // comments. Both can apply at once (an oversized roster stuffed with
  // stars is a real, if uncommon, shape); each contributes its own slots
  // independently.
  final legality = evaluateFranchiseLegality(franchise);
  final oversizedExtraSlots = legality.hasLegalActiveRosterSize
      ? 0
      : kOversizedRosterExtraSlots;
  final tooManyStarsExtraSlots =
      legality.hasLegalFourStarCount && legality.hasLegalThreeStarAndUpCount
      ? 0
      : kTooManyStarsExtraSlots;
  final starOverflowCandidates = _starTierOverflowCandidates(ownActive);
  final totalSlots =
      kTradeOfferCount + oversizedExtraSlots + tooManyStarsExtraSlots;

  final offers = <TradeOffer>[];
  for (var slot = 0; slot < totalSlots; slot++) {
    final aiTeam = aiTeams[slot % aiTeams.length];

    if (slot >= kTradeOfferCount + oversizedExtraSlots) {
      // A star-tier-overflow relief slot -- reuses [_tryBuildOffer]'s
      // ordinary "forced target, real return" shape, just forced onto
      // one of the GM's own excess 3-star-or-better players instead of
      // whatever's on the trade block.
      if (starOverflowCandidates.isEmpty) continue;
      final target =
          starOverflowCandidates[random.nextInt(starOverflowCandidates.length)];
      final offer = _tryBuildOffer(
        random,
        aiTeam: aiTeam,
        ownActive: ownActive,
        forcedTarget: target,
        slotIndex: slot,
        ownTeamAbbreviation: franchise.team.abbreviation,
        pickOwnershipOverrides: franchise.pickOwnershipOverrides,
        allTeamAbbreviations: allTeamAbbreviations,
        draftSeasons: draftSeasons,
      );
      if (offer != null) offers.add(offer);
      continue;
    }

    if (slot >= kTradeOfferCount) {
      // An oversized-roster relief slot -- half sell-for-picks, half an
      // extra consolidation (both reduce the GM's own headcount, unlike
      // every other slot).
      final wantsPicksOnly = (slot - kTradeOfferCount).isEven;
      final offer = wantsPicksOnly
          ? _tryBuildSellForPicksOffer(
              random,
              aiTeam: aiTeam,
              ownActive: ownActive,
              ownTeamAbbreviation: franchise.team.abbreviation,
              pickOwnershipOverrides: franchise.pickOwnershipOverrides,
              allTeamAbbreviations: allTeamAbbreviations,
              draftSeasons: draftSeasons,
            )
          : _tryBuildConsolidationOffer(
              aiTeam: aiTeam,
              ownActive: ownActive,
              ownTeamAbbreviation: franchise.team.abbreviation,
              pickOwnershipOverrides: franchise.pickOwnershipOverrides,
              allTeamAbbreviations: allTeamAbbreviations,
              draftSeasons: draftSeasons,
            );
      if (offer != null) offers.add(offer);
      continue;
    }

    final wantsTradeBlockPlayer =
        tradeBlockPlayer != null && slot < kTradeBlockTargetedOfferCount;
    // Slot 0 is the one guaranteed 2-for-2-with-a-pick offer, whenever a
    // trade-block player is set -- a direct GM ask (2026-08-19): "I want
    // to see at least one trade that's a 2:2 and involved a draft pick."
    // Every other trade-block-targeted slot stays 1-for-something, same
    // as before. Falls back to the ordinary builder if this specific
    // shape genuinely can't be found (see that function's own doc
    // comment) -- the slot still tries for an offer either way, same
    // "try, don't guarantee" posture [kTradeBlockTargetedOfferCount]
    // already documents.
    final offer =
        (wantsTradeBlockPlayer && slot == 0
            ? _tryBuildGuaranteedTradeBlockPickOffer(
                random,
                aiTeam: aiTeam,
                ownActive: ownActive,
                forcedTarget: tradeBlockPlayer,
                ownTeamAbbreviation: franchise.team.abbreviation,
                pickOwnershipOverrides: franchise.pickOwnershipOverrides,
                allTeamAbbreviations: allTeamAbbreviations,
                draftSeasons: draftSeasons,
              )
            : slot == kConsolidationOfferSlotIndex
            ? _tryBuildConsolidationOffer(
                aiTeam: aiTeam,
                ownActive: ownActive,
                ownTeamAbbreviation: franchise.team.abbreviation,
                pickOwnershipOverrides: franchise.pickOwnershipOverrides,
                allTeamAbbreviations: allTeamAbbreviations,
                draftSeasons: draftSeasons,
              )
            : null) ??
        _tryBuildOffer(
          random,
          aiTeam: aiTeam,
          ownActive: ownActive,
          forcedTarget: wantsTradeBlockPlayer ? tradeBlockPlayer : null,
          slotIndex: slot,
          ownTeamAbbreviation: franchise.team.abbreviation,
          pickOwnershipOverrides: franchise.pickOwnershipOverrides,
          allTeamAbbreviations: allTeamAbbreviations,
          draftSeasons: draftSeasons,
        );
    if (offer != null) offers.add(offer);
  }
  return offers;
}

/// Seed offset for [generateTradeOffersForIntent]'s own random stream,
/// whenever [intent] isn't [TradeBoardIntent.anything] -- a fresh,
/// deliberately different stream from [generateTradeOffers]' own
/// [kTradeOfferSeedOffset] so switching toggles doesn't just reshuffle
/// the exact same offers into a different order. Next free number after
/// `trade_offer_generator.dart`'s own `kAssistantGmBrokerSeedOffset`
/// (26).
const kTradeBoardIntentSeedOffset = 27;

/// How many real matches [generateTradeOffersForIntent] tries to collect
/// before giving up -- same as the ordinary board's own
/// [kTradeOfferCount], so a filtered board reads as a comparable size
/// when it can actually fill out, not deliberately thin.
const kTradeBoardIntentTargetCount = kTradeOfferCount;

/// How many (AI team, attempt) draws [generateTradeOffersForIntent] is
/// willing to make hunting for [kTradeBoardIntentTargetCount] real
/// matches before giving up -- generous relative to
/// [kTradeBoardIntentTargetCount] since most individual draws won't
/// happen to match a specific intent (e.g. most ordinary offers never
/// involve a pick at all), not a sign anything's wrong when it comes up
/// short.
const kTradeBoardIntentMaxDraws = 120;

/// The Trade Board, filtered to [intent] -- a direct GM ask (2026-08-23):
/// "Could we have some further options on the trade board? ... I'm
/// looking to get rid of draft picks, get more draft picks, looking to
/// offload some depth to improve quality, looking to lose some quality
/// to get younger, or 'anything'." [TradeBoardIntent.anything] is just
/// [generateTradeOffers] itself, unchanged -- every existing caller
/// keeps exactly the same board it always got.
///
/// Every other [intent] hunts across real (AI team, attempt) draws from
/// its own dedicated random stream ([kTradeBoardIntentSeedOffset]) until
/// [kTradeBoardIntentTargetCount] real matches turn up or
/// [kTradeBoardIntentMaxDraws] is exhausted -- genuinely real, legal
/// offers the exact same builders already used everywhere else in this
/// file produce, just kept only when they happen to match what the GM
/// actually asked to see. [TradeBoardIntent.offloadDepth] reuses
/// [_tryBuildConsolidationOffer] directly (it's *always* that shape when
/// it succeeds at all); the other 3 reuse [_tryBuildOffer] and keep only
/// the draws whose real, already-computed assets happen to satisfy the
/// intent (never invents a shape [_tryBuildOffer] itself couldn't
/// produce on its own). Can come back shorter than
/// [kTradeBoardIntentTargetCount] -- a real, honest outcome when the
/// league genuinely doesn't have enough of what the GM's looking for
/// right now, not a bug to paper over.
List<TradeOffer> generateTradeOffersForIntent(
  Franchise franchise,
  TradeBoardIntent intent,
) {
  if (intent == TradeBoardIntent.anything) {
    return generateTradeOffers(franchise);
  }

  final ownActive = [
    for (final m in franchise.roster)
      if (m.status == RosterStatus.active) m.player,
  ];
  if (ownActive.isEmpty) return const [];

  final random = Random(
    franchise.seasonSeed +
        kTradeBoardIntentSeedOffset +
        franchise.seasonProgress.nextGameDayIndex +
        intent.index,
  );
  final aiTeams = List<AiTeamRoster>.of(franchise.league.aiTeams)
    ..shuffle(random);
  if (aiTeams.isEmpty) return const [];
  final allTeamAbbreviations = [
    franchise.team.abbreviation,
    for (final aiTeam in franchise.league.aiTeams) aiTeam.team.abbreviation,
  ];
  final draftSeasons = tradeableDraftSeasons(franchise.season);

  bool matches(TradeOffer offer) => switch (intent) {
    TradeBoardIntent.anything => true,
    TradeBoardIntent.shedPicks => offer.askedFromYou.any(
      (a) => a is PickTradeAsset,
    ),
    TradeBoardIntent.gainPicks => offer.offeredToYou.any(
      (a) => a is PickTradeAsset,
    ),
    TradeBoardIntent.offloadDepth =>
      offer.askedFromYou.whereType<PlayerTradeAsset>().length >
          offer.offeredToYou.whereType<PlayerTradeAsset>().length,
    TradeBoardIntent.getYounger => _sendsOlderThanItReceives(offer),
  };

  final seenIds = <String>{};
  final offers = <TradeOffer>[];
  var draws = 0;
  while (offers.length < kTradeBoardIntentTargetCount &&
      draws < kTradeBoardIntentMaxDraws) {
    final aiTeam = aiTeams[draws % aiTeams.length];
    draws++;

    final offer = intent == TradeBoardIntent.offloadDepth
        ? _tryBuildConsolidationOffer(
            aiTeam: aiTeam,
            ownActive: ownActive,
            ownTeamAbbreviation: franchise.team.abbreviation,
            pickOwnershipOverrides: franchise.pickOwnershipOverrides,
            allTeamAbbreviations: allTeamAbbreviations,
            draftSeasons: draftSeasons,
          )
        : _tryBuildOffer(
            random,
            aiTeam: aiTeam,
            ownActive: ownActive,
            forcedTarget: null,
            slotIndex: draws,
            ownTeamAbbreviation: franchise.team.abbreviation,
            pickOwnershipOverrides: franchise.pickOwnershipOverrides,
            allTeamAbbreviations: allTeamAbbreviations,
            draftSeasons: draftSeasons,
          );
    if (offer == null || !seenIds.add(offer.id)) continue;
    if (matches(offer)) offers.add(offer);
  }
  return offers;
}

/// Whether [offer]'s player assets read as the GM sending someone older
/// for someone younger back -- [TradeBoardIntent.getYounger]'s own exact
/// meaning. Compares average age of the GM's own outgoing players
/// (`askedFromYou`) against the incoming ones (`offeredToYou`); `false`
/// if either side has no player assets at all to compare (a pure
/// picks-for-picks trade never reads as an age move either way).
bool _sendsOlderThanItReceives(TradeOffer offer) {
  final sentAges = [
    for (final a in offer.askedFromYou)
      if (a is PlayerTradeAsset) a.player.age,
  ];
  final receivedAges = [
    for (final a in offer.offeredToYou)
      if (a is PlayerTradeAsset) a.player.age,
  ];
  if (sentAges.isEmpty || receivedAges.isEmpty) return false;
  final sentAvg = sentAges.reduce((a, b) => a + b) / sentAges.length;
  final receivedAvg =
      receivedAges.reduce((a, b) => a + b) / receivedAges.length;
  return sentAvg - receivedAvg >= _kCharacterAgeGapThreshold;
}

/// [active]'s own 3-star-or-better players -- the pool
/// [generateTradeOffers]' star-tier-overflow relief slots target, since
/// that's exactly who a `hasLegalFourStarCount`/`hasLegalThreeStarAndUpCount`
/// violation is actually about. Empty (never actually reached, since
/// [generateTradeOffers] only adds those slots when a real violation
/// exists) if [active] happens to hold none.
List<Player> _starTierOverflowCandidates(List<Player> active) {
  return [
    for (final player in active)
      if (StarTier.of(player) == StarTier.fourStar ||
          StarTier.of(player) == StarTier.threeStar)
        player,
  ];
}

/// Seed offset for [assistantGmBrokeredOffers]' own random stream --
/// next free number after `available_head_coaches_screen.dart`'s
/// `kAvailableHeadCoachesSeedOffset`/`injury_advancer.dart`'s
/// `kInjuryResolutionSeedOffset` (25, coincidentally shared by those
/// two unrelated streams already).
const kAssistantGmBrokerSeedOffset = 26;

/// How many of the GM's own weakest active players the Assistant GM
/// tries to actively move whenever [needsAssistantGmTradeBrokering] is
/// true. A direct GM ask (2026-08-23): "The asst gm should bust her ass
/// trying to trade out 3 players at the bottom of your roster and dev
/// slots... She should find 3x special deals just for them."
const kAssistantGmBrokerCandidateCount = 3;

/// Whether [franchise]'s post-draft situation is bad enough that the
/// Assistant GM should be actively out shopping specific players, not
/// just passively flagging the roster as illegal
/// (`mail_item.dart`'s `RosterLegalityMailItem` already covers that
/// general case) -- true only when there's genuinely nowhere left to
/// put a drafted rookie at all (both the active roster and the
/// developmental roster are already at or past their own caps) *and*
/// it's still within the post-draft Trade Weeks window
/// ([Franchise.postDraftTradeWeeksRemaining]), matching the GM's own
/// framing: "After a draft, if you don't have room, your active roster
/// is full, dev slots full...."
bool needsAssistantGmTradeBrokering(Franchise franchise) {
  if (franchise.postDraftTradeWeeksRemaining == null) return false;
  final activeCount = franchise.roster
      .where((m) => m.status == RosterStatus.active)
      .length;
  final developmentalCount = franchise.roster
      .where((m) => m.status == RosterStatus.developmental)
      .length;
  return activeCount >= kActiveRosterSize &&
      developmentalCount >= kMaxDevelopmentalRosterSpots;
}

/// [franchise]'s own weakest [kAssistantGmBrokerCandidateCount] active
/// players -- who [assistantGmBrokeredOffers] actually tries to move,
/// and `mailbox.dart`'s `AssistantGmTradeBrokeringMailItem` names
/// regardless of whether a real deal was found for each one (so the
/// mail can say "she's working on X, Y, and Z" even for whichever of
/// them didn't get a matching [TradeOffer] back). Empty whenever
/// [needsAssistantGmTradeBrokering] is false, same guard
/// [assistantGmBrokeredOffers] itself uses.
List<Player> assistantGmBrokerCandidates(Franchise franchise) {
  if (!needsAssistantGmTradeBrokering(franchise)) return const [];
  final ownActive = [
    for (final m in franchise.roster)
      if (m.status == RosterStatus.active) m.player,
  ];
  final byValue = [...ownActive]
    ..sort(
      (a, b) => PlayerTradeAsset(
        a,
      ).tradeValue.compareTo(PlayerTradeAsset(b).tradeValue),
    );
  return byValue.take(kAssistantGmBrokerCandidateCount).toList();
}

/// The Assistant GM's own real, concrete trade proposals for
/// [kAssistantGmBrokerCandidateCount] of the GM's weakest active players
/// -- empty unless [needsAssistantGmTradeBrokering] is actually true.
/// Each candidate gets tried against *every* AI team in a shuffled order
/// (not just one, unlike an ordinary Trade Board slot) via
/// [_trySellPlayerForPicks], the same "trying to get draft picks for
/// them" shape the GM's own ask called for -- "bust her ass" reads as
/// genuinely working harder than a normal slot's handful of attempts,
/// not just trying the same odds again. Only developmental-eligible
/// candidates: only active players are actually tradeable in this
/// system (every other builder in this file already assumes that too)
/// -- "dev slots full" is read as *why* she's desperate, not as a claim
/// developmental players themselves get shopped. Can come back shorter
/// than [kAssistantGmBrokerCandidateCount] if she genuinely can't find a
/// real deal for one of them -- a real, honest outcome
/// (`mail_item.dart`'s `AssistantGmTradeBrokeringMailItem` shows
/// whatever she actually found, not a padded list).
List<TradeOffer> assistantGmBrokeredOffers(Franchise franchise) {
  if (!needsAssistantGmTradeBrokering(franchise)) return const [];

  final random = Random(franchise.seasonSeed + kAssistantGmBrokerSeedOffset);
  final candidates = assistantGmBrokerCandidates(franchise);
  if (candidates.isEmpty) return const [];

  final aiTeams = List<AiTeamRoster>.of(franchise.league.aiTeams)
    ..shuffle(random);
  final allTeamAbbreviations = [
    franchise.team.abbreviation,
    for (final aiTeam in franchise.league.aiTeams) aiTeam.team.abbreviation,
  ];
  final draftSeasons = tradeableDraftSeasons(franchise.season);

  final offers = <TradeOffer>[];
  for (final candidate in candidates) {
    for (final aiTeam in aiTeams) {
      final ownedPicks = picksOwnedBy(
        aiTeam.team.abbreviation,
        franchise.pickOwnershipOverrides,
        allTeamAbbreviations,
        draftSeasons: draftSeasons,
        rounds: kDraftRounds,
      );
      if (ownedPicks.isEmpty) continue;
      final offer = _trySellPlayerForPicks(
        random,
        aiTeam: aiTeam,
        target: candidate,
        ownedPicks: ownedPicks,
      );
      if (offer != null) {
        offers.add(offer);
        break;
      }
    }
  }
  return offers;
}

/// One attempt at a valid offer from [aiTeam] -- picks (or uses
/// [forcedTarget] for) 1-2 of the GM's own active players as the ask,
/// finds the best-value-matching combination of [aiTeam]'s own active
/// players to offer back, then closes any remaining gap with a single
/// pick on whichever side needs it. `null` if nothing legal could be
/// found within a bounded number of tries -- a real, expected outcome
/// for a poorly-matched team, not a bug.
TradeOffer? _tryBuildOffer(
  Random random, {
  required AiTeamRoster aiTeam,
  required List<Player> ownActive,
  required Player? forcedTarget,
  required int slotIndex,
  required String ownTeamAbbreviation,
  required FuturePickOwnershipOverrides pickOwnershipOverrides,
  required List<String> allTeamAbbreviations,
  required List<int> draftSeasons,
}) {
  final aiActive = [
    for (final m in aiTeam.roster)
      if (m.status == RosterStatus.active) m.player,
  ];
  if (aiActive.isEmpty) return null;

  final management = aiTeam.coach.stats.management;
  final swing = tradeSwing(management);

  const kMaxAttempts = 6;
  for (var attempt = 0; attempt < kMaxAttempts; attempt++) {
    final wantCount = forcedTarget != null
        ? 1
        : (random.nextDouble() < 0.75 ? 1 : 2);
    if (ownActive.length < wantCount || aiActive.length < wantCount) continue;

    final asked = forcedTarget != null
        ? [forcedTarget]
        : _randomDistinct(random, ownActive, wantCount);
    final askedValue = asked.fold(
      0,
      (s, p) => s + PlayerTradeAsset(p).tradeValue,
    );

    final offeredPlayers = _closestCombo(aiActive, wantCount, askedValue);
    var offered = <TradeAsset>[
      for (final p in offeredPlayers) PlayerTradeAsset(p),
    ];
    var askedAssets = <TradeAsset>[for (final p in asked) PlayerTradeAsset(p)];

    var gap = totalTradeValue(offered) - totalTradeValue(askedAssets);
    if (gap.abs() > swing) {
      final balanced = _tryAddPickToBalance(
        offered: offered,
        asked: askedAssets,
        swing: swing,
        ownTeamAbbreviation: ownTeamAbbreviation,
        aiTeamAbbreviation: aiTeam.team.abbreviation,
        pickOwnershipOverrides: pickOwnershipOverrides,
        allTeamAbbreviations: allTeamAbbreviations,
        draftSeasons: draftSeasons,
      );
      if (balanced == null) continue;
      offered = balanced.offered;
      askedAssets = balanced.asked;
      gap = totalTradeValue(offered) - totalTradeValue(askedAssets);
    }
    if (gap.abs() > swing) continue;

    return TradeOffer(
      id: _offerId(aiTeam, offered, askedAssets),
      offeringTeamAbbreviation: aiTeam.team.abbreviation,
      offeredToYou: offered,
      askedFromYou: askedAssets,
      character: _characterFor(
        offered: offered,
        asked: askedAssets,
        gap: gap,
        swing: swing,
      ),
    );
  }
  return null;
}

/// Builds the one Trade Board slot guaranteed to be a real 2-for-2 trade
/// that also involves a draft pick, whenever [forcedTarget] (the GM's own
/// trade-block player) is set -- a direct GM ask (2026-08-19): "I want to
/// see at least one trade that's a 2:2 and involved a draft pick." Every
/// other slot's pick usage stays purely opportunistic
/// ([_tryAddPickToBalance], only added when the value gap genuinely needs
/// one) -- this is the one exception, sweetening the deal with a pick
/// ([_forceAddPick]) even when the 2 players alone would already clear
/// [swing] on their own, specifically so the guarantee doesn't depend on
/// the value math happening to need one.
///
/// `null` under the same real conditions [_tryBuildOffer] can already
/// fail for -- not enough distinct players on either side, or no legal
/// value match within [swing] even with a pick added. The "guarantee" is
/// "try hard for exactly this shape," not "break the trade math to force
/// one" -- the caller falls back to the ordinary [_tryBuildOffer] shape
/// when this returns `null`.
TradeOffer? _tryBuildGuaranteedTradeBlockPickOffer(
  Random random, {
  required AiTeamRoster aiTeam,
  required List<Player> ownActive,
  required Player forcedTarget,
  required String ownTeamAbbreviation,
  required FuturePickOwnershipOverrides pickOwnershipOverrides,
  required List<String> allTeamAbbreviations,
  required List<int> draftSeasons,
}) {
  final aiActive = [
    for (final m in aiTeam.roster)
      if (m.status == RosterStatus.active) m.player,
  ];
  if (aiActive.length < 2) return null;
  final ownOthers = [
    for (final p in ownActive)
      if (p.id != forcedTarget.id) p,
  ];
  if (ownOthers.isEmpty) return null;

  final management = aiTeam.coach.stats.management;
  final swing = tradeSwing(management);

  const kMaxAttempts = 6;
  for (var attempt = 0; attempt < kMaxAttempts; attempt++) {
    final second = ownOthers[random.nextInt(ownOthers.length)];
    final asked = [forcedTarget, second];
    final askedValue = asked.fold(
      0,
      (s, p) => s + PlayerTradeAsset(p).tradeValue,
    );

    final offeredPlayers = _closestCombo(aiActive, 2, askedValue);
    final offered = <TradeAsset>[
      for (final p in offeredPlayers) PlayerTradeAsset(p),
    ];
    final askedAssets = <TradeAsset>[
      for (final p in asked) PlayerTradeAsset(p),
    ];

    final withPick = _forceAddPick(
      offered: offered,
      asked: askedAssets,
      swing: swing,
      ownTeamAbbreviation: ownTeamAbbreviation,
      aiTeamAbbreviation: aiTeam.team.abbreviation,
      pickOwnershipOverrides: pickOwnershipOverrides,
      allTeamAbbreviations: allTeamAbbreviations,
      draftSeasons: draftSeasons,
    );
    if (withPick == null) continue;

    final gap =
        totalTradeValue(withPick.offered) - totalTradeValue(withPick.asked);
    if (gap.abs() > swing) continue;

    return TradeOffer(
      id: _offerId(aiTeam, withPick.offered, withPick.asked),
      offeringTeamAbbreviation: aiTeam.team.abbreviation,
      offeredToYou: withPick.offered,
      askedFromYou: withPick.asked,
      character: _characterFor(
        offered: withPick.offered,
        asked: withPick.asked,
        gap: gap,
        swing: swing,
      ),
    );
  }
  return null;
}

/// Unconditionally sweetens [offered]/[asked] with one *real,
/// currently-owned* pick, unlike [_tryAddPickToBalance]'s "only if the
/// value gap needs it" -- prefers sweetening the AI's own [offered] side
/// first (the friendlier "they threw in a pick" framing, and doesn't cost
/// the GM anything extra), falling back to the GM's [ownTeamAbbreviation]
/// side only if the AI team has no tradeable pick that keeps the result
/// within [swing]. `null` if neither side has one that works -- e.g. an
/// AI team that already traded away every pick it owns this season.
({List<TradeAsset> offered, List<TradeAsset> asked})? _forceAddPick({
  required List<TradeAsset> offered,
  required List<TradeAsset> asked,
  required int swing,
  required String ownTeamAbbreviation,
  required String aiTeamAbbreviation,
  required FuturePickOwnershipOverrides pickOwnershipOverrides,
  required List<String> allTeamAbbreviations,
  required List<int> draftSeasons,
}) {
  for (final pick in picksOwnedBy(
    aiTeamAbbreviation,
    pickOwnershipOverrides,
    allTeamAbbreviations,
    draftSeasons: draftSeasons,
    rounds: kDraftRounds,
  )) {
    final candidate = [...offered, pick];
    if ((totalTradeValue(candidate) - totalTradeValue(asked)).abs() <= swing) {
      return (offered: candidate, asked: asked);
    }
  }
  for (final pick in picksOwnedBy(
    ownTeamAbbreviation,
    pickOwnershipOverrides,
    allTeamAbbreviations,
    draftSeasons: draftSeasons,
    rounds: kDraftRounds,
  )) {
    final candidate = [...asked, pick];
    if ((totalTradeValue(offered) - totalTradeValue(candidate)).abs() <=
        swing) {
      return (offered: offered, asked: candidate);
    }
  }
  return null;
}

/// Tries adding one *real, currently-owned* pick to whichever side of the
/// ledger is short, same "one pick, whichever side needs it"
/// simplification `trading-and-hidden-gems-notes.md` settled on -- covers
/// every canonical case worked out this session without needing a
/// literal pick-for-pick swap on both sides at once. Only ever offers a
/// pick the sweetening side genuinely still holds
/// (`pick_ownership.dart`'s `picksOwnedBy`, 2026-08-19) -- a team that
/// already traded its own natal pick away earlier this season can't
/// offer it again, though it can offer forward anything it picked up in
/// an earlier trade.
({List<TradeAsset> offered, List<TradeAsset> asked})? _tryAddPickToBalance({
  required List<TradeAsset> offered,
  required List<TradeAsset> asked,
  required int swing,
  required String ownTeamAbbreviation,
  required String aiTeamAbbreviation,
  required FuturePickOwnershipOverrides pickOwnershipOverrides,
  required List<String> allTeamAbbreviations,
  required List<int> draftSeasons,
}) {
  final gap = totalTradeValue(offered) - totalTradeValue(asked);
  if (gap < 0) {
    // The AI's side is short -- it sweetens its own offer with a pick it
    // actually currently holds.
    for (final pick in picksOwnedBy(
      aiTeamAbbreviation,
      pickOwnershipOverrides,
      allTeamAbbreviations,
      draftSeasons: draftSeasons,
      rounds: kDraftRounds,
    )) {
      final candidate = [...offered, pick];
      if ((totalTradeValue(candidate) - totalTradeValue(asked)).abs() <=
          swing) {
        return (offered: candidate, asked: asked);
      }
    }
  } else if (gap > 0) {
    // The AI is asking for less than it's offering -- it asks the GM to
    // send one of the GM's own currently-held picks back too, exactly
    // the "pick-swap" shape Case B worked out.
    for (final pick in picksOwnedBy(
      ownTeamAbbreviation,
      pickOwnershipOverrides,
      allTeamAbbreviations,
      draftSeasons: draftSeasons,
      rounds: kDraftRounds,
    )) {
      final candidate = [...asked, pick];
      if ((totalTradeValue(offered) - totalTradeValue(candidate)).abs() <=
          swing) {
        return (offered: offered, asked: candidate);
      }
    }
  }
  return null;
}

/// Builds [kConsolidationOfferSlotIndex]'s one guaranteed-attempt "consolidate
/// the bench" offer -- the GM's own weakest 2 active players (by
/// [PlayerTradeAsset.tradeValue], deliberately the bottom of the roster
/// rather than a random 2, so it always reads as trading bench depth,
/// never risking the GM's best players) for whichever 1 of [aiTeam]'s
/// own players lands closest in combined value ([_closestCombo]) -- a
/// direct GM ask
/// (2026-08-21): "I have a super deep bench, but I want to transition
/// that to a better player." Same value-balancing fallback
/// ([_tryAddPickToBalance]) every other slot already uses when the raw
/// player values alone don't land within [tradeSwing] of each other.
///
/// `null` under the same real conditions every other builder can already
/// fail for -- fewer than 2 active players to offer, no AI player (or
/// AI-player-plus-pick) combination lands close enough in value. Not
/// tied to [Franchise.tradeBlockPlayerId] at all -- this slot always
/// tries, independent of whether (or who) the GM has flagged.
TradeOffer? _tryBuildConsolidationOffer({
  required AiTeamRoster aiTeam,
  required List<Player> ownActive,
  required String ownTeamAbbreviation,
  required FuturePickOwnershipOverrides pickOwnershipOverrides,
  required List<String> allTeamAbbreviations,
  required List<int> draftSeasons,
}) {
  if (ownActive.length < 2) return null;
  final aiActive = [
    for (final m in aiTeam.roster)
      if (m.status == RosterStatus.active) m.player,
  ];
  if (aiActive.isEmpty) return null;

  final management = aiTeam.coach.stats.management;
  final swing = tradeSwing(management);

  final weakestTwo = [...ownActive]
    ..sort(
      (a, b) => PlayerTradeAsset(
        a,
      ).tradeValue.compareTo(PlayerTradeAsset(b).tradeValue),
    );
  final asked = weakestTwo.take(2).toList();
  final askedValue = asked.fold(
    0,
    (sum, p) => sum + PlayerTradeAsset(p).tradeValue,
  );

  final offeredPlayer = _closestCombo(aiActive, 1, askedValue).single;
  var offered = <TradeAsset>[PlayerTradeAsset(offeredPlayer)];
  var askedAssets = <TradeAsset>[for (final p in asked) PlayerTradeAsset(p)];

  var gap = totalTradeValue(offered) - totalTradeValue(askedAssets);
  if (gap.abs() > swing) {
    final balanced = _tryAddPickToBalance(
      offered: offered,
      asked: askedAssets,
      swing: swing,
      ownTeamAbbreviation: ownTeamAbbreviation,
      aiTeamAbbreviation: aiTeam.team.abbreviation,
      pickOwnershipOverrides: pickOwnershipOverrides,
      allTeamAbbreviations: allTeamAbbreviations,
      draftSeasons: draftSeasons,
    );
    if (balanced == null) return null;
    offered = balanced.offered;
    askedAssets = balanced.asked;
    gap = totalTradeValue(offered) - totalTradeValue(askedAssets);
  }
  if (gap.abs() > swing) return null;

  return TradeOffer(
    id: _offerId(aiTeam, offered, askedAssets),
    offeringTeamAbbreviation: aiTeam.team.abbreviation,
    offeredToYou: offered,
    askedFromYou: askedAssets,
    character: _characterFor(
      offered: offered,
      asked: askedAssets,
      gap: gap,
      swing: swing,
    ),
  );
}

/// How much wider than the ordinary [tradeSwing] a
/// [_tryBuildSellForPicksOffer] deal is allowed to run -- a real,
/// below-market discount, not a bug to route around. Even the best 2
/// real picks combined ([kDraftPickTradeValue] rounds 1+2, 620) sit
/// below almost any real active player's value (a fresh 12-player
/// starting roster ranges ~700-1000), so gating this shape at the same
/// tight tolerance ordinary trades use would make it nearly unreachable
/// -- and the GM's own framing for this whole feature already expects a
/// discount: "the other team recognizes that you're trying to sell off
/// players, so they'll make offers" (2026-08-23) describes an AI team
/// taking advantage of a desperate seller, not a fair-value swap. Wide
/// enough that most of a real roster's weaker-to-middling players are
/// reachable at any coach, while a genuine star still generally isn't
/// (own doc comment's own worked numbers).
const kSellForPicksExtraTolerance = 250;

/// Builds one of [generateTradeOffers]' oversized-roster relief slots --
/// pure "picks for a player," the other real shape a direct GM ask
/// (2026-08-23) called for: "other teams are more likely to offer you
/// picks for players." Goes out for *only* real picks [aiTeam] currently
/// owns -- one if that alone lands within [tradeSwing] (widened by
/// [kSellForPicksExtraTolerance] -- see that constant's own doc
/// comment), the closest-value pair of two otherwise.
///
/// Tries the GM's own active players from weakest upward (same
/// deliberate "bottom of the roster first" posture
/// [_tryBuildConsolidationOffer] uses), not just the single weakest, so
/// a genuinely bottom-of-the-roster player isn't the only one ever
/// considered. `null` if nothing in the first few candidates works
/// either -- e.g. an AI team down to a single low pick, or already
/// traded every pick it had.
TradeOffer? _tryBuildSellForPicksOffer(
  Random random, {
  required AiTeamRoster aiTeam,
  required List<Player> ownActive,
  required String ownTeamAbbreviation,
  required FuturePickOwnershipOverrides pickOwnershipOverrides,
  required List<String> allTeamAbbreviations,
  required List<int> draftSeasons,
}) {
  if (ownActive.isEmpty) return null;

  final ownedPicks = picksOwnedBy(
    aiTeam.team.abbreviation,
    pickOwnershipOverrides,
    allTeamAbbreviations,
    draftSeasons: draftSeasons,
    rounds: kDraftRounds,
  );
  if (ownedPicks.isEmpty) return null;

  final byValue = [...ownActive]
    ..sort(
      (a, b) => PlayerTradeAsset(
        a,
      ).tradeValue.compareTo(PlayerTradeAsset(b).tradeValue),
    );
  const kMaxCandidates = 6;

  for (final target in byValue.take(kMaxCandidates)) {
    final offer = _trySellPlayerForPicks(
      random,
      aiTeam: aiTeam,
      target: target,
      ownedPicks: ownedPicks,
    );
    if (offer != null) return offer;
  }
  return null;
}

/// One [target] player, out for only real picks [ownedPicks] holds --
/// the actual per-player matching [_tryBuildSellForPicksOffer] (any of
/// the GM's own weaker players) and `assistantGmBrokeredOffers` (one
/// specific named player) both reuse. A single pick close enough on its
/// own (tried in a shuffled order so the same pick isn't always offered
/// when several would work), or the closest-value pair of two
/// otherwise, both within [tradeSwing] widened by
/// [kSellForPicksExtraTolerance]. `null` if neither works.
TradeOffer? _trySellPlayerForPicks(
  Random random, {
  required AiTeamRoster aiTeam,
  required Player target,
  required List<TradeAsset> ownedPicks,
}) {
  final management = aiTeam.coach.stats.management;
  final swing = tradeSwing(management);
  final tolerance = swing + kSellForPicksExtraTolerance;

  final askedAssets = <TradeAsset>[PlayerTradeAsset(target)];
  final targetValue = PlayerTradeAsset(target).tradeValue;

  final shuffledPicks = List<TradeAsset>.of(ownedPicks)..shuffle(random);
  for (final pick in shuffledPicks) {
    final gap = pick.tradeValue - targetValue;
    if (gap.abs() <= tolerance) {
      return TradeOffer(
        id: _offerId(aiTeam, [pick], askedAssets),
        offeringTeamAbbreviation: aiTeam.team.abbreviation,
        offeredToYou: [pick],
        askedFromYou: askedAssets,
        character: _characterFor(
          offered: [pick],
          asked: askedAssets,
          gap: gap,
          swing: swing,
        ),
      );
    }
  }
  if (ownedPicks.length < 2) return null;

  // Otherwise the closest-value pair of 2 distinct owned picks.
  TradeAsset? bestFirst;
  TradeAsset? bestSecond;
  var bestDiff = 1 << 30;
  for (var i = 0; i < ownedPicks.length; i++) {
    for (var j = i + 1; j < ownedPicks.length; j++) {
      final sum = ownedPicks[i].tradeValue + ownedPicks[j].tradeValue;
      final diff = (sum - targetValue).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        bestFirst = ownedPicks[i];
        bestSecond = ownedPicks[j];
      }
    }
  }
  if (bestFirst == null || bestSecond == null || bestDiff > tolerance) {
    return null;
  }
  final offered = [bestFirst, bestSecond];
  final gap = totalTradeValue(offered) - targetValue;
  return TradeOffer(
    id: _offerId(aiTeam, offered, askedAssets),
    offeringTeamAbbreviation: aiTeam.team.abbreviation,
    offeredToYou: offered,
    askedFromYou: askedAssets,
    character: _characterFor(
      offered: offered,
      asked: askedAssets,
      gap: gap,
      swing: swing,
    ),
  );
}

/// [count] distinct players drawn from [pool] at random.
List<Player> _randomDistinct(Random random, List<Player> pool, int count) {
  final shuffled = List<Player>.of(pool)..shuffle(random);
  return shuffled.take(count).toList();
}

/// The [count]-player combination from [pool] whose combined
/// [PlayerTradeAsset.tradeValue] lands closest to [targetValue] -- a
/// brute-force search (at most a roster's worth of single players, or
/// pairs of one, both cheap at a 12-player active roster) rather than a
/// random guess, so generated offers actually read as sensible trades
/// instead of wildly mismatched ones the pick-balancing step then has to
/// paper over.
List<Player> _closestCombo(List<Player> pool, int count, int targetValue) {
  if (count == 1) {
    var best = pool.first;
    var bestDiff = (PlayerTradeAsset(best).tradeValue - targetValue).abs();
    for (final p in pool.skip(1)) {
      final diff = (PlayerTradeAsset(p).tradeValue - targetValue).abs();
      if (diff < bestDiff) {
        best = p;
        bestDiff = diff;
      }
    }
    return [best];
  }

  // count == 2 -- every distinct pair, cheap at a 12-player roster.
  List<Player>? best;
  var bestDiff = 1 << 30;
  for (var i = 0; i < pool.length; i++) {
    for (var j = i + 1; j < pool.length; j++) {
      final sum =
          PlayerTradeAsset(pool[i]).tradeValue +
          PlayerTradeAsset(pool[j]).tradeValue;
      final diff = (sum - targetValue).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        best = [pool[i], pool[j]];
      }
    }
  }
  return best ?? pool.take(2).toList();
}

/// A stable id for the exact (team, assets) combination this offer
/// resolved to -- what [Franchise.resolvedTradeOfferIds] matches against
/// so a regenerated-but-identical offer doesn't reappear after being
/// accepted or declined this turn. Player/pick identity only (not
/// [TradeOfferCharacter], which is derived, not part of the offer's own
/// identity).
String _offerId(
  AiTeamRoster aiTeam,
  List<TradeAsset> offered,
  List<TradeAsset> asked,
) {
  String assetKey(TradeAsset asset) => switch (asset) {
    PlayerTradeAsset(:final player) => 'p:${player.id}',
    PickTradeAsset(
      :final draftSeason,
      :final round,
      :final originalTeamAbbreviation,
    ) =>
      'r:$draftSeason:$round:$originalTeamAbbreviation',
  };
  final offeredKey = offered.map(assetKey).toList()..sort();
  final askedKey = asked.map(assetKey).toList()..sort();
  return '${aiTeam.team.abbreviation}|${offeredKey.join(",")}|${askedKey.join(",")}';
}

TradeOfferCharacter _characterFor({
  required List<TradeAsset> offered,
  required List<TradeAsset> asked,
  required int gap,
  required int swing,
}) {
  if (swing > 0 && gap.abs() >= (swing * 0.75).round()) {
    return TradeOfferCharacter.aggressive;
  }

  final offeredAges = [
    for (final a in offered)
      if (a is PlayerTradeAsset) a.player.age,
  ];
  final askedAges = [
    for (final a in asked)
      if (a is PlayerTradeAsset) a.player.age,
  ];
  if (offeredAges.isNotEmpty && askedAges.isNotEmpty) {
    final offeredAvgAge =
        offeredAges.reduce((a, b) => a + b) / offeredAges.length;
    final askedAvgAge = askedAges.reduce((a, b) => a + b) / askedAges.length;
    if (askedAvgAge - offeredAvgAge >= _kCharacterAgeGapThreshold) {
      return TradeOfferCharacter.rebuilding;
    }
    if (offeredAvgAge - askedAvgAge >= _kCharacterAgeGapThreshold) {
      return TradeOfferCharacter.winNow;
    }
  }
  return TradeOfferCharacter.value;
}
