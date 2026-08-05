import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/core/persistence/save_repository_provider.dart';
import 'package:womensbballmgr/features/franchise/application/current_franchise_provider.dart';
import 'package:womensbballmgr/features/franchise/onboarding/expansion_franchise_factory.dart'
    show kStarterPalettes;
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
    'shows 10 of the conference\'s 20-team pool, and swaps when it changes',
    (tester) async {
      await pumpHarness(tester);

      // Each conference now has a 20-team candidate pool, of which this
      // playthrough draws 10 -- so the test can't assert a specific named
      // team is shown (that varies run to run), only that exactly 10 of
      // the right conference's pool render, and none of the other
      // conference's pool does. Team names are unique across both pools
      // (`initial_league_test.dart`), so name-matching can't cross-count.
      final atlanticPool = kLeagueTeamPool
          .where((team) => team.conference == Conference.atlantic)
          .toList();
      final pacificPool = kLeagueTeamPool
          .where((team) => team.conference == Conference.pacific)
          .toList();

      int shownCount(List<Team> pool) => pool
          .where((team) => find.text(team.name).evaluate().isNotEmpty)
          .length;

      // Atlantic is the default selection.
      expect(find.text('Choose the team to replace'), findsOneWidget);
      expect(shownCount(atlanticPool), 10);
      expect(shownCount(pacificPool), 0);

      await tester.tap(find.text('Pacific'));
      await tester.pumpAndSettle();

      expect(find.text('Choose the team to replace'), findsOneWidget);
      expect(shownCount(pacificPool), 10);
      expect(shownCount(atlanticPool), 0);
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
      expect(
        kLeagueTeamPool
            .where((team) => team.conference == Conference.atlantic)
            .map((team) => team.abbreviation),
        contains(franchise?.replacedTeamAbbreviation),
        reason: 'defaults to a random team in the chosen (Atlantic) conference',
      );
      expect(
        kStarterPalettes.map((palette) => palette.primaryHex),
        contains(franchise?.team.colors.primaryHex),
        reason: 'defaults to one of the curated starter palettes',
      );
    },
  );

  testWidgets('exactly one color palette is selected by default, and tapping a '
      'different one switches the selection', (tester) async {
    await pumpHarness(tester);

    Finder swatchFinder(int index) =>
        find.byKey(ValueKey(kStarterPalettes[index].primaryHex));
    bool isSelected(int index) => find
        .descendant(of: swatchFinder(index), matching: find.byIcon(Icons.check))
        .evaluate()
        .isNotEmpty;

    final selectedIndices = [
      for (var i = 0; i < kStarterPalettes.length; i++)
        if (isSelected(i)) i,
    ];
    expect(selectedIndices, hasLength(1));

    final targetIndex = (selectedIndices.first + 1) % kStarterPalettes.length;
    await tester.ensureVisible(swatchFinder(targetIndex));
    await tester.pumpAndSettle();
    await tester.tap(swatchFinder(targetIndex));
    await tester.pump();

    expect(isSelected(targetIndex), isTrue);
    expect(isSelected(selectedIndices.first), isFalse);
  });

  testWidgets(
    'exactly one team is checked, and tapping a different one switches the '
    'selection',
    (tester) async {
      await pumpHarness(tester);

      Checkbox checkboxAt(int index) =>
          tester.widget<Checkbox>(find.byType(Checkbox).at(index));

      // A default selection is pre-checked -- exactly one, since it behaves
      // like a radio group despite being drawn as checkboxes.
      final checkedCount = List.generate(
        10,
        checkboxAt,
      ).where((c) => c.value == true).length;
      expect(checkedCount, 1);

      final firstWasChecked = checkboxAt(0).value!;
      final targetIndex = firstWasChecked ? 1 : 0;
      final targetCheckbox = find.byType(Checkbox).at(targetIndex);
      await tester.ensureVisible(targetCheckbox);
      await tester.pumpAndSettle();
      await tester.tap(targetCheckbox);
      await tester.pump();

      expect(checkboxAt(targetIndex).value, isTrue);
      expect(checkboxAt(0).value, targetIndex == 0);
    },
  );
}
