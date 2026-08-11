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
}
