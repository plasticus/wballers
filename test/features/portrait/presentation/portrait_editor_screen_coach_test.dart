import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/core/persistence/save_repository_provider.dart';
import 'package:womensbballmgr/features/franchise/application/current_franchise_provider.dart';
import 'package:womensbballmgr/features/portrait/presentation/portrait_editor_screen.dart';

import '../../../support/in_memory_save_repository.dart';
import '../../../support/portrait_test_helpers.dart';

void main() {
  testWidgets('editing the coach (no playerId) targets the coach', (
    tester,
  ) async {
    final franchise = franchiseForPortraitTests();
    final repository = InMemorySaveRepository();

    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [saveRepositoryProvider.overrideWithValue(repository)],
        child: Consumer(
          builder: (context, ref, _) {
            container = ProviderScope.containerOf(context);
            return MaterialApp(
              home: PortraitEditorScreen(franchise: franchise),
            );
          },
        ),
      ),
    );
    await container
        .read(currentFranchiseProvider.notifier)
        .createFranchise(franchise);
    await letPortraitAsyncWorkFinish(tester);

    expect(find.text('Edit Coach Portrait'), findsOneWidget);
    // Coach-only fields are visible for a coach edit -- shown even though
    // they're below the fold, since this screen's ListView builds all its
    // children eagerly rather than lazily.
    expect(find.text('Shoulders'), findsOneWidget);
    expect(find.text('Facial hair'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Save Portrait'));
    await letPortraitAsyncWorkFinish(tester);

    final updated = container.read(currentFranchiseProvider).value;
    expect(updated?.coach.appearance, isNotNull);
    expect(updated?.coach.appearance?.isCoach, isTrue);
  });
}
