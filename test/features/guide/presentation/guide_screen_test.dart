import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/guide/presentation/guide_screen.dart';

/// Covers the plain-language reference doc reachable from the app's main
/// AppBar chrome (2026-08-19, a direct GM ask). No franchise/provider
/// setup needed at all -- this screen is static content, the same reason
/// it's a plain `StatelessWidget` with no `Franchise` param.
void main() {
  Future<void> pumpGuide(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: GuideScreen()));
  }

  testWidgets('shows a Coaching section covering all 5 coach stats', (
    tester,
  ) async {
    await pumpGuide(tester);

    expect(find.text('Coaching'), findsOneWidget);
    for (final label in [
      'Offense',
      'Defense',
      'Development',
      'Motivation',
      'Management',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('shows the exact same Training section the Training screen '
      'itself uses -- one source of copy, not 2 that can drift apart', (
    tester,
  ) async {
    await pumpGuide(tester);

    expect(find.text('How Training Works'), findsOneWidget);
    expect(find.textContaining('Team Focus decides'), findsOneWidget);
  });
}
