import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/core/persistence/portrait_cache_provider.dart';
import 'package:womensbballmgr/features/portrait/domain/portrait_appearance.dart';
import 'package:womensbballmgr/features/portrait/generation/portrait_generator.dart';
import 'package:womensbballmgr/features/portrait/presentation/portrait_image.dart';

import '../../../support/in_memory_portrait_cache.dart';

const _appearance = PortraitAppearance(
  baseSprite: kDefaultBaseSprite,
  skinTone: 'medium',
  hairColor: 'black',
  eyes: 'eyes_1center',
  nose: 'nose_1',
  mouth: 'mouth_1',
  isCoach: false,
);

Future<void> _pumpPortrait(
  WidgetTester tester, {
  PortraitAppearance? appearance,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        portraitCacheProvider.overrideWithValue(InMemoryPortraitCache()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: PortraitImage(
            saveId: 'franchise-1',
            ownerId: 'p1',
            appearance: appearance,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows an accessible fallback when appearance is null', (
    tester,
  ) async {
    await _pumpPortrait(tester);
    await tester.pump();

    expect(find.byIcon(Icons.person), findsOneWidget);
    expect(find.bySemanticsLabel('No portrait available'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('renders the portrait image once it resolves', (tester) async {
    await _pumpPortrait(tester, appearance: _appearance);

    // First frame: still rendering, falls back.
    expect(find.byIcon(Icons.person), findsOneWidget);

    // Real asset decode/PNG-encode work (rootBundle.load,
    // ui.instantiateImageCodec) can't progress inside testWidgets' fake
    // async zone -- runAsync switches to the real zone so it can actually
    // complete; several rounds are needed since the multi-layer decode
    // chain takes real wall-clock time.
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }

    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Icons.person), findsNothing);
  });
}
