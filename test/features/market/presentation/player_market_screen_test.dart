import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/core/persistence/save_envelope.dart';
import 'package:womensbballmgr/core/persistence/save_repository_provider.dart';
import 'package:womensbballmgr/features/franchise/application/current_franchise_provider.dart';
import 'package:womensbballmgr/features/franchise/domain/franchise.dart';
import 'package:womensbballmgr/features/franchise/onboarding/expansion_franchise_factory.dart';
import 'package:womensbballmgr/features/franchise/persistence/franchise_json.dart';
import 'package:womensbballmgr/features/league/domain/team.dart';
import 'package:womensbballmgr/features/market/presentation/player_market_screen.dart';
import 'package:womensbballmgr/features/player/domain/position.dart';
import 'package:womensbballmgr/features/roster/domain/roster_status.dart';
import 'package:womensbballmgr/features/trade/domain/trade_asset.dart';
import 'package:womensbballmgr/features/trade/domain/trade_offer.dart';
import 'package:womensbballmgr/features/trade/generation/trade_offer_generator.dart';

import '../../../support/in_memory_save_repository.dart';

Franchise _newFranchise() => createExpansionFranchise(
  gmName: 'Jordan Ellis',
  clubName: 'Comets',
  homeCity: 'Springfield, IL',
  conference: Conference.atlantic,
  replacedTeamAbbreviation: 'BOS',
  colors: kStarterPalettes.first,
  emoji: '🏀',
  simulationSeed: 1,
);

Future<InMemorySaveRepository> _seededRepository(Franchise franchise) async {
  final repository = InMemorySaveRepository();
  await repository.writeSave(
    kCurrentFranchiseSaveId,
    SaveEnvelope(
      schemaVersion: 1,
      payload: franchiseToJson(franchise),
    ).toJson(),
  );
  return repository;
}

void main() {
  testWidgets(
    'shows the 3 tabs, opening on Free Agents with a real, signable pool',
    (tester) async {
      // All 12 free-agent rows need to be on-screen at once, same "plain
      // ListView only builds near the viewport" reasoning every other
      // long-list test in this codebase already works around.
      tester.view.physicalSize = const Size(800, 4500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final franchise = _newFranchise();
      final repository = await _seededRepository(franchise);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [saveRepositoryProvider.overrideWithValue(repository)],
          child: MaterialApp(home: PlayerMarketScreen(franchise: franchise)),
        ),
      );
      await tester.pump();

      expect(find.text('Player Market'), findsOneWidget);
      expect(find.text('Free Agents'), findsWidgets); // tab + banner text
      expect(find.text('Trade Board'), findsOneWidget);
      expect(find.text('Draft'), findsOneWidget);

      // The active roster starts one short (11/12) -- the banner says so
      // and nudges toward signing, not a "preview only" disclaimer.
      expect(
        find.textContaining('Your active roster has an open spot'),
        findsOneWidget,
      );

      // Every free agent in the real, persisted pool shows up, each
      // labeled "Free Agent" (folded into the identity subtitle line, not
      // its own standalone Text, hence textContaining) with a Sign button.
      expect(
        find.textContaining('Free Agent ·'),
        findsNWidgets(franchise.freeAgents.length),
      );
      expect(find.text('Sign'), findsNWidgets(franchise.freeAgents.length));

      // Every free agent's card shows a POT chip alongside OFF/DEF/PHY --
      // a direct GM ask (2026-08-09, `Aug9bugs.md` #2): "should be able to
      // see potential. That's a huge part of what free agent you might
      // want." Grouped by value (rather than asserting `findsOneWidget`
      // per player) since two free agents can land on the same potential
      // by chance -- this still catches a missing/wrong chip either way.
      final potentialCounts = <int, int>{};
      for (final freeAgent in franchise.freeAgents) {
        potentialCounts[freeAgent.ratings.potential] =
            (potentialCounts[freeAgent.ratings.potential] ?? 0) + 1;
      }
      for (final entry in potentialCounts.entries) {
        expect(find.text('POT ${entry.key}'), findsNWidgets(entry.value));
      }
    },
  );

  testWidgets(
    'tapping Sign moves that free agent onto the active roster and pops '
    'back',
    (tester) async {
      tester.view.physicalSize = const Size(800, 4500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final franchise = _newFranchise();
      final repository = await _seededRepository(franchise);
      // The tab defaults to Overall, descending -- the first "Sign" button
      // on screen belongs to the highest-overall free agent, not
      // necessarily `franchise.freeAgents.first`.
      final targetFreeAgent = franchise.freeAgents.reduce(
        (a, b) => a.ratings.overall >= b.ratings.overall ? a : b,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [saveRepositoryProvider.overrideWithValue(repository)],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            PlayerMarketScreen(franchise: franchise),
                      ),
                    ),
                    child: const Text('Open Player Market'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Open Player Market'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign').first);
      await tester.pumpAndSettle();

      // Popped back to the screen underneath -- Player Market is gone.
      expect(find.text('Player Market'), findsNothing);
      expect(find.text('Open Player Market'), findsOneWidget);

      final saved = await repository.readSave(kCurrentFranchiseSaveId);
      final savedFranchise = franchiseFromJson(
        SaveEnvelope.fromJson(saved!).payload,
      );
      // The active roster grew by exactly one, and it's the free agent
      // that was signed -- who's no longer in the pool.
      expect(
        savedFranchise.roster
            .where((m) => m.status == RosterStatus.active)
            .length,
        franchise.roster.length + 1,
      );
      expect(
        savedFranchise.roster.any((m) => m.player.id == targetFreeAgent.id),
        isTrue,
      );
      expect(
        savedFranchise.freeAgents.any((p) => p.id == targetFreeAgent.id),
        isFalse,
      );
      expect(
        savedFranchise.freeAgents,
        hasLength(franchise.freeAgents.length - 1),
      );
    },
  );

  testWidgets('the Position filter narrows the Free Agents list (2026-08-11, a '
      'direct GM ask: "Free agents also need to be sorted... I thought we '
      'wired this up, but it isn\'t live in the build on my phone")', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 4500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final franchise = _newFranchise();
    final repository = await _seededRepository(franchise);
    final targetPosition = franchise.freeAgents.first.primaryPosition;
    final expectedCount = franchise.freeAgents
        .where((p) => p.primaryPosition == targetPosition)
        .length;
    // The pool needs at least one player at a different position too,
    // or this test can't tell "filtered" from "coincidentally everyone
    // matches" -- true for every real seeded pool, but asserted here so
    // a future change to pool generation fails loudly instead of
    // silently testing nothing.
    expect(expectedCount, lessThan(franchise.freeAgents.length));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [saveRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(home: PlayerMarketScreen(franchise: franchise)),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(targetPosition.abbreviation).last);
    await tester.pumpAndSettle();

    expect(find.textContaining('Free Agent ·'), findsNWidgets(expectedCount));
  });

  testWidgets('the Trade Board tab shows live AI offers with Accept/Decline', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 4500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final franchise = _newFranchise();
    final repository = await _seededRepository(franchise);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [saveRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(home: PlayerMarketScreen(franchise: franchise)),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Trade Board'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Real offers from around the league'),
      findsOneWidget,
    );

    // The screen's own offers, recomputed the same way it generates them
    // internally (same seed/game-day formula) -- a fresh franchise's trade
    // window is open at game day 0, so this matches exactly.
    final offers = generateTradeOffers(franchise);
    expect(offers, isNotEmpty);
    final firstOfferTeam = franchise.league.aiTeams.firstWhere(
      (t) => t.team.abbreviation == offers.first.offeringTeamAbbreviation,
    );
    expect(find.text(firstOfferTeam.team.name), findsWidgets);
    expect(find.text('Accept'), findsNWidgets(offers.length));
    expect(find.text('Decline'), findsNWidgets(offers.length));
  });

  testWidgets(
    'switching the Trade Board intent toggle rerolls the board to match '
    '(2026-08-23, a direct GM ask: "Give me some toggles or something. '
    'I\'m looking to get rid of draft picks...")',
    (tester) async {
      tester.view.physicalSize = const Size(800, 4500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final franchise = _newFranchise();
      final repository = await _seededRepository(franchise);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [saveRepositoryProvider.overrideWithValue(repository)],
          child: MaterialApp(home: PlayerMarketScreen(franchise: franchise)),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Trade Board'));
      await tester.pumpAndSettle();

      // Every toggle is visible up front, no scrolling needed to find one.
      for (final intent in TradeBoardIntent.values) {
        expect(find.text(tradeBoardIntentLabel(intent)), findsOneWidget);
      }

      await tester.tap(find.text('Shed Picks'));
      await tester.pumpAndSettle();

      final shedPicksOffers = generateTradeOffersForIntent(
        franchise,
        TradeBoardIntent.shedPicks,
      );
      expect(shedPicksOffers, isNotEmpty);
      expect(find.text('Accept'), findsNWidgets(shedPicksOffers.length));

      // Every real player asset on screen belongs to the shedPicks board,
      // not whatever "Anything" happened to show a moment ago -- each
      // player's name renders inline as part of a longer "PG Name · Age
      // NN" tile, not its own bare Text, hence textContaining.
      final allNames = <String>{
        for (final offer in shedPicksOffers)
          for (final asset in [...offer.offeredToYou, ...offer.askedFromYou])
            if (asset case PlayerTradeAsset(:final player)) player.name,
      };
      for (final name in allNames) {
        expect(find.textContaining(name), findsWidgets);
      }
    },
  );

  testWidgets(
    'shows a POT chip for every player on the Trade Board -- a direct GM '
    'ask (2026-08-20): "on the trade board screen, we need to add '
    'potential somewhere"',
    (tester) async {
      tester.view.physicalSize = const Size(800, 4500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final franchise = _newFranchise();
      final repository = await _seededRepository(franchise);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [saveRepositoryProvider.overrideWithValue(repository)],
          child: MaterialApp(home: PlayerMarketScreen(franchise: franchise)),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Trade Board'));
      await tester.pumpAndSettle();

      final offers = generateTradeOffers(franchise);
      expect(offers, isNotEmpty);
      final potentials = <int>[
        for (final offer in offers)
          for (final asset in [...offer.offeredToYou, ...offer.askedFromYou])
            if (asset is PlayerTradeAsset) asset.player.ratings.potential,
      ];
      expect(potentials, isNotEmpty);
      final counts = <int, int>{};
      for (final pot in potentials) {
        counts[pot] = (counts[pot] ?? 0) + 1;
      }
      for (final entry in counts.entries) {
        expect(find.text('POT ${entry.key}'), findsNWidgets(entry.value));
      }
    },
  );

  testWidgets(
    'tapping Cancel on the confirm dialog leaves the offer untouched',
    (tester) async {
      tester.view.physicalSize = const Size(800, 4500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final franchise = _newFranchise();
      final repository = await _seededRepository(franchise);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [saveRepositoryProvider.overrideWithValue(repository)],
          child: MaterialApp(home: PlayerMarketScreen(franchise: franchise)),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Trade Board'));
      await tester.pumpAndSettle();

      final offers = generateTradeOffers(franchise);
      final offerCountBefore = find.text('Accept').evaluate().length;

      await tester.tap(find.text('Accept').first);
      await tester.pumpAndSettle();
      expect(find.text('Accept this trade?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Accept this trade?'), findsNothing);
      // Still every offer, nothing resolved.
      expect(find.text('Accept'), findsNWidgets(offerCountBefore));
      final saved = await repository.readSave(kCurrentFranchiseSaveId);
      final savedFranchise = franchiseFromJson(
        SaveEnvelope.fromJson(saved!).payload,
      );
      expect(
        savedFranchise.resolvedTradeOfferIds,
        isNot(contains(offers.first.id)),
      );
    },
  );

  testWidgets(
    'accepting one offer drops it (plus any other offer touching the same '
    'players) -- the rest of the board stays exactly as it was, no '
    'instant reshuffle or refill (2026-08-21, a direct GM spec: "remove '
    'any deals containing the traded players too... you get more deals '
    'next week")',
    (tester) async {
      tester.view.physicalSize = const Size(800, 4500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final franchise = _newFranchise();
      final repository = await _seededRepository(franchise);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [saveRepositoryProvider.overrideWithValue(repository)],
          child: MaterialApp(home: PlayerMarketScreen(franchise: franchise)),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Trade Board'));
      await tester.pumpAndSettle();

      final offers = generateTradeOffers(franchise);
      expect(offers.length, greaterThan(1));
      final accepted = offers.first;
      final acceptedPlayerIds = {
        for (final asset in [
          ...accepted.offeredToYou,
          ...accepted.askedFromYou,
        ])
          if (asset is PlayerTradeAsset) asset.player.id,
      };
      final expectedRemaining = offers.skip(1).where((offer) {
        final ids = {
          for (final asset in [...offer.offeredToYou, ...offer.askedFromYou])
            if (asset is PlayerTradeAsset) asset.player.id,
        };
        return ids.intersection(acceptedPlayerIds).isEmpty;
      }).length;

      await tester.tap(find.text('Accept').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Accept').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // Exactly the surviving offers -- not regenerated from the
      // post-trade roster, which could otherwise swap in a completely
      // different set instead of just shrinking.
      expect(find.text('Accept'), findsNWidgets(expectedRemaining));
    },
  );

  testWidgets(
    'tapping Accept on a Trade Board offer asks for confirmation, then '
    'resolves and persists it, then shows a completion dialog '
    '(2026-08-21, a direct GM spec)',
    (tester) async {
      tester.view.physicalSize = const Size(800, 4500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final franchise = _newFranchise();
      final repository = await _seededRepository(franchise);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [saveRepositoryProvider.overrideWithValue(repository)],
          child: MaterialApp(home: PlayerMarketScreen(franchise: franchise)),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Trade Board'));
      await tester.pumpAndSettle();

      final offers = generateTradeOffers(franchise);
      expect(offers, isNotEmpty);
      final acceptedOffer = offers.first;

      await tester.tap(find.text('Accept').first);
      await tester.pumpAndSettle();

      // A confirm dialog first -- not resolved yet.
      expect(find.text('Accept this trade?'), findsOneWidget);
      var saved = await repository.readSave(kCurrentFranchiseSaveId);
      var savedFranchise = franchiseFromJson(
        SaveEnvelope.fromJson(saved!).payload,
      );
      expect(
        savedFranchise.resolvedTradeOfferIds,
        isNot(contains(acceptedOffer.id)),
      );

      // Confirming actually resolves it, then shows a completion dialog.
      await tester.tap(find.text('Accept').last);
      await tester.pumpAndSettle();

      expect(find.text('Trade Completed'), findsOneWidget);
      saved = await repository.readSave(kCurrentFranchiseSaveId);
      savedFranchise = franchiseFromJson(SaveEnvelope.fromJson(saved!).payload);
      expect(savedFranchise.resolvedTradeOfferIds, contains(acceptedOffer.id));

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Trade Completed'), findsNothing);
    },
  );

  testWidgets(
    'tapping View Full Details opens a trade detail screen showing every '
    'player on both sides, each tappable through to their full profile '
    '-- a direct GM ask (2026-08-20): "each trade needs a details '
    'screen, where all the players involved are there, I can see every '
    'detail about each player"',
    (tester) async {
      tester.view.physicalSize = const Size(800, 4500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final franchise = _newFranchise();
      final repository = await _seededRepository(franchise);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [saveRepositoryProvider.overrideWithValue(repository)],
          child: MaterialApp(home: PlayerMarketScreen(franchise: franchise)),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Trade Board'));
      await tester.pumpAndSettle();

      final offers = generateTradeOffers(franchise);
      final firstOffer = offers.first;
      final firstGivePlayer =
          (firstOffer.askedFromYou.whereType<PlayerTradeAsset>().first).player;

      await tester.tap(find.text('View Full Details').first);
      await tester.pumpAndSettle();

      expect(find.text('Trade Offer'), findsOneWidget);
      expect(find.text('You Get'), findsOneWidget);
      expect(find.text('You Give'), findsOneWidget);
      expect(
        find.textContaining(firstGivePlayer.name),
        findsOneWidget,
        reason:
            'the GM\'s own asked-for player should be listed under '
            '"You Give"',
      );

      // Tapping that player's row opens her full profile.
      await tester.tap(find.textContaining(firstGivePlayer.name));
      await tester.pumpAndSettle();

      expect(find.text(firstGivePlayer.name), findsWidgets);
    },
  );

  testWidgets(
    'accepting from the trade detail screen resolves the offer and pops '
    'back',
    (tester) async {
      tester.view.physicalSize = const Size(800, 4500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final franchise = _newFranchise();
      final repository = await _seededRepository(franchise);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [saveRepositoryProvider.overrideWithValue(repository)],
          child: MaterialApp(home: PlayerMarketScreen(franchise: franchise)),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Trade Board'));
      await tester.pumpAndSettle();

      final offers = generateTradeOffers(franchise);
      final acceptedOffer = offers.first;

      await tester.tap(find.text('View Full Details').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();

      // The detail screen's own confirm dialog first.
      expect(find.text('Accept this trade?'), findsOneWidget);
      await tester.tap(find.text('Accept').last);
      await tester.pumpAndSettle();

      // Back on the Trade Board, with a completion dialog up.
      expect(find.text('Trade Offer'), findsNothing);
      expect(find.text('Trade Completed'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      final saved = await repository.readSave(kCurrentFranchiseSaveId);
      final savedFranchise = franchiseFromJson(
        SaveEnvelope.fromJson(saved!).payload,
      );
      expect(savedFranchise.resolvedTradeOfferIds, contains(acceptedOffer.id));
    },
  );

  testWidgets('setting a Trade Block player persists the flag', (tester) async {
    tester.view.physicalSize = const Size(800, 4500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final franchise = _newFranchise();
    final repository = await _seededRepository(franchise);
    final target = franchise.roster
        .firstWhere((m) => m.status == RosterStatus.active)
        .player;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [saveRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(home: PlayerMarketScreen(franchise: franchise)),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Trade Board'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Set'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(target.name));
    await tester.pumpAndSettle();

    expect(find.textContaining('${target.name} is flagged'), findsOneWidget);

    final saved = await repository.readSave(kCurrentFranchiseSaveId);
    final savedFranchise = franchiseFromJson(
      SaveEnvelope.fromJson(saved!).payload,
    );
    expect(savedFranchise.tradeBlockPlayerId, target.id);
  });

  testWidgets(
    'the Draft tab shows the real upcoming draft class, a college per '
    'prospect, not a team (2026-08-21: this used to be a fake regenerated '
    '-every-open preview -- now it\'s Franchise.upcomingDraftClass, the '
    'real prospects for this season\'s eventual draft)',
    (tester) async {
      tester.view.physicalSize = const Size(800, 4500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final franchise = _newFranchise();
      final repository = await _seededRepository(franchise);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [saveRepositoryProvider.overrideWithValue(repository)],
          child: MaterialApp(home: PlayerMarketScreen(franchise: franchise)),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Draft'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('This season\'s real upcoming draft class'),
        findsOneWidget,
      );
      // Franchise.upcomingDraftClass's first prospect's real college shows
      // up as that row's subtitle -- not some independently re-derived
      // preview.
      final prospect = franchise.upcomingDraftClass.first;
      expect(find.textContaining('${prospect.college.name} ·'), findsWidgets);
      expect(find.textContaining('Free Agent ·'), findsNothing);
      expect(find.text('Sign'), findsNothing);
    },
  );
}
