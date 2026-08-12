import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/player/presentation/player_card_widgets.dart';

import '../../roster/domain/roster_test_helpers.dart';

void main() {
  group('StarTierBadge (2026-08-10, TODO.md item 2)', () {
    testWidgets('renders one ★ per StarTier.of tier, 4-star down to '
        '1-star', (tester) async {
      final cases = {90: '★★★★', 80: '★★★', 70: '★★', 60: '★'};
      for (final entry in cases.entries) {
        final player = playerWithOverall(entry.key);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: StarTierBadge(player: player)),
          ),
        );
        await tester.pump();

        expect(
          find.text(entry.value),
          findsOneWidget,
          reason: 'overall ${entry.key}',
        );
      }
    });

    testWidgets('renders no ★ glyphs at all for a no-stars player (below '
        '60 overall)', (tester) async {
      final player = playerWithOverall(59);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: StarTierBadge(player: player)),
        ),
      );
      await tester.pump();

      expect(find.textContaining('★'), findsNothing);
    });
  });

  group('statChipTone (2026-08-11, a direct GM report tied to their known '
      'low-vision needs -- "purple font on a dark blue background... '
      'really hard for me to read")', () {
    testWidgets('uses a lighter shade in dark theme than in light theme, '
        'same hue', (tester) async {
      late Color darkTone;
      late Color lightTone;

      await tester.pumpWidget(
        MaterialApp(
          home: Theme(
            data: ThemeData(brightness: Brightness.light),
            child: Builder(
              builder: (context) {
                lightTone = statChipTone(context, Colors.purple);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Theme(
            data: ThemeData(brightness: Brightness.dark),
            child: Builder(
              builder: (context) {
                darkTone = statChipTone(context, Colors.purple);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(lightTone, Colors.purple.shade700);
      expect(darkTone, Colors.purple.shade200);
      // The dark-theme tone is meaningfully brighter (higher luminance)
      // than the light-theme one -- the whole point of the fix.
      expect(
        darkTone.computeLuminance(),
        greaterThan(lightTone.computeLuminance()),
      );
    });
  });
}
