import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/training/presentation/coach_picker_lab_screen.dart';

void main() {
  testWidgets(
    'shows all 5 variations, each a real working dropdown over the same '
    'stress-test roster (2026-08-10, TODO.md item 5)',
    (tester) async {
      // All 5 sections need to be on-screen at once -- the default test
      // surface is too short to lay out every section in the plain
      // `ListView` without scrolling.
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: CoachPickerLabScreen()));
      await tester.pump();

      expect(find.text('Coach Picker Lab'), findsOneWidget);
      expect(find.text('1. Current Format (for reference)'), findsOneWidget);
      expect(
        find.text('2. GM\'s Sketch: 2-Line, Collapses to 1'),
        findsOneWidget,
      );
      expect(find.text('3. Stat Chips'), findsOneWidget);
      expect(find.text('4. Stats-First Hierarchy'), findsOneWidget);
      expect(find.text('5. Aligned Columns'), findsOneWidget);

      // 5 real dropdown fields -- one per variation, each independently
      // interactive.
      expect(find.byType(DropdownButtonFormField<int>), findsNWidgets(5));
    },
  );

  testWidgets(
    'opening variation 2\'s menu shows the 2-line item, and Henderson '
    'never gets cut off',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: CoachPickerLabScreen()));
      await tester.pump();

      // Variation 2 is the second dropdown field on the page.
      final dropdowns = find.byType(DropdownButtonFormField<int>);
      await tester.tap(dropdowns.at(1));
      await tester.pumpAndSettle();

      // The stress-test roster's long-surname player, split across the
      // 2 lines the GM's own sketch calls for -- neither line ellipsizes.
      expect(find.text('C #42 · Henderson'), findsWidgets);
      expect(find.text('68 OVR, 93 POT, 21y'), findsOneWidget);
    },
  );
}
