import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/core/persistence/save_repository_provider.dart';
import 'package:womensbballmgr/features/franchise/application/current_franchise_provider.dart';
import 'package:womensbballmgr/features/portrait/presentation/portrait_editor_screen.dart';

import '../../../support/in_memory_save_repository.dart';
import '../../../support/portrait_test_helpers.dart';

/// See `portrait_editor_screen_nickname_edit_test.dart`'s own doc comment
/// for why this is its own file rather than sharing one with the other
/// nickname-field tests.
void main() {
  testWidgets(
    'a player who has never earned a nickname gets no nickname field at '
    'all -- never a free way to hand one out from scratch',
    (tester) async {
      final franchise = franchiseForPortraitTests();
      final targetId = franchise.roster.first.player.id;
      expect(franchise.roster.first.player.nickname, isNull);
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

      expect(find.text('Nickname'), findsNothing);
      expect(find.byType(TextField), findsNothing);
    },
  );
}
