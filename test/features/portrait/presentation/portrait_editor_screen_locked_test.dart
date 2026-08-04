import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/core/persistence/save_repository_provider.dart';
import 'package:womensbballmgr/features/portrait/presentation/portrait_editor_screen.dart';

import '../../../support/in_memory_save_repository.dart';
import '../../../support/portrait_test_helpers.dart';

void main() {
  testWidgets(
    'the special hair color picker is hidden for a player with no achievements',
    (tester) async {
      final franchise = franchiseForPortraitTests();
      final targetId = franchise.roster.first.player.id;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            saveRepositoryProvider.overrideWithValue(InMemorySaveRepository()),
          ],
          child: MaterialApp(
            home: PortraitEditorScreen(
              franchise: franchise,
              playerId: targetId,
            ),
          ),
        ),
      );
      await letPortraitAsyncWorkFinish(tester);

      expect(find.text('Special hair color (unlocked)'), findsNothing);
    },
  );
}
