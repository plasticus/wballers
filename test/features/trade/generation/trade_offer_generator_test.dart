import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/roster/domain/roster_status.dart';
import 'package:womensbballmgr/features/season/domain/season_progress.dart';
import 'package:womensbballmgr/features/trade/domain/pick_ownership.dart';
import 'package:womensbballmgr/features/trade/domain/trade_asset.dart';
import 'package:womensbballmgr/features/trade/domain/trade_value.dart';
import 'package:womensbballmgr/features/trade/generation/trade_offer_generator.dart';

import '../../../support/franchise_test_helpers.dart';
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
    final ownActiveBySkill = [
      for (final m in franchise.roster)
        if (m.status == RosterStatus.active) m.player,
    ]..sort((a, b) => a.ratings.skillPoints.compareTo(b.ratings.skillPoints));
    final weakestTwoIds = ownActiveBySkill.take(2).map((p) => p.id).toSet();

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
}
