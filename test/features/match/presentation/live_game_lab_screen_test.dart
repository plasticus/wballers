import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/match/presentation/live_game_lab_screen.dart';

/// Covers the Step-mode navigation added 2026-08-18 (a direct GM ask,
/// "instant replay style" stepping backward, plus a "Highlight" jump to
/// the next point/steal/block) -- exercised via the dev-lab's demo mode
/// (no `franchise`/`game` given), which needs no save/provider setup at
/// all and drives the exact same real `simulateMatchLive` engine the real
/// screen does.
void main() {
  Future<void> pumpLab(WidgetTester tester) async {
    // The Play/Speed controls sit well below the ad banner/score card/
    // court diagram in a scrollable ListView -- needs a taller surface to
    // be on-screen and tap-hittable, same pattern every other screen's
    // tests in this repo already use for a similarly long layout.
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LiveGameLabScreen())),
    );
    await tester.pump();
  }

  Future<void> switchToStep(WidgetTester tester) async {
    await tester.tap(find.text('Step'));
    await tester.pump();
  }

  testWidgets('Prev is disabled before any beat has been shown, and stepping '
      'forward then back returns to the same headline', (tester) async {
    await pumpLab(tester);
    await switchToStep(tester);

    // Nothing shown yet -- Prev has nothing to go back to.
    final prevBefore = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('Prev'),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(prevBefore.onPressed, isNull);

    // First tap starts the game and shows the tip-off (real engine,
    // real translator -- always the first beat). Snapshotting every
    // rendered string is more robust than matching one phrase: the
    // real phrase bank has several tip-off variants, picked at random.
    List<String> textSnapshot() => tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .toList();

    await tester.tap(find.text('Next'));
    await tester.pump();
    final afterFirstBeat = textSnapshot();

    // Advance one more beat, then step back -- the whole screen should
    // read exactly like it did right after the first beat again.
    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(
      textSnapshot(),
      isNot(afterFirstBeat),
      reason: 'sanity check: the 2nd beat really did change the screen',
    );

    await tester.tap(find.text('Prev'));
    await tester.pump();
    expect(textSnapshot(), afterFirstBeat);
  });

  testWidgets(
    'Highlight jumps past ordinary beats straight to the next scoring '
    'play',
    (tester) async {
      await pumpLab(tester);
      await switchToStep(tester);

      await tester.tap(find.text('Next')); // starts the game, tip-off
      await tester.pump();

      await tester.tap(find.text('Highlight'));
      await tester.pump();

      // Whatever beat Highlight landed on scored points -- the score bug
      // (top of the card) shows a nonzero total for at least one side.
      final scoreTexts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>()
          .where((t) => RegExp(r'^\d+$').hasMatch(t))
          .map(int.parse)
          .toList();
      expect(scoreTexts.any((s) => s > 0), isTrue);
    },
  );
}
