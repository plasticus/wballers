import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/app/app_preferences.dart';
import 'package:womensbballmgr/core/persistence/save_repository_provider.dart';
import 'package:womensbballmgr/features/franchise/presentation/main_menu_screen.dart';
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
}
