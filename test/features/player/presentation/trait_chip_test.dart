import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/player/domain/trait.dart';
import 'package:womensbballmgr/features/player/presentation/trait_chip.dart';

void main() {
  testWidgets('tapping a trait chip opens a popup with its description', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: TraitChip(trait: Trait.leader)),
      ),
    );

    // Not shown until tapped.
    expect(find.text(Trait.leader.description), findsNothing);

    await tester.tap(find.text('Leader'));
    await tester.pumpAndSettle();

    expect(find.text('Leader'), findsWidgets); // chip + dialog title
    expect(find.text(Trait.leader.description), findsOneWidget);
    // Leader's opposite (Malcontent) gets a called-out mutual-exclusion
    // note.
    expect(find.textContaining('Malcontent'), findsOneWidget);

    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

    expect(find.text(Trait.leader.description), findsNothing);
  });

  testWidgets(
    'a trait with no opposite doesn\'t show a mutual-exclusion note',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: TraitChip(trait: Trait.gymRat)),
        ),
      );

      await tester.tap(find.text('Gym Rat'));
      await tester.pumpAndSettle();

      expect(find.text(Trait.gymRat.description), findsOneWidget);
      expect(find.textContaining('Mutually exclusive'), findsNothing);
    },
  );
}
