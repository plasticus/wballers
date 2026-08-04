import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/app/app.dart';

void main() {
  testWidgets('shows the offline franchise foundation shell', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: WomensBasketballManagerApp()),
    );

    expect(find.text('Women\'s Basketball Manager'), findsOneWidget);
    expect(find.text('Dashboard banner — reserved'), findsOneWidget);
    expect(find.text('Team'), findsOneWidget);
    expect(find.text('League'), findsOneWidget);
  });
}
