import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/core/persistence/save_repository_provider.dart';
import 'package:womensbballmgr/features/franchise/application/current_franchise_provider.dart';
import 'package:womensbballmgr/features/portrait/presentation/portrait_editor_screen.dart';

import '../../../support/in_memory_save_repository.dart';
import '../../../support/portrait_nickname_test_helpers.dart';
import '../../../support/portrait_test_helpers.dart';

/// See `portrait_editor_screen_nickname_edit_test.dart`'s own doc comment
/// for why this is its own file rather than a 2nd `testWidgets` sharing
/// one.
void main() {
  testWidgets('clearing the nickname field removes it entirely', (
    tester,
  ) async {
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

    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.widgetWithText(FilledButton, 'Save Portrait'));
    await letPortraitAsyncWorkFinish(tester);

    final updated = container.read(currentFranchiseProvider).value;
    expect(updated!.roster.first.player.nickname, isNull);
  });
}
