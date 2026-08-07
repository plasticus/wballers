import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/core/persistence/save_repository_provider.dart';
import 'package:womensbballmgr/features/franchise/application/current_franchise_provider.dart';
import 'package:womensbballmgr/features/franchise/application/save_slots.dart';
import 'package:womensbballmgr/features/franchise/onboarding/expansion_franchise_factory.dart';
import 'package:womensbballmgr/features/franchise/presentation/main_menu_screen.dart';
import 'package:womensbballmgr/features/league/domain/team.dart';

import '../../../support/in_memory_save_repository.dart';

void main() {
  testWidgets('lists all 3 slots, occupied ones with a real summary, '
      'empty ones plainly marked', (tester) async {
    // All 3 slot cards need to be on-screen at once -- a plain ListView
    // only mounts elements near the viewport, same gotcha every other
    // long-list test in this codebase already works around.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repository = InMemorySaveRepository();
    final container = ProviderContainer(
      overrides: [saveRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final franchise = createExpansionFranchise(
      gmName: 'Jordan Ellis',
      clubName: 'Comets',
      homeCity: 'Springfield, IL',
      conference: Conference.atlantic,
      replacedTeamAbbreviation: 'BOS',
      colors: kStarterPalettes.first,
      emoji: '🏀',
      simulationSeed: 1,
    );
    await container
        .read(currentFranchiseProvider.notifier)
        .createFranchise(franchise);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MainMenuScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Slot 1'), findsOneWidget);
    expect(find.text('Slot 2'), findsOneWidget);
    expect(find.text('Slot 3'), findsOneWidget);
    expect(find.text('Comets'), findsOneWidget);
    expect(find.text('GM Jordan Ellis'), findsOneWidget);
    expect(find.text('Empty'), findsNWidgets(2));
    expect(find.text('Play'), findsNWidgets(3));
  });

  testWidgets(
    'tapping Play on a different slot switches the active slot and opens '
    'AppShell',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repository = InMemorySaveRepository();
      final container = ProviderContainer(
        overrides: [saveRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      await container.read(activeSaveSlotProvider.future);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: MainMenuScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Slot 2's card is the second "Play" button.
      await tester.tap(find.text('Play').at(1));
      await tester.pumpAndSettle();

      expect(container.read(activeSaveSlotProvider).value, 'franchise-slot-2');
      // Landed on AppShell, showing the empty-slot hero (no back button --
      // the stack was reset, not just pushed on top).
      expect(find.text('Women\'s Basketball Manager'), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
    },
  );

  testWidgets(
    'deleting a slot asks for confirmation, then removes it and the card '
    'goes back to Empty',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repository = InMemorySaveRepository();
      final container = ProviderContainer(
        overrides: [saveRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final franchise = createExpansionFranchise(
        gmName: 'Jordan Ellis',
        clubName: 'Comets',
        homeCity: 'Springfield, IL',
        conference: Conference.atlantic,
        replacedTeamAbbreviation: 'BOS',
        colors: kStarterPalettes.first,
        emoji: '🏀',
        simulationSeed: 1,
      );
      await container
          .read(currentFranchiseProvider.notifier)
          .createFranchise(franchise);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: MainMenuScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // A confirmation dialog, not an immediate delete.
      expect(find.text('Delete this save?'), findsOneWidget);
      expect(find.text('Comets'), findsWidgets); // named in the dialog body

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Empty'), findsNWidgets(2)); // unchanged -- cancelled

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last); // the dialog's own button
      await tester.pumpAndSettle();

      expect(find.text('Empty'), findsNWidgets(3));
      expect(
        await container.read(
          saveSlotFranchiseProvider(kCurrentFranchiseSaveId).future,
        ),
        isNull,
      );
    },
  );
}
