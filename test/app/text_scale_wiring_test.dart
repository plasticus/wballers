import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/app/app.dart';
import 'package:womensbballmgr/app/app_preferences.dart';

void main() {
  testWidgets(
    'the textScaleProvider value reaches the widget tree\'s MediaQuery',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [textScaleProvider.overrideWith((ref) => 1.5)],
          child: const WomensBasketballManagerApp(),
        ),
      );

      final context = tester.element(find.text('Women\'s Basketball Manager'));
      expect(MediaQuery.textScalerOf(context).scale(10), closeTo(15, 1e-9));
    },
  );

  testWidgets('an extreme textScaleProvider value stays within bounds', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [textScaleProvider.overrideWith((ref) => 10.0)],
        child: const WomensBasketballManagerApp(),
      ),
    );

    final context = tester.element(find.text('Women\'s Basketball Manager'));
    final scale = MediaQuery.textScalerOf(context).scale(1.0);
    expect(scale, lessThanOrEqualTo(kMaxTextScale));
  });
}
