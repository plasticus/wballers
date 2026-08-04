import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/core/persistence/save_repository_provider.dart';
import 'package:womensbballmgr/features/franchise/application/current_franchise_provider.dart';
import 'package:womensbballmgr/features/portrait/presentation/portrait_editor_screen.dart';

import '../../../support/in_memory_save_repository.dart';
import '../../../support/portrait_test_helpers.dart';

void main() {
  testWidgets('editing a player\'s nickname and saving persists it', (
    tester,
  ) async {
    final franchise = franchiseForPortraitTests();
    final targetId = franchise.roster.first.player.id;
    final repository = InMemorySaveRepository();

    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [saveRepositoryProvider.overrideWithValue(repository)],
        child: Consumer(
          builder: (context, ref, _) {
            container = ProviderScope.containerOf(context);
            return MaterialApp(
              home: PortraitEditorScreen(
                franchise: franchise,
                playerId: targetId,
              ),
            );
          },
        ),
      ),
    );
    await container
        .read(currentFranchiseProvider.notifier)
        .createFranchise(franchise);
    await letPortraitAsyncWorkFinish(tester);

    await tester.enterText(find.byType(TextField), 'The Wall');
    await tester.tap(find.widgetWithText(FilledButton, 'Save Portrait'));
    await letPortraitAsyncWorkFinish(tester);

    final updated = container.read(currentFranchiseProvider).value;
    final updatedPlayer = updated!.roster
        .firstWhere((m) => m.player.id == targetId)
        .player;
    expect(updatedPlayer.nickname, 'The Wall');
  });
}
