import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/core/persistence/save_repository_provider.dart';
import 'package:womensbballmgr/features/franchise/application/current_franchise_provider.dart';
import 'package:womensbballmgr/features/portrait/presentation/portrait_editor_screen.dart';

import '../../../support/in_memory_save_repository.dart';
import '../../../support/portrait_nickname_test_helpers.dart';
import '../../../support/portrait_test_helpers.dart';

/// Covers the nickname field folded into the portrait editor
/// (2026-08-19, a direct GM ask: "I don't want a separate screen for
/// nicknames... if they have a nickname, put it on [the portrait
/// editor], editable") -- earning one is still the only way to *get*
/// one (`achievement_grant.dart`); this only ever offers to reword an
/// already-earned one.
void main() {
  testWidgets(
    'a player with an earned nickname shows it, pre-filled and editable',
    (tester) async {
      final franchise = franchiseForNicknameTests(nickname: 'The Wall');
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

      expect(find.text('Nickname'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'The Wall'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'The Fortress');
      await tester.tap(find.widgetWithText(FilledButton, 'Save Portrait'));
      await letPortraitAsyncWorkFinish(tester);

      final updated = container.read(currentFranchiseProvider).value;
      expect(updated!.roster.first.player.nickname, 'The Fortress');
    },
  );
}
