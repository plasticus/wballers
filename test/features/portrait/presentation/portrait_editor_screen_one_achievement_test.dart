import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/core/persistence/save_repository_provider.dart';
import 'package:womensbballmgr/features/portrait/presentation/portrait_editor_screen.dart';

import '../../../support/in_memory_save_repository.dart';
import '../../../support/portrait_test_helpers.dart';

void main() {
  testWidgets(
    'still hidden for a player with exactly 1 achievement (2026-08-10: '
    'unlock needs a second award, not the first -- kept in its own file, '
    'same reasoning as the other 2 asset-loading portrait editor tests)',
    (tester) async {
      final franchise = franchiseForPortraitTests(
        firstPlayerAchievementCount: 1,
      );
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
