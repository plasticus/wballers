import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/training/domain/player_rating_field.dart';
import 'package:womensbballmgr/features/training/domain/training_report.dart';
import 'package:womensbballmgr/features/training/presentation/player_growth_card.dart';

void main() {
  testWidgets('field-delta chips sort largest growth first, regardless of the '
      'result\'s own map insertion order (2026-08-10, TODO.md item 5)', (
    tester,
  ) async {
    const result = PlayerGrowthResult(
      playerId: 'p1',
      // Deliberately not in descending order, and not alphabetical
      // either, so a passing test can't be an accident of either.
      fieldDeltas: {
        PlayerRatingField.disruption: 3,
        PlayerRatingField.agility: 7,
        PlayerRatingField.passing: 5,
      },
      overallBefore: 50,
      overallAfter: 51,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PlayerGrowthCard(playerName: 'PG Test Player', result: result),
        ),
      ),
    );
    await tester.pump();

    final agilityX = tester.getTopLeft(find.text('Agility +7')).dx;
    final passingX = tester.getTopLeft(find.text('Passing +5')).dx;
    final disruptionX = tester.getTopLeft(find.text('Disruption +3')).dx;
    expect(agilityX, lessThan(passingX));
    expect(passingX, lessThan(disruptionX));
  });

  testWidgets(
    'a whole-point OVR change gets its own callout, separate from the '
    'field-delta chips (2026-08-18, a direct GM ask: "I want to be '
    'notified if their OVR went up by 1 (eg, OVR 67 -> 68)")',
    (tester) async {
      const result = PlayerGrowthResult(
        playerId: 'p1',
        fieldDeltas: {PlayerRatingField.agility: 7},
        overallBefore: 67,
        overallAfter: 68,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlayerGrowthCard(
              playerName: 'PG Test Player',
              result: result,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('OVR 67 → 68'), findsOneWidget);
    },
  );

  testWidgets(
    'no OVR callout when the whole-point overall rating did not actually '
    'move, even if individual fields did',
    (tester) async {
      const result = PlayerGrowthResult(
        playerId: 'p1',
        fieldDeltas: {PlayerRatingField.agility: 2},
        overallBefore: 67,
        overallAfter: 67,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlayerGrowthCard(
              playerName: 'PG Test Player',
              result: result,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('OVR 67'), findsNothing);
    },
  );
}
