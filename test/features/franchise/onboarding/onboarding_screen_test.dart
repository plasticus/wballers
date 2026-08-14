import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/core/persistence/portrait_cache_provider.dart';
import 'package:womensbballmgr/core/persistence/save_repository_provider.dart';
import 'package:womensbballmgr/features/franchise/application/current_franchise_provider.dart';
import 'package:womensbballmgr/features/franchise/onboarding/coach_selection_screen.dart';
import 'package:womensbballmgr/features/franchise/onboarding/expansion_franchise_factory.dart'
    show kStarterPalettes;
import 'package:womensbballmgr/features/franchise/onboarding/onboarding_screen.dart';
import 'package:womensbballmgr/features/franchise/onboarding/quick_start_teams.dart';
import 'package:womensbballmgr/features/franchise/onboarding/team_emoji_options.dart';
import 'package:womensbballmgr/features/league/domain/initial_league.dart';
import 'package:womensbballmgr/features/league/domain/team.dart';
import 'package:womensbballmgr/features/league/team_row.dart';

import '../../../support/in_memory_portrait_cache.dart';
import '../../../support/in_memory_save_repository.dart';
import '../../../support/portrait_test_helpers.dart';

void main() {
  Future<void> pumpHarness(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          saveRepositoryProvider.overrideWithValue(InMemorySaveRepository()),
          // The real FilePortraitCache calls path_provider, a plugin
          // channel that isn't reliably available under flutter test.
          portraitCacheProvider.overrideWithValue(InMemoryPortraitCache()),
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

  Future<void> fillIdentityFields(WidgetTester tester) async {
    await tester.enterText(
      find.widgetWithText(TextField, 'Name of General Manager'),
      'Jordan Ellis',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Team Name'),
      'Comets',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Home City'),
      'Springfield',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'State/Province'),
      'IL',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Abbr.'), 'CMT');
    await tester.pump();
  }

  /// Fills the identity step, continues to coach selection, picks the
  /// first candidate, and confirms -- the full path to a real franchise.
  /// Returns the name of whichever candidate got picked, so the caller
  /// can confirm the franchise's actual head coach matches it.
  Future<String> createFranchiseThroughOnboarding(WidgetTester tester) async {
    await fillIdentityFields(tester);

    final continueButton = find.widgetWithText(FilledButton, 'Continue');
    await tester.ensureVisible(continueButton);
    await tester.pumpAndSettle();
    await tester.tap(continueButton);
    // Not pumpAndSettle -- CoachSelectionScreen awaits the real bundled
    // portrait assets, and its LoadingView's perpetually-repeating
    // bouncing-basketball animation can make pumpAndSettle declare a
    // (false) timeout while that's still pending. letPortraitAsyncWorkFinish's
    // own fixed ~2 real seconds usually covers it, but isn't guaranteed
    // under heavier load, so retry a few more rounds rather than assert
    // on a fixed budget.
    final confirmButtonFinder = find.widgetWithText(
      FilledButton,
      'Confirm & Create Franchise',
    );
    for (var attempt = 0; attempt < 5; attempt++) {
      if (confirmButtonFinder.evaluate().isNotEmpty) break;
      await letPortraitAsyncWorkFinish(tester);
    }

    expect(find.byType(CoachSelectionScreen), findsOneWidget);
    // Disabled until a candidate is actually picked.
    expect(tester.widget<FilledButton>(confirmButtonFinder).onPressed, isNull);

    // Scoped to this screen -- the previous route (still mounted offstage
    // underneath) has its own InkWells (color swatches, emoji tiles) that
    // an unscoped `find.byType(InkWell).first` could match instead.
    final firstCandidateCard = find
        .descendant(
          of: find.byType(CoachSelectionScreen),
          matching: find.byType(InkWell),
        )
        .first;
    final pickedName = tester
        .widgetList<Text>(
          find.descendant(of: firstCandidateCard, matching: find.byType(Text)),
        )
        .first
        .data!;
    await tester.tap(firstCandidateCard);
    await tester.pumpAndSettle();

    expect(
      tester.widget<FilledButton>(confirmButtonFinder).onPressed,
      isNotNull,
      reason: 'enabled once a candidate is picked',
    );

    await tester.ensureVisible(confirmButtonFinder);
    await tester.pumpAndSettle();
    await tester.tap(confirmButtonFinder);
    await tester.pumpAndSettle();

    return pickedName;
  }

  testWidgets('the continue button is disabled until every field is filled', (
    tester,
  ) async {
    await pumpHarness(tester);

    FilledButton continueButton() => tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continue'),
    );

    expect(continueButton().onPressed, isNull);

    await tester.enterText(
      find.widgetWithText(TextField, 'Name of General Manager'),
      'Jordan Ellis',
    );
    await tester.pump();
    expect(continueButton().onPressed, isNull);

    await tester.enterText(
      find.widgetWithText(TextField, 'Team Name'),
      'Comets',
    );
    await tester.pump();
    expect(continueButton().onPressed, isNull);

    await tester.enterText(
      find.widgetWithText(TextField, 'Home City'),
      'Springfield',
    );
    await tester.pump();
    expect(continueButton().onPressed, isNull);

    await tester.enterText(
      find.widgetWithText(TextField, 'State/Province'),
      'IL',
    );
    await tester.pump();
    expect(continueButton().onPressed, isNull);

    await tester.enterText(find.widgetWithText(TextField, 'Abbr.'), 'CMT');
    await tester.pump();

    expect(continueButton().onPressed, isNotNull);
  });

  testWidgets('tapping a Quick Start club fills in GM name, team name, city, '
      'state, abbreviation, and the emoji -- and every field stays '
      'hand-editable afterward (2026-08-14, a direct GM ask)', (tester) async {
    await pumpHarness(tester);

    final preset = kQuickStartTeams.first;
    await tester.tap(find.text(preset.clubName));
    await tester.pump();

    String textOf(String label) => tester
        .widget<TextField>(find.widgetWithText(TextField, label))
        .controller!
        .text;

    expect(textOf('Team Name'), preset.clubName);
    expect(textOf('Home City'), preset.homeCity);
    expect(textOf('State/Province'), preset.homeState);
    expect(textOf('Abbr.'), preset.abbreviation);
    expect(preset.gmNames, contains(textOf('Name of General Manager')));
    // Every emoji option this preset could have picked renders somewhere
    // -- specifically confirming *this* preset's own emoji shows as
    // selected would need reaching into `_EmojiOption`'s internal
    // selected state, more than this test needs; the identity preview
    // card rendering the right emoji is the real, user-visible signal.
    expect(find.textContaining(preset.emoji), findsWidgets);

    // Still freely hand-editable afterward -- not locked in by the tap.
    await tester.enterText(
      find.widgetWithText(TextField, 'Team Name'),
      'Something Else Entirely',
    );
    await tester.pump();
    expect(textOf('Team Name'), 'Something Else Entirely');
  });

  testWidgets('shows a live preview of the identity as it\'s typed', (
    tester,
  ) async {
    await pumpHarness(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Name of General Manager'),
      'Corey M',
    );
    await tester.pump();
    expect(find.text('Corey M, General Manager'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Team Name'),
      'Sunfish',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Home City'),
      'Seattle',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'State/Province'),
      'WA',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Abbr.'), 'SEA');
    await tester.pump();

    // The preview delegates to the real TeamRow widget (2026-08-10) --
    // typed fields show up through it exactly as they would on the real
    // League screen, not a separately hand-formatted preview string.
    // Scoped to TeamRow specifically -- "Sunfish" also matches the still-
    // mounted TextField's own EditableText otherwise.
    expect(find.text('Corey M, General Manager'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(TeamRow), matching: find.text('Sunfish')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(TeamRow),
        matching: find.text('SEA · Seattle, WA'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'shows 10 of the conference\'s 20-team pool, and swaps when it changes',
    (tester) async {
      // The Pacific/Atlantic SegmentedButton this test taps sits below
      // the Quick Start row (2026-08-14) -- tall enough that the default
      // test viewport hides it off the bottom of the screen, same
      // "needs real height, this content doesn't lazily build" reasoning
      // other tall-page tests in this codebase already handle this way.
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

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
    'continuing hands off to coach selection, and confirming a candidate '
    'creates and saves the franchise',
    (tester) async {
      await pumpHarness(tester);

      final pickedCoachName = await createFranchiseThroughOnboarding(tester);

      expect(find.text('Open onboarding'), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(find.byType(CoachSelectionScreen), findsNothing);

      final context = tester.element(find.text('Open onboarding'));
      final container = ProviderScope.containerOf(context);
      final franchise = container.read(currentFranchiseProvider).value;

      expect(franchise?.team.name, 'Comets');
      expect(franchise?.gmName, 'Jordan Ellis');
      expect(franchise?.team.location, 'Springfield, IL');
      expect(
        franchise?.coach.name,
        pickedCoachName,
        reason:
            'the franchise\'s head coach is whichever candidate was '
            'picked, not an unrelated auto-generated one',
      );
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
      final drawnEmoji = franchise!.league.aiTeams
          .map((aiTeam) => aiTeam.team.emoji)
          .toSet();
      expect(
        drawnEmoji.contains(franchise.team.emoji),
        isFalse,
        reason: 'the GM\'s emoji always comes from outside this league',
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

  bool emojiOptionSelected(WidgetTester tester, String emoji) {
    final container = tester.widget<Container>(
      find.descendant(
        of: find.byKey(ValueKey(emoji)),
        matching: find.byType(Container),
      ),
    );
    final border = (container.decoration! as BoxDecoration).border! as Border;
    return border.top.width == 3;
  }

  testWidgets('offers the curated emoji pool minus whatever this league drew', (
    tester,
  ) async {
    await pumpHarness(tester);

    expect(find.text('Team emoji'), findsOneWidget);

    // Scroll the emoji grid into view so its tiles actually build --
    // GridView.builder only builds items near its own viewport (plus a
    // cache extent margin), not the whole ~100-entry pool at once.
    await tester.ensureVisible(find.text('Team emoji'));
    await tester.pumpAndSettle();

    final tileCount = kTeamEmojiOptions
        .where((emoji) => find.byKey(ValueKey(emoji)).evaluate().isNotEmpty)
        .length;
    // At least most of the curated pool should be offered -- a handful
    // may be filtered out if this league happened to draw a team using
    // the same emoji, but it should never be anywhere close to zero.
    expect(tileCount, greaterThan(kTeamEmojiOptions.length ~/ 2));
  });

  testWidgets('tapping an emoji tile updates the selection', (tester) async {
    await pumpHarness(tester);
    await tester.ensureVisible(find.text('Team emoji'));
    await tester.pumpAndSettle();

    // Whichever two tiles happen to be built first, purely by position --
    // avoids needing to know which one the random default landed on,
    // which (being one of ~100 options) isn't reliably built without
    // scrolling the grid's own internal viewport to it.
    final tileFinder = find.descendant(
      of: find.byType(GridView),
      matching: find.byType(InkWell),
    );
    expect(tileFinder, findsWidgets);

    String emojiOf(Finder inkWellFinder) => tester
        .widget<Text>(
          find.descendant(of: inkWellFinder, matching: find.byType(Text)),
        )
        .data!;

    final firstEmoji = emojiOf(tileFinder.at(0));
    final secondEmoji = emojiOf(tileFinder.at(1));

    await tester.tap(tileFinder.at(0));
    await tester.pump();
    expect(emojiOptionSelected(tester, firstEmoji), isTrue);

    await tester.tap(tileFinder.at(1));
    await tester.pump();
    expect(emojiOptionSelected(tester, secondEmoji), isTrue);
    expect(emojiOptionSelected(tester, firstEmoji), isFalse);
  });

  testWidgets(
    'Reroll League redraws the league and leaves a valid selection state',
    (tester) async {
      await pumpHarness(tester);

      final rerollButton = find.text('Reroll League');
      await tester.ensureVisible(rerollButton);
      await tester.pumpAndSettle();
      await tester.tap(rerollButton);
      await tester.pumpAndSettle();

      // Still exactly 10 teams shown for the current (Atlantic) conference,
      // exactly one checked -- rerolling can't leave the form in a broken
      // state.
      expect(find.byType(Checkbox), findsNWidgets(10));
      final checkedCount = List.generate(
        10,
        (i) => tester.widget<Checkbox>(find.byType(Checkbox).at(i)),
      ).where((c) => c.value == true).length;
      expect(checkedCount, 1);
    },
  );
}
