import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/core/persistence/portrait_cache_provider.dart';
import 'package:womensbballmgr/core/persistence/save_repository_provider.dart';
import 'package:womensbballmgr/features/coach/domain/coach_archetype.dart';
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
/// one test rather than fighting that.
void main() {
  testWidgets('shows the same 3 candidates generateCoachCandidates would '
      'produce for this seed', (tester) async {
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
      portraitWeights: weights,
      portraitManifest: manifest,
    );

    expect(
      find.textContaining('your first task is to select a Head Coach'),
      findsOneWidget,
    );
    for (final candidate in expectedCandidates) {
      expect(find.text(candidate.name), findsOneWidget);
      expect(find.text(candidate.archetype.label), findsOneWidget);
    }
    // 3 distinct archetypes -- never a duplicate philosophy among the
    // options.
    expect(expectedCandidates.map((c) => c.archetype).toSet(), hasLength(3));
  });
}
