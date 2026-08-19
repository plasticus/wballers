import 'dart:math';

import '../../franchise/domain/franchise.dart';
import '../../league/domain/ai_team_roster.dart';
import '../../player/domain/player.dart';
import '../../roster/domain/roster_status.dart';
import '../domain/trade_asset.dart';
import '../domain/trade_offer.dart';
import '../domain/trade_value.dart';

/// Seed offset for the Trade Board's own random stream -- keeps it off
/// every other per-season generator's stream. Next free number after
/// `draft_advancer.dart`'s `kDraftFinalizeSeedOffset` (21).
const kTradeOfferSeedOffset = 22;

/// How many offers the Trade Board shows at once
/// (`trading-and-hidden-gems-notes.md`).
const kTradeOfferCount = 5;

/// Of [kTradeOfferCount] offers, how many should try to involve
/// [Franchise.tradeBlockPlayerId] when one is set -- "the trade board
/// should TRY to have 3 (out of the 5) involve that player," a direct GM
/// ask. "Try" because there's no guarantee some AI team's own roster
/// happens to have a matching-value asset to offer for her.
const kTradeBlockTargetedOfferCount = 3;

/// A years-of-age gap past which an offer's headline players read as a
/// deliberate youth-for-experience swap, for [TradeOfferCharacter]
/// labeling purposes only -- see that enum's own doc comment on why this
/// is a description of what resulted, not a target the generator aims
/// for.
const _kCharacterAgeGapThreshold = 4;

/// The 5 real trade offers on the board right now -- deterministic for a
/// given [franchise] state (same "regenerate fresh every time, nothing
/// to persist" posture `player_market_preview_generator.dart` already
/// uses for its own preview tabs), seeded off
/// [Franchise.seasonSeed]/[kTradeOfferSeedOffset]/[SeasonProgress.nextGameDayIndex]
/// so the same 5 offers stay stable for as long as the GM's still on the
/// same game day, and change the moment a new one is advanced into.
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
/// headcount, so accepting an offer can never leave either roster over
/// or under [kActiveRosterSize] active players by surprise (see
/// `current_franchise_provider.dart`'s `acceptTradeOffer`).
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

  final offers = <TradeOffer>[];
  for (var slot = 0; slot < kTradeOfferCount; slot++) {
    final wantsTradeBlockPlayer =
        tradeBlockPlayer != null && slot < kTradeBlockTargetedOfferCount;
    final aiTeam = aiTeams[slot % aiTeams.length];
    final offer = _tryBuildOffer(
      random,
      aiTeam: aiTeam,
      ownActive: ownActive,
      forcedTarget: wantsTradeBlockPlayer ? tradeBlockPlayer : null,
      slotIndex: slot,
    );
    if (offer != null) offers.add(offer);
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
    final askedValue = asked.fold(0, (s, p) => s + p.ratings.skillPoints);

    final offeredPlayers = _closestCombo(aiActive, wantCount, askedValue);
    var offered = <TradeAsset>[for (final p in offeredPlayers) PlayerTradeAsset(p)];
    var askedAssets = <TradeAsset>[for (final p in asked) PlayerTradeAsset(p)];

    var gap = totalTradeValue(offered) - totalTradeValue(askedAssets);
    if (gap.abs() > swing) {
      final balanced = _tryAddPickToBalance(
        offered: offered,
        asked: askedAssets,
        swing: swing,
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

/// Tries adding one pick (largest first) to whichever side of the ledger
/// is short, same "one pick, whichever side needs it" simplification
/// `trading-and-hidden-gems-notes.md` settled on -- covers every
/// canonical case worked out this session without needing a literal
/// pick-for-pick swap on both sides at once.
({List<TradeAsset> offered, List<TradeAsset> asked})? _tryAddPickToBalance({
  required List<TradeAsset> offered,
  required List<TradeAsset> asked,
  required int swing,
}) {
  final gap = totalTradeValue(offered) - totalTradeValue(asked);
  for (final round in [1, 2, 3]) {
    if (gap < 0) {
      // The AI's side is short -- it sweetens its own offer.
      final candidate = [...offered, PickTradeAsset(round)];
      if ((totalTradeValue(candidate) - totalTradeValue(asked)).abs() <=
          swing) {
        return (offered: candidate, asked: asked);
      }
    } else if (gap > 0) {
      // The AI is asking for less than it's offering -- it asks the GM
      // to send a pick back too, exactly the "pick-swap" shape Case B
      // worked out.
      final candidate = [...asked, PickTradeAsset(round)];
      if ((totalTradeValue(offered) - totalTradeValue(candidate)).abs() <=
          swing) {
        return (offered: offered, asked: candidate);
      }
    }
  }
  return null;
}

/// [count] distinct players drawn from [pool] at random.
List<Player> _randomDistinct(Random random, List<Player> pool, int count) {
  final shuffled = List<Player>.of(pool)..shuffle(random);
  return shuffled.take(count).toList();
}

/// The [count]-player combination from [pool] whose combined
/// `skillPoints` lands closest to [targetValue] -- a brute-force search
/// (at most a roster's worth of single players, or pairs of one, both
/// cheap at a 12-player active roster) rather than a random guess, so
/// generated offers actually read as sensible trades instead of wildly
/// mismatched ones the pick-balancing step then has to paper over.
List<Player> _closestCombo(List<Player> pool, int count, int targetValue) {
  if (count == 1) {
    var best = pool.first;
    var bestDiff = (best.ratings.skillPoints - targetValue).abs();
    for (final p in pool.skip(1)) {
      final diff = (p.ratings.skillPoints - targetValue).abs();
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
      final sum = pool[i].ratings.skillPoints + pool[j].ratings.skillPoints;
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
    PickTradeAsset(:final round) => 'r:$round',
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
    final offeredAvgAge = offeredAges.reduce((a, b) => a + b) / offeredAges.length;
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
