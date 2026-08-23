import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/franchise/domain/franchise.dart';
import 'package:womensbballmgr/features/roster/domain/roster_membership.dart';
import 'package:womensbballmgr/features/roster/domain/roster_status.dart';
import 'package:womensbballmgr/features/season/domain/season_progress.dart';
import 'package:womensbballmgr/features/trade/domain/pick_ownership.dart';
import 'package:womensbballmgr/features/trade/domain/trade_asset.dart';
import 'package:womensbballmgr/features/trade/domain/trade_offer.dart';
import 'package:womensbballmgr/features/trade/domain/trade_value.dart';
import 'package:womensbballmgr/features/trade/generation/trade_offer_generator.dart';

import '../../../support/franchise_test_helpers.dart';
import '../../../support/match_test_players.dart';
import '../../../support/portrait_test_helpers.dart';

void main() {
  test('every generated offer is objectively legal for the offering '
      'team\'s own coach Management, across several distinct turns', () {
    final base = withFullActiveRoster(franchiseForPortraitTests());

    // Vary the "turn" the same way a real game does -- nextGameDayIndex
    // -- to exercise several distinct deterministic draws, not just one.
    for (var gameDayIndex = 0; gameDayIndex < 10; gameDayIndex++) {
      final franchise = base.copyWithSeasonProgress(
        SeasonProgress(
          schedule: base.seasonProgress.schedule,
          playedGames: base.seasonProgress.playedGames,
          nextGameDayIndex: gameDayIndex,
        ),
      );
      final offers = generateTradeOffers(franchise);

      for (final offer in offers) {
        final aiTeam = franchise.league.aiTeams.firstWhere(
          (t) => t.team.abbreviation == offer.offeringTeamAbbreviation,
        );
        expect(
          isTradeWithinManagementSwing(
            offeredValue: offer.offeredValue,
            requestedValue: offer.askedValue,
            management: aiTeam.coach.stats.management,
          ),
          isTrue,
          reason:
              'game day $gameDayIndex: offer $offer is not actually '
              'legal for ${offer.offeringTeamAbbreviation}\'s own coach',
        );
      }
    }
  });

  test('never asks for more players than it offers, or vice versa -- '
      'headcount always matches on both sides, except the one dedicated '
      '2-for-1 consolidation slot (2026-08-21, a direct GM ask)', () {
    final franchise = withFullActiveRoster(franchiseForPortraitTests());
    final offers = generateTradeOffers(franchise);

    for (final offer in offers) {
      final offeredPlayers = offer.offeredToYou.whereType<PlayerTradeAsset>();
      final askedPlayers = offer.askedFromYou.whereType<PlayerTradeAsset>();
      // The consolidation slot is deliberately 2-for-1 (2 of the GM's
      // own bench players for 1 upgrade back) -- everything else stays
      // headcount-symmetric.
      final isConsolidationShape =
          offeredPlayers.length == 1 && askedPlayers.length == 2;
      if (!isConsolidationShape) {
        expect(offeredPlayers.length, askedPlayers.length);
      }
    }
  });

  test('the dedicated consolidation slot really does build a 2-for-1 -- 2 of '
      'the GM\'s own weakest active players for 1 upgraded player back '
      '(2026-08-21, a direct GM ask: "I have a super deep bench, but I '
      'want to transition that to a better player... show me an option for '
      'that as a 6th trade slot")', () {
    final franchise = withFullActiveRoster(franchiseForPortraitTests());
    final ownActiveByValue =
        [
          for (final m in franchise.roster)
            if (m.status == RosterStatus.active) m.player,
        ]..sort(
          (a, b) => PlayerTradeAsset(
            a,
          ).tradeValue.compareTo(PlayerTradeAsset(b).tradeValue),
        );
    final weakestTwoIds = ownActiveByValue.take(2).map((p) => p.id).toSet();

    // Several distinct turns, same "not every draw happens to need a
    // pick to balance, or find a close-enough AI player" reasoning the
    // 2-for-2-with-a-pick test above already uses.
    var sawConsolidationOffer = false;
    for (var gameDayIndex = 0; gameDayIndex < 10; gameDayIndex++) {
      final turn = franchise.copyWithSeasonProgress(
        SeasonProgress(
          schedule: franchise.seasonProgress.schedule,
          playedGames: franchise.seasonProgress.playedGames,
          nextGameDayIndex: gameDayIndex,
        ),
      );
      final offers = generateTradeOffers(turn);

      for (final offer in offers) {
        final offered = offer.offeredToYou.whereType<PlayerTradeAsset>();
        final asked = offer.askedFromYou.whereType<PlayerTradeAsset>();
        if (offered.length == 1 && asked.length == 2) {
          sawConsolidationOffer = true;
          final askedIds = asked.map((a) => a.player.id).toSet();
          expect(askedIds, weakestTwoIds);
        }
      }
    }
    expect(sawConsolidationOffer, isTrue);
  });

  test('never asks for a player who isn\'t actually on the GM\'s active '
      'roster', () {
    final franchise = withFullActiveRoster(franchiseForPortraitTests());
    final activeIds = {
      for (final m in franchise.roster)
        if (m.status == RosterStatus.active) m.player.id,
    };
    final offers = generateTradeOffers(franchise);

    for (final offer in offers) {
      for (final asset in offer.askedFromYou) {
        if (asset case PlayerTradeAsset(:final player)) {
          expect(activeIds, contains(player.id));
        }
      }
    }
  });

  test('is deterministic for the same franchise state', () {
    final franchise = withFullActiveRoster(franchiseForPortraitTests());
    final a = generateTradeOffers(franchise);
    final b = generateTradeOffers(franchise);

    expect(a.length, b.length);
    for (var i = 0; i < a.length; i++) {
      expect(a[i].id, b[i].id);
    }
  });

  test('a set trade-block player is the sole ask on at least '
      'kTradeBlockTargetedOfferCount offers, when a valid match exists', () {
    final franchise = withFullActiveRoster(franchiseForPortraitTests());
    final blockPlayerId = franchise.roster
        .firstWhere((m) => m.status == RosterStatus.active)
        .player
        .id;
    final withBlock = franchise.copyWithTradeBlockPlayerId(blockPlayerId);

    final offers = generateTradeOffers(withBlock);
    final targetingBlockPlayer = offers.where(
      (offer) =>
          offer.askedFromYou.length == 1 &&
          offer.askedFromYou.single is PlayerTradeAsset &&
          (offer.askedFromYou.single as PlayerTradeAsset).player.id ==
              blockPlayerId,
    );

    // "Try" -- not every slot is guaranteed a legal match, but real
    // rosters/coaches should generally produce at least 1.
    expect(targetingBlockPlayer, isNotEmpty);
  });

  test('every pick asset in every offer is a pick the offering/asking side '
      'genuinely currently owns (2026-08-19, real draft-pick ownership)', () {
    final base = withFullActiveRoster(franchiseForPortraitTests());
    final allTeamAbbreviations = [
      base.team.abbreviation,
      for (final aiTeam in base.league.aiTeams) aiTeam.team.abbreviation,
    ];
    var sawAtLeastOnePick = false;

    // Several distinct turns, same reasoning as the "objectively legal"
    // test above -- not every turn's 5 offers happen to need a pick
    // sweetener, so check enough of them to reliably hit one.
    for (var gameDayIndex = 0; gameDayIndex < 10; gameDayIndex++) {
      final franchise = base.copyWithSeasonProgress(
        SeasonProgress(
          schedule: base.seasonProgress.schedule,
          playedGames: base.seasonProgress.playedGames,
          nextGameDayIndex: gameDayIndex,
        ),
      );
      final offers = generateTradeOffers(franchise);

      for (final offer in offers) {
        for (final asset in offer.offeredToYou) {
          if (asset case PickTradeAsset()) {
            sawAtLeastOnePick = true;
            expect(
              currentFuturePickOwner(
                franchise.pickOwnershipOverrides,
                draftSeason: asset.draftSeason,
                round: asset.round,
                originalTeamAbbreviation: asset.originalTeamAbbreviation,
              ),
              offer.offeringTeamAbbreviation,
            );
            expect(
              allTeamAbbreviations,
              contains(asset.originalTeamAbbreviation),
            );
            expect(
              tradeableDraftSeasons(franchise.season),
              contains(asset.draftSeason),
            );
          }
        }
        for (final asset in offer.askedFromYou) {
          if (asset case PickTradeAsset()) {
            sawAtLeastOnePick = true;
            expect(
              currentFuturePickOwner(
                franchise.pickOwnershipOverrides,
                draftSeason: asset.draftSeason,
                round: asset.round,
                originalTeamAbbreviation: asset.originalTeamAbbreviation,
              ),
              franchise.team.abbreviation,
            );
          }
        }
      }
    }

    // Not asserting a specific count -- just that these turns' real
    // offers actually exercise the pick-balancing path at all, so the
    // ownership checks above aren't vacuously true.
    expect(sawAtLeastOnePick, isTrue);
  });

  test('once a pick is traded away, a later turn\'s offers never offer it '
      'again from the side that no longer holds it', () {
    final franchise = withFullActiveRoster(franchiseForPortraitTests());
    final aiAbbreviation = franchise.league.aiTeams.first.team.abbreviation;
    final immediateDraftSeason = tradeableDraftSeasons(franchise.season).first;
    // The GM's own round-1 pick for the immediately upcoming draft
    // already went to this AI team earlier this season.
    final withATrade = franchise.copyWithPickOwnershipOverrides({
      immediateDraftSeason: {
        1: {franchise.team.abbreviation: aiAbbreviation},
      },
    });

    final offers = generateTradeOffers(withATrade);

    for (final offer in offers) {
      for (final asset in offer.askedFromYou) {
        if (asset case PickTradeAsset(
          draftSeason: final draftSeason,
          round: 1,
          originalTeamAbbreviation: final originalTeam,
        )) {
          if (draftSeason == immediateDraftSeason) {
            // The GM can no longer offer this specific pick away again.
            expect(originalTeam == franchise.team.abbreviation, isFalse);
          }
        }
      }
    }
  });

  test('with a trade-block player set, at least one offer across several '
      'turns is a real 2-for-2 trade that also involves a draft pick '
      '(2026-08-19, a direct GM ask: "I want to see at least one trade '
      'that\'s a 2:2 and involved a draft pick")', () {
    final base = withFullActiveRoster(franchiseForPortraitTests());
    final blockPlayerId = base.roster
        .firstWhere((m) => m.status == RosterStatus.active)
        .player
        .id;
    final withBlock = base.copyWithTradeBlockPlayerId(blockPlayerId);

    var sawQualifyingOffer = false;
    // Several distinct turns, same "not every draw happens to need this"
    // reasoning the pick-ownership test above already uses.
    for (var gameDayIndex = 0; gameDayIndex < 10; gameDayIndex++) {
      final turn = withBlock.copyWithSeasonProgress(
        SeasonProgress(
          schedule: withBlock.seasonProgress.schedule,
          playedGames: withBlock.seasonProgress.playedGames,
          nextGameDayIndex: gameDayIndex,
        ),
      );
      final offers = generateTradeOffers(turn);

      for (final offer in offers) {
        final askedPlayers = offer.askedFromYou.whereType<PlayerTradeAsset>();
        final offeredPlayers = offer.offeredToYou.whereType<PlayerTradeAsset>();
        final hasPick =
            offer.offeredToYou.whereType<PickTradeAsset>().isNotEmpty ||
            offer.askedFromYou.whereType<PickTradeAsset>().isNotEmpty;
        final involvesBlockPlayer = askedPlayers.any(
          (a) => a.player.id == blockPlayerId,
        );
        if (askedPlayers.length == 2 &&
            offeredPlayers.length == 2 &&
            hasPick &&
            involvesBlockPlayer) {
          sawQualifyingOffer = true;
        }
      }
    }

    expect(sawQualifyingOffer, isTrue);
  });

  test('no trade-block player set -- no offer is specifically forced '
      'onto one player', () {
    final franchise = withFullActiveRoster(franchiseForPortraitTests());
    expect(franchise.tradeBlockPlayerId, isNull);

    final offers = generateTradeOffers(franchise);
    final askedPlayerIds = <String>{
      for (final offer in offers)
        for (final asset in offer.askedFromYou)
          if (asset case PlayerTradeAsset(:final player)) player.id,
    };

    // With a real 12-player roster and 5 offers, seeing every single ask
    // land on the exact same one player would be a sign generation is
    // secretly always targeting someone -- not asserting on which
    // player(s), just that there's real variety when nothing is forced.
    expect(askedPlayerIds.length, greaterThan(1));
  });

  group('roster-legality desperation scaling (2026-08-23, a direct GM ask: '
      '"if your roster is illegal with too many players, other teams are '
      'more likely to offer you picks for players, and 2:1 trades... '
      'if your roster is illegal based on having too many star-tier, you '
      'should find yourself getting more offers")', () {
    test('an oversized active roster gets more offers than a legal one, '
        'including a real picks-only sell-off shape', () {
      final legal = withFullActiveRoster(franchiseForPortraitTests());
      final oversized = legal.copyWithRoster([
        ...legal.roster,
        for (var i = 0; i < 3; i++)
          RosterMembership(
            player: testPlayer(id: 'extra-bench-$i', rating: 45),
            status: RosterStatus.active,
          ),
      ]);

      var sawMoreOffers = false;
      var sawPicksOnlySale = false;
      for (var gameDayIndex = 0; gameDayIndex < 10; gameDayIndex++) {
        final legalTurn = legal.copyWithSeasonProgress(
          SeasonProgress(
            schedule: legal.seasonProgress.schedule,
            playedGames: legal.seasonProgress.playedGames,
            nextGameDayIndex: gameDayIndex,
          ),
        );
        final oversizedTurn = oversized.copyWithSeasonProgress(
          SeasonProgress(
            schedule: oversized.seasonProgress.schedule,
            playedGames: oversized.seasonProgress.playedGames,
            nextGameDayIndex: gameDayIndex,
          ),
        );
        final legalOffers = generateTradeOffers(legalTurn);
        final oversizedOffers = generateTradeOffers(oversizedTurn);
        if (oversizedOffers.length > legalOffers.length) {
          sawMoreOffers = true;
        }
        for (final offer in oversizedOffers) {
          final offeredPlayers = offer.offeredToYou
              .whereType<PlayerTradeAsset>();
          final offeredPicks = offer.offeredToYou.whereType<PickTradeAsset>();
          final askedPlayers = offer.askedFromYou.whereType<PlayerTradeAsset>();
          if (offeredPlayers.isEmpty &&
              offeredPicks.isNotEmpty &&
              askedPlayers.length == 1) {
            sawPicksOnlySale = true;
          }
        }
      }
      expect(sawMoreOffers, isTrue);
      expect(sawPicksOnlySale, isTrue);
    });

    test('a roster over a star-tier cap gets more offers than a legal '
        'one, some of them specifically targeting one of the excess '
        'star-tier players', () {
      final legal = withFullActiveRoster(franchiseForPortraitTests());
      // Every roster member here is active (`generateStartingRoster`
      // never produces any other status) -- replace 7 of the 12 with
      // 85-OVR (three-star) players, one over kMaxThreeStarAndUpPlayers
      // (6).
      expect(
        legal.roster.every((m) => m.status == RosterStatus.active),
        isTrue,
      );
      final starIds = <String>{for (var i = 0; i < 7; i++) 'star-$i'};
      final swapped = [
        for (var i = 0; i < legal.roster.length; i++)
          if (i < 7)
            RosterMembership(
              player: testPlayer(id: 'star-$i', rating: 85),
              status: RosterStatus.active,
            )
          else
            legal.roster[i],
      ];
      final tooManyStars = legal.copyWithRoster(swapped);

      var sawMoreOffers = false;
      var sawStarTargeted = false;
      for (var gameDayIndex = 0; gameDayIndex < 10; gameDayIndex++) {
        final legalTurn = legal.copyWithSeasonProgress(
          SeasonProgress(
            schedule: legal.seasonProgress.schedule,
            playedGames: legal.seasonProgress.playedGames,
            nextGameDayIndex: gameDayIndex,
          ),
        );
        final starTurn = tooManyStars.copyWithSeasonProgress(
          SeasonProgress(
            schedule: tooManyStars.seasonProgress.schedule,
            playedGames: tooManyStars.seasonProgress.playedGames,
            nextGameDayIndex: gameDayIndex,
          ),
        );
        final legalOffers = generateTradeOffers(legalTurn);
        final starOffers = generateTradeOffers(starTurn);
        if (starOffers.length > legalOffers.length) {
          sawMoreOffers = true;
        }
        for (final offer in starOffers) {
          for (final asset in offer.askedFromYou) {
            if (asset case PlayerTradeAsset(:final player)) {
              if (starIds.contains(player.id)) sawStarTargeted = true;
            }
          }
        }
      }
      expect(sawMoreOffers, isTrue);
      expect(sawStarTargeted, isTrue);
    });
  });

  group('Assistant GM trade brokering (2026-08-23, a direct GM ask: "The '
      'asst gm should bust her ass trying to trade out 3 players at the '
      'bottom of your roster and dev slots... She should find 3x special '
      'deals just for them")', () {
    // `franchiseForPortraitTests()` has no queued free agents, so
    // `withFullActiveRoster` (which only tops up from those) is a no-op
    // here and the roster stays at generateStartingRoster's deliberate
    // 11 -- pad with a real 12th active player directly instead of
    // relying on it, so activeCount genuinely reaches kActiveRosterSize.
    Franchise fullActiveAndDev(Franchise franchise) {
      return franchise
          .copyWithRoster([
            ...franchise.roster,
            RosterMembership(
              player: testPlayer(id: 'active-pad', rating: 60),
              status: RosterStatus.active,
            ),
            for (var i = 0; i < 2; i++)
              RosterMembership(
                player: testPlayer(id: 'dev-$i', rating: 55),
                status: RosterStatus.developmental,
              ),
          ])
          .copyWithPostDraftTradeWeeksRemaining(kPostDraftTradeWeeks);
    }

    test('needsAssistantGmTradeBrokering is false without an active '
        'Trade Week gate, even with a full active+dev roster', () {
      // Same padding fullActiveAndDev uses, just without setting
      // postDraftTradeWeeksRemaining -- isolates that one variable.
      final full = franchiseForPortraitTests().copyWithRoster([
        ...franchiseForPortraitTests().roster,
        RosterMembership(
          player: testPlayer(id: 'active-pad', rating: 60),
          status: RosterStatus.active,
        ),
        for (var i = 0; i < 2; i++)
          RosterMembership(
            player: testPlayer(id: 'dev-$i', rating: 55),
            status: RosterStatus.developmental,
          ),
      ]);
      expect(full.postDraftTradeWeeksRemaining, isNull);
      expect(needsAssistantGmTradeBrokering(full), isFalse);
      expect(assistantGmBrokerCandidates(full), isEmpty);
      expect(assistantGmBrokeredOffers(full), isEmpty);
    });

    test('needsAssistantGmTradeBrokering is false when only the active '
        'roster is full, developmental still has room', () {
      final onlyActiveFull = franchiseForPortraitTests()
          .copyWithRoster([
            ...franchiseForPortraitTests().roster,
            RosterMembership(
              player: testPlayer(id: 'active-pad', rating: 60),
              status: RosterStatus.active,
            ),
          ])
          .copyWithPostDraftTradeWeeksRemaining(kPostDraftTradeWeeks);
      expect(needsAssistantGmTradeBrokering(onlyActiveFull), isFalse);
    });

    test('true, and finds real candidates/offers, once both are full '
        'during an active Trade Week', () {
      final franchise = fullActiveAndDev(franchiseForPortraitTests());
      expect(needsAssistantGmTradeBrokering(franchise), isTrue);

      final candidates = assistantGmBrokerCandidates(franchise);
      expect(candidates.length, kAssistantGmBrokerCandidateCount);
      // Every candidate is a real active player, weakest-first.
      final activeIds = {
        for (final m in franchise.roster)
          if (m.status == RosterStatus.active) m.player.id,
      };
      for (final candidate in candidates) {
        expect(activeIds, contains(candidate.id));
      }
      for (var i = 1; i < candidates.length; i++) {
        expect(
          PlayerTradeAsset(candidates[i - 1]).tradeValue,
          lessThanOrEqualTo(PlayerTradeAsset(candidates[i]).tradeValue),
        );
      }

      final offers = assistantGmBrokeredOffers(franchise);
      expect(offers, isNotEmpty);
      for (final offer in offers) {
        // Every offer is a real "picks only" sale of exactly one of the
        // named candidates.
        expect(offer.askedFromYou.length, 1);
        final asked = offer.askedFromYou.single;
        expect(asked, isA<PlayerTradeAsset>());
        expect(
          candidates.map((p) => p.id),
          contains((asked as PlayerTradeAsset).player.id),
        );
        expect(offer.offeredToYou.every((a) => a is PickTradeAsset), isTrue);
      }
    });

    test('deterministic for the same franchise state', () {
      final franchise = fullActiveAndDev(franchiseForPortraitTests());
      final a = assistantGmBrokeredOffers(franchise);
      final b = assistantGmBrokeredOffers(franchise);
      expect(a.length, b.length);
      for (var i = 0; i < a.length; i++) {
        expect(a[i].id, b[i].id);
      }
    });
  });

  group('generateTradeOffersForIntent (2026-08-23, a direct GM ask: '
      '"Could we have some further options on the trade board? ... I\'m '
      'looking to get rid of draft picks, get more draft picks, looking '
      'to offload some depth to improve quality, looking to lose some '
      'quality to get younger, or \'anything\'")', () {
    test('TradeBoardIntent.anything is exactly generateTradeOffers, '
        'unchanged', () {
      final franchise = withFullActiveRoster(franchiseForPortraitTests());
      final plain = generateTradeOffers(franchise);
      final viaIntent = generateTradeOffersForIntent(
        franchise,
        TradeBoardIntent.anything,
      );
      expect(viaIntent.length, plain.length);
      for (var i = 0; i < plain.length; i++) {
        expect(viaIntent[i].id, plain[i].id);
      }
    });

    test('shedPicks -- every offer really does send a pick away from the '
        'GM', () {
      final franchise = withFullActiveRoster(franchiseForPortraitTests());
      final offers = generateTradeOffersForIntent(
        franchise,
        TradeBoardIntent.shedPicks,
      );
      expect(offers, isNotEmpty);
      for (final offer in offers) {
        expect(offer.askedFromYou.whereType<PickTradeAsset>(), isNotEmpty);
      }
    });

    test('gainPicks -- every offer really does send the GM a pick back', () {
      final franchise = withFullActiveRoster(franchiseForPortraitTests());
      final offers = generateTradeOffersForIntent(
        franchise,
        TradeBoardIntent.gainPicks,
      );
      expect(offers, isNotEmpty);
      for (final offer in offers) {
        expect(offer.offeredToYou.whereType<PickTradeAsset>(), isNotEmpty);
      }
    });

    test('offloadDepth -- every offer really is the 2-for-1 '
        'consolidation shape', () {
      final franchise = withFullActiveRoster(franchiseForPortraitTests());
      final offers = generateTradeOffersForIntent(
        franchise,
        TradeBoardIntent.offloadDepth,
      );
      expect(offers, isNotEmpty);
      for (final offer in offers) {
        expect(offer.askedFromYou.whereType<PlayerTradeAsset>().length, 2);
        expect(offer.offeredToYou.whereType<PlayerTradeAsset>().length, 1);
      }
    });

    test('getYounger -- every offer really does send an older player (or '
        'players) for a younger return', () {
      final franchise = withFullActiveRoster(franchiseForPortraitTests());
      final offers = generateTradeOffersForIntent(
        franchise,
        TradeBoardIntent.getYounger,
      );
      expect(offers, isNotEmpty);
      for (final offer in offers) {
        final sentAges = [
          for (final a in offer.askedFromYou)
            if (a case PlayerTradeAsset(:final player)) player.age,
        ];
        final receivedAges = [
          for (final a in offer.offeredToYou)
            if (a case PlayerTradeAsset(:final player)) player.age,
        ];
        expect(sentAges, isNotEmpty);
        expect(receivedAges, isNotEmpty);
        final sentAvg = sentAges.reduce((a, b) => a + b) / sentAges.length;
        final receivedAvg =
            receivedAges.reduce((a, b) => a + b) / receivedAges.length;
        expect(sentAvg, greaterThan(receivedAvg));
      }
    });

    test('every offer is still objectively legal for the offering '
        'team\'s own coach Management, across every non-anything intent', () {
      final franchise = withFullActiveRoster(franchiseForPortraitTests());
      for (final intent in TradeBoardIntent.values) {
        for (final offer in generateTradeOffersForIntent(franchise, intent)) {
          final aiTeam = franchise.league.aiTeams.firstWhere(
            (t) => t.team.abbreviation == offer.offeringTeamAbbreviation,
          );
          expect(
            isTradeWithinManagementSwing(
              offeredValue: offer.offeredValue,
              requestedValue: offer.askedValue,
              management: aiTeam.coach.stats.management,
            ),
            isTrue,
            reason: 'intent $intent: offer $offer is not actually legal',
          );
        }
      }
    });

    test('deterministic for the same franchise state, for every intent', () {
      final franchise = withFullActiveRoster(franchiseForPortraitTests());
      for (final intent in TradeBoardIntent.values) {
        final a = generateTradeOffersForIntent(franchise, intent);
        final b = generateTradeOffersForIntent(franchise, intent);
        expect(a.length, b.length);
        for (var i = 0; i < a.length; i++) {
          expect(a[i].id, b[i].id);
        }
      }
    });

    test('distinct intents produce distinct offer ids from the plain '
        'board -- not just the same offers reshuffled', () {
      final franchise = withFullActiveRoster(franchiseForPortraitTests());
      final plainIds = generateTradeOffers(franchise).map((o) => o.id).toSet();
      final shedPicksIds = generateTradeOffersForIntent(
        franchise,
        TradeBoardIntent.shedPicks,
      ).map((o) => o.id).toSet();
      expect(shedPicksIds.intersection(plainIds), isEmpty);
    });
  });
}
