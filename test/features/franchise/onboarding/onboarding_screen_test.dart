import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/core/persistence/save_repository_provider.dart';
import 'package:womensbballmgr/features/franchise/application/current_franchise_provider.dart';
import 'package:womensbballmgr/features/franchise/onboarding/onboarding_screen.dart';

import '../../../support/in_memory_save_repository.dart';

void main() {
  Future<void> pumpHarness(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          saveRepositoryProvider.overrideWithValue(InMemorySaveRepository()),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                  ),
                  child: const Text('Open onboarding'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open onboarding'));
    await tester.pumpAndSettle();
  }

  testWidgets('the create button is disabled until every field is filled', (
    tester,
  ) async {
    await pumpHarness(tester);

    FilledButton createButton() => tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Create Franchise'),
    );

    expect(createButton().onPressed, isNull);

    await tester.enterText(
      find.widgetWithText(TextField, 'Coach name'),
      'Jordan Ellis',
    );
    await tester.pump();
    expect(createButton().onPressed, isNull);

    await tester.enterText(
      find.widgetWithText(TextField, 'Club name'),
      'Comets',
    );
    await tester.pump();
    expect(createButton().onPressed, isNull);

    await tester.enterText(
      find.widgetWithText(TextField, 'Home city'),
      'Springfield, IL',
    );
    await tester.pump();

    expect(createButton().onPressed, isNotNull);
  });

  testWidgets(
    'creating a franchise saves it and returns to the previous screen',
    (tester) async {
      await pumpHarness(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Coach name'),
        'Jordan Ellis',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Club name'),
        'Comets',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Home city'),
        'Springfield, IL',
      );
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Create Franchise'));
      await tester.pumpAndSettle();

      expect(find.text('Open onboarding'), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);

      final context = tester.element(find.text('Open onboarding'));
      final container = ProviderScope.containerOf(context);
      final franchise = container.read(currentFranchiseProvider).value;

      expect(franchise?.team.name, 'Comets');
      expect(franchise?.coach.name, 'Jordan Ellis');
    },
  );
}
