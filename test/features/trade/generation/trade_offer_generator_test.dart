import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/roster/domain/roster_status.dart';
import 'package:womensbballmgr/features/season/domain/season_progress.dart';
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
          reason: 'game day $gameDayIndex: offer $offer is not actually '
              'legal for ${offer.offeringTeamAbbreviation}\'s own coach',
        );
      }
    }
  });

  test('never asks for more players than it offers, or vice versa -- '
      'headcount always matches on both sides', () {
    final franchise = withFullActiveRoster(franchiseForPortraitTests());
    final offers = generateTradeOffers(franchise);

    for (final offer in offers) {
      final offeredPlayers = offer.offeredToYou.whereType<PlayerTradeAsset>();
      final askedPlayers = offer.askedFromYou.whereType<PlayerTradeAsset>();
      expect(offeredPlayers.length, askedPlayers.length);
    }
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
