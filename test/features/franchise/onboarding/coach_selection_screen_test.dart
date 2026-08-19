import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/core/persistence/portrait_cache_provider.dart';
import 'package:womensbballmgr/core/persistence/save_repository_provider.dart';
import 'package:womensbballmgr/features/coach/domain/coach_archetype.dart';
import 'package:womensbballmgr/features/coach/domain/coach_lifecycle.dart';
import 'package:womensbballmgr/features/coach/generation/coach_generator.dart';
import 'package:womensbballmgr/features/franchise/onboarding/coach_selection_screen.dart';
import 'package:womensbballmgr/features/franchise/onboarding/expansion_franchise_factory.dart';
import 'package:womensbballmgr/features/league/domain/team.dart';
import 'package:womensbballmgr/features/portrait/persistence/portrait_catalog_loader.dart';

import '../../../support/in_memory_portrait_cache.dart';
import '../../../support/in_memory_save_repository.dart';
import '../../../support/portrait_test_helpers.dart';

const _simulationSeed = 777;

/// Screen-level coverage for the candidate-generation/display piece
/// specifically; the interaction flow (selecting a candidate, confirming,
/// and the resulting franchise carrying that coach) is covered by
/// `onboarding_screen_test.dart`'s full-flow test instead -- running
/// multiple portrait-rendering `testWidgets` back to back in one file
/// here proved unreliable (real asset I/O interacting with `tester.runAsync`
/// across tests, not a product bug), so this file deliberately stays to
/// one test rather than fighting that -- the reroll button (2026-08-19)
/// is covered inline in that same one test, not a second `testWidgets`.
void main() {
  testWidgets('shows the same 3 candidates generateCoachCandidates would '
      'produce for this seed, and Re-roll Candidates draws a genuinely '
      'fresh batch (2026-08-19, a direct GM ask: "I\'d love a re-roll '
      'button at the bottom too")', (tester) async {
    // The Re-roll button sits below the 3 candidate cards -- needs a
    // tall surface so it's actually on-screen to tap, same reasoning
    // every other long-column test in this codebase already works
    // around.
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repository = InMemorySaveRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          saveRepositoryProvider.overrideWithValue(repository),
          // The real FilePortraitCache calls path_provider, a plugin
          // channel that isn't reliably available under flutter test.
          portraitCacheProvider.overrideWithValue(InMemoryPortraitCache()),
        ],
        child: MaterialApp(
          home: CoachSelectionScreen(
            gmName: 'Jordan Ellis',
            clubName: 'Comets',
            homeCity: 'Springfield',
            homeState: 'IL',
            abbreviation: 'CMT',
            conference: Conference.atlantic,
            simulationSeed: _simulationSeed,
            replacedTeamAbbreviation: 'BOS',
            colors: kStarterPalettes.first,
            emoji: '🐟',
          ),
        ),
      ),
    );
    await letPortraitAsyncWorkFinish(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(CoachSelectionScreen)),
    );
    final weights = container.read(portraitWeightsProvider).value!;
    final manifest = container.read(portraitManifestProvider).value!;
    final expectedCandidates = generateCoachCandidates(
      Random(_simulationSeed),
      minAge: kCoachInitialLeagueMinAge,
      maxAge: kCoachInitialLeagueMaxAge,
      portraitWeights: weights,
      portraitManifest: manifest,
    );

    expect(
      find.textContaining('your first task is to select a Head Coach'),
      findsOneWidget,
    );
    for (final candidate in expectedCandidates) {
      expect(find.text(candidate.name), findsOneWidget);
      expect(
        find.text('${candidate.archetype.label} · Age ${candidate.age}'),
        findsOneWidget,
      );
      expect(
        candidate.age,
        inInclusiveRange(kCoachInitialLeagueMinAge, kCoachInitialLeagueMaxAge),
      );
    }
    // 3 distinct archetypes -- never a duplicate philosophy among the
    // options.
    expect(expectedCandidates.map((c) => c.archetype).toSet(), hasLength(3));

    await tester.tap(find.text('Re-roll Candidates'));
    await letPortraitAsyncWorkFinish(tester);

    // The screen no longer shows any of the original batch's names -- a
    // genuinely fresh draw, not a no-op.
    for (final original in expectedCandidates) {
      expect(find.text(original.name), findsNothing);
    }
    // Nothing stays selected across a reroll -- the old candidate
    // objects are gone, so Confirm has nothing to submit yet.
    final confirmButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Confirm & Create Franchise'),
    );
    expect(confirmButton.onPressed, isNull);
  });
}
