import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/core/widgets/state_views.dart';

void main() {
  testWidgets('LoadingView shows a bouncing basketball and optional message', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: LoadingView(message: 'Loading roster…')),
    );

    expect(find.text('🏀'), findsOneWidget);
    expect(find.text('Loading roster…'), findsOneWidget);
    expect(find.bySemanticsLabel('Loading'), findsOneWidget);

    // Advance the repeating bounce animation a few frames without throwing.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('EmptyStateView shows the message and an optional action', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EmptyStateView(
          message: 'No franchises yet',
          action: TextButton(onPressed: () {}, child: const Text('Create one')),
        ),
      ),
    );

    expect(find.text('No franchises yet'), findsOneWidget);
    expect(find.text('Create one'), findsOneWidget);
  });

  testWidgets('ErrorStateView shows the message and triggers retry', (
    tester,
  ) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: ErrorStateView(
          message: 'Could not load save',
          onRetry: () => retried = true,
        ),
      ),
    );

    expect(find.text('Could not load save'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retried, isTrue);
  });
}
