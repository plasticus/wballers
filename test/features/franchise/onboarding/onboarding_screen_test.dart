import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/core/persistence/save_repository_provider.dart';
import 'package:womensbballmgr/features/franchise/application/current_franchise_provider.dart';
import 'package:womensbballmgr/features/franchise/onboarding/onboarding_screen.dart';
import 'package:womensbballmgr/features/league/domain/initial_league.dart';
import 'package:womensbballmgr/features/league/domain/team.dart';

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
      find.widgetWithText(TextField, 'Your name (General Manager)'),
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
    'shows the selected conference\'s teams and updates when it changes',
    (tester) async {
      await pumpHarness(tester);

      final firstAtlanticTeam = kInitialLeagueTeams.firstWhere(
        (team) => team.conference == Conference.atlantic,
      );
      final firstPacificTeam = kInitialLeagueTeams.firstWhere(
        (team) => team.conference == Conference.pacific,
      );

      // Atlantic is the default selection.
      expect(find.text('Atlantic Conference teams'), findsOneWidget);
      expect(find.text(firstAtlanticTeam.name), findsOneWidget);
      expect(find.text(firstPacificTeam.name), findsNothing);

      await tester.tap(find.text('Pacific'));
      await tester.pumpAndSettle();

      expect(find.text('Pacific Conference teams'), findsOneWidget);
      expect(find.text(firstPacificTeam.name), findsOneWidget);
      expect(find.text(firstAtlanticTeam.name), findsNothing);
    },
  );

  testWidgets(
    'creating a franchise saves it and returns to the previous screen',
    (tester) async {
      await pumpHarness(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Your name (General Manager)'),
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

      // The conference team listing pushes the button below the fold.
      final createButton = find.widgetWithText(
        FilledButton,
        'Create Franchise',
      );
      await tester.ensureVisible(createButton);
      await tester.pumpAndSettle();
      await tester.tap(createButton);
      await tester.pumpAndSettle();

      expect(find.text('Open onboarding'), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);

      final context = tester.element(find.text('Open onboarding'));
      final container = ProviderScope.containerOf(context);
      final franchise = container.read(currentFranchiseProvider).value;

      expect(franchise?.team.name, 'Comets');
      expect(franchise?.gmName, 'Jordan Ellis');
      expect(franchise?.coach.name, isNot('Jordan Ellis'));
    },
  );
}
