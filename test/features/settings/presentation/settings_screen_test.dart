import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/app/app_preferences.dart';
import 'package:womensbballmgr/core/persistence/save_repository_provider.dart';
import 'package:womensbballmgr/features/franchise/application/current_franchise_provider.dart';
import 'package:womensbballmgr/features/franchise/application/debug_test_save.dart';
import 'package:womensbballmgr/features/franchise/application/save_slots.dart';
import 'package:womensbballmgr/features/franchise/presentation/main_menu_screen.dart';
import 'package:womensbballmgr/features/season/domain/season_progress.dart';
import 'package:womensbballmgr/features/settings/presentation/settings_screen.dart';

import '../../../support/in_memory_save_repository.dart';

void main() {
  testWidgets('dragging the text-size slider updates textScaleProvider', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        saveRepositoryProvider.overrideWithValue(InMemorySaveRepository()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump();

    expect(container.read(textScaleProvider), 1.0);

    // Drag the slider handle most of the way to its max -- a `Slider`
    // exposes no `.value` finder, so this exercises the real gesture
    // rather than calling `onChanged` directly.
    await tester.drag(find.byType(Slider), const Offset(300, 0));
    await tester.pump();

    expect(container.read(textScaleProvider), greaterThan(1.0));
  });

  testWidgets('picking a theme segment updates themeModeProvider', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        saveRepositoryProvider.overrideWithValue(InMemorySaveRepository()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump();

    expect(container.read(themeModeProvider), ThemeModePreference.system);

    await tester.tap(find.text('Dark'));
    await tester.pump();

    expect(container.read(themeModeProvider), ThemeModePreference.dark);
  });

  testWidgets('Exit to Main Menu resets the stack to MainMenuScreen', (
    tester,
  ) async {
    // The button sits below Text Size/Theme/Coming Soon in a ListView --
    // needs a taller surface to be on-screen and tap-hittable.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        saveRepositoryProvider.overrideWithValue(InMemorySaveRepository()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                  child: const Text('Open Settings'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Open Settings'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Exit to Main Menu'));
    await tester.pumpAndSettle();

    expect(find.byType(MainMenuScreen), findsOneWidget);
    expect(find.text('Open Settings'), findsNothing);
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('the Ad-Supported Play row is a real placeholder -- present '
      'but disabled', (tester) async {
    // The new App Version card at the very top (2026-08-21) pushes
    // everything below it further down than the default test surface's
    // height -- same taller-surface need the Coach Picker Lab test below
    // already has for the same underlying reason.
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        saveRepositoryProvider.overrideWithValue(InMemorySaveRepository()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump();

    final tile = tester.widget<ListTile>(find.byType(ListTile));
    expect(tile.enabled, isFalse);
    expect(find.text('Ad-Supported Play'), findsOneWidget);
  });

  testWidgets(
    'the Coach Picker Lab button opens CoachPickerLabScreen -- moved here '
    'from the Training screen (2026-08-18, a direct GM ask to hide it from '
    'that real gameplay screen)',
    (tester) async {
      // The Developer section (Live Game Lab, Coach Picker Lab) sits
      // below Text Size/Theme/Ad placeholder in a ListView -- needs a
      // taller surface to be on-screen and tap-hittable.
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final container = ProviderContainer(
        overrides: [
          saveRepositoryProvider.overrideWithValue(InMemorySaveRepository()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Coach Picker Lab'));
      await tester.pumpAndSettle();

      expect(find.text('1. Current Format (for reference)'), findsOneWidget);
    },
  );

  testWidgets(
    'Load Test Save asks for confirmation, then generates a franchise '
    'fast-forwarded to exactly 3 games left, in the dedicated scratch '
    'slot (2026-08-21, a direct GM ask: "I need to develop an admin '
    'save-game that fires up with like... 3 games left in the season")',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final container = ProviderContainer(
        overrides: [
          saveRepositoryProvider.overrideWithValue(InMemorySaveRepository()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pump();

      await tester.tap(find.textContaining('Load Test Save'));
      await tester.pump();

      // Cancel first -- confirms nothing happens without confirming.
      expect(find.text('Load Test Save?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      expect(
        container.read(currentFranchiseProvider).value,
        isNull,
        reason: 'Cancel should leave the (empty) active slot alone',
      );

      await tester.tap(find.textContaining('Load Test Save'));
      await tester.pump();
      await tester.tap(find.text('Load'));
      // A real, multi-game-day fast-forward -- give it a generous
      // timeout rather than the default.
      await tester.pumpAndSettle(
        const Duration(milliseconds: 50),
        EnginePhase.sendSemanticsUpdate,
        const Duration(minutes: 2),
      );

      expect(container.read(activeSaveSlotProvider).value, kSaveSlotIds.last);
      final franchise = container.read(currentFranchiseProvider).value;
      expect(franchise, isNotNull);
      final remaining =
          gameDaysInOrder(franchise!.seasonProgress.schedule).length -
          franchise.seasonProgress.nextGameDayIndex;
      expect(remaining, kDebugTestSaveGameDaysRemaining);
      // Landed back in the real app shell, not still on Settings.
      expect(find.byType(SettingsScreen), findsNothing);
    },
  );
}
