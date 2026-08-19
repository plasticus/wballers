import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/core/persistence/portrait_cache_provider.dart';
import 'package:womensbballmgr/core/persistence/save_envelope.dart';
import 'package:womensbballmgr/core/persistence/save_repository_provider.dart';
import 'package:womensbballmgr/features/coach/domain/coach_lifecycle.dart';
import 'package:womensbballmgr/features/coach/generation/coach_generator.dart';
import 'package:womensbballmgr/features/coach/presentation/available_head_coaches_screen.dart';
import 'package:womensbballmgr/features/franchise/application/current_franchise_provider.dart';
import 'package:womensbballmgr/features/franchise/domain/franchise.dart';
import 'package:womensbballmgr/features/franchise/onboarding/expansion_franchise_factory.dart';
import 'package:womensbballmgr/features/franchise/persistence/franchise_json.dart';
import 'package:womensbballmgr/features/league/domain/team.dart';
import 'package:womensbballmgr/features/portrait/persistence/portrait_catalog_loader.dart';

import '../../../support/franchise_test_helpers.dart';
import '../../../support/in_memory_portrait_cache.dart';
import '../../../support/in_memory_save_repository.dart';
import '../../../support/portrait_test_helpers.dart';

Franchise _newFranchise() => withFullActiveRoster(
  createExpansionFranchise(
    gmName: 'Jordan Ellis',
    clubName: 'Comets',
    homeCity: 'Springfield, IL',
    conference: Conference.atlantic,
    replacedTeamAbbreviation: 'BOS',
    colors: kStarterPalettes.first,
    emoji: '🏀',
    simulationSeed: 1,
  ),
);

/// Kept to one `testWidgets` in this file -- multiple portrait-rendering
/// tests back to back in one file proved unreliable elsewhere in this
/// codebase (`coach_selection_screen_test.dart`'s own doc comment), same
/// reasoning applies here.
void main() {
  testWidgets('shows kAvailableHeadCoachesCount real candidates, sortable, and '
      'hiring one actually replaces the GM\'s own coach and pops '
      '(2026-08-19, a direct GM ask)', (tester) async {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final franchise = _newFranchise();
    final repository = InMemorySaveRepository();
    await repository.writeSave(
      kCurrentFranchiseSaveId,
      SaveEnvelope(
        schemaVersion: 1,
        payload: franchiseToJson(franchise),
      ).toJson(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          saveRepositoryProvider.overrideWithValue(repository),
          portraitCacheProvider.overrideWithValue(InMemoryPortraitCache()),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          AvailableHeadCoachesScreen(franchise: franchise),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Open'));
    await letPortraitAsyncWorkFinish(tester);

    expect(find.text('Available Head Coaches'), findsOneWidget);
    expect(find.text('Hire'), findsNWidgets(kAvailableHeadCoachesCount));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(AvailableHeadCoachesScreen)),
    );
    final weights = container.read(portraitWeightsProvider).value!;
    final manifest = container.read(portraitManifestProvider).value!;
    final expectedCandidates = generateCoachCandidates(
      Random(franchise.seasonSeed + kAvailableHeadCoachesSeedOffset),
      count: kAvailableHeadCoachesCount,
      minAge: kCoachEntryMinAge,
      maxAge: kCoachEntryMaxAge,
      portraitWeights: weights,
      portraitManifest: manifest,
    );
    for (final candidate in expectedCandidates) {
      expect(find.text(candidate.name), findsOneWidget);
    }

    // Hire whichever candidate renders first (the screen sorts by
    // Overall descending by default, so this isn't necessarily
    // expectedCandidates.first in raw generation order) -- persists
    // for real and pops back.
    await tester.tap(find.text('Hire').first);
    await letPortraitAsyncWorkFinish(tester);

    expect(find.text('Available Head Coaches'), findsNothing);
    final saved = await repository.readSave(kCurrentFranchiseSaveId);
    final savedFranchise = franchiseFromJson(
      SaveEnvelope.fromJson(saved!).payload,
    );
    expect(
      expectedCandidates.map((c) => c.name),
      contains(savedFranchise.coach.name),
    );
  });
}
