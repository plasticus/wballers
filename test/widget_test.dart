import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/app/app.dart';
import 'package:womensbballmgr/core/persistence/save_repository_provider.dart';

import 'support/in_memory_save_repository.dart';

void main() {
  testWidgets('shows the offline franchise foundation shell', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          saveRepositoryProvider.overrideWithValue(InMemorySaveRepository()),
        ],
        child: const WomensBasketballManagerApp(),
      ),
    );
    await tester.pump();

    expect(find.text('Women\'s Basketball Manager'), findsOneWidget);
    expect(find.text('Dashboard banner — reserved'), findsOneWidget);
    expect(find.text('Team'), findsOneWidget);
    expect(find.text('League'), findsOneWidget);
  });
}
