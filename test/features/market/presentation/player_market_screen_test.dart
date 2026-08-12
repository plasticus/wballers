import 'dart:math';

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
import 'package:womensbballmgr/features/market/generation/player_market_preview_generator.dart';
import 'package:womensbballmgr/features/market/presentation/player_market_screen.dart';
import 'package:womensbballmgr/features/player/domain/position.dart';
import 'package:womensbballmgr/features/roster/domain/roster_status.dart';

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
      expect(find.text('Trade Block'), findsOneWidget);
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

  testWidgets('the Trade Block tab shows real AI teams, one per player', (
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

    await tester.tap(find.text('Trade Block'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Preview only -- there\'s no trade system'),
      findsOneWidget,
    );
    // The screen's own preview picks, recomputed the same way it
    // generates them internally (same seed formula) -- whichever real
    // team its first pick actually belongs to shows up as that row's
    // subtitle, not "Free Agent".
    final picks = pickTradeBlockPreview(
      franchise,
      Random(franchise.simulationSeed + kTradeBlockPreviewSeedOffset),
    );
    final firstPickTeam = picks.first.team;
    expect(
      find.textContaining('${firstPickTeam.emoji} ${firstPickTeam.name}'),
      findsWidgets,
    );
    expect(find.textContaining('Free Agent ·'), findsNothing);
    expect(find.text('Sign'), findsNothing);
  });

  testWidgets('the Draft tab shows a college per prospect, not a team', (
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

    await tester.tap(find.text('Draft'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Preview only -- a fresh, hypothetical class'),
      findsOneWidget,
    );
    // The screen's own preview prospects, recomputed the same way --
    // the first prospect's real college shows up as that row's subtitle.
    final prospects = generateDraftPreview(
      Random(franchise.simulationSeed + kDraftPreviewSeedOffset),
    );
    expect(
      find.textContaining('${prospects.first.college.name} ·'),
      findsWidgets,
    );
    expect(find.textContaining('Free Agent ·'), findsNothing);
    expect(find.text('Sign'), findsNothing);
  });
}
