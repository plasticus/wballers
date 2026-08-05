import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/player/domain/player.dart';
import 'package:womensbballmgr/features/player/generation/player_generator.dart';
import 'package:womensbballmgr/features/portrait/domain/portrait_height_tier.dart';

import '../../roster/domain/roster_test_helpers.dart';

void main() {
  test('72 inches (6\'0") is baseline, not tall', () {
    expect(
      PortraitHeightTier.of(playerWithOverall(50, heightInches: 72)),
      PortraitHeightTier.baseline,
    );
  });

  test('73 inches (6\'1") is tall', () {
    expect(
      PortraitHeightTier.of(playerWithOverall(50, heightInches: 73)),
      PortraitHeightTier.tall,
    );
  });

  test('76 inches (6\'4") is tall, not tallest', () {
    expect(
      PortraitHeightTier.of(playerWithOverall(50, heightInches: 76)),
      PortraitHeightTier.tall,
    );
  });

  test('77 inches (6\'5") is tallest', () {
    expect(
      PortraitHeightTier.of(playerWithOverall(50, heightInches: 77)),
      PortraitHeightTier.tallest,
    );
  });

  test('the shortest possible height is baseline', () {
    expect(
      PortraitHeightTier.of(
        playerWithOverall(50, heightInches: kMinHeightInches),
      ),
      PortraitHeightTier.baseline,
    );
  });

  test('the tallest possible height is tallest', () {
    expect(
      PortraitHeightTier.of(
        playerWithOverall(50, heightInches: kMaxHeightInches),
      ),
      PortraitHeightTier.tallest,
    );
  });

  test('across a real generated sample, the tiers land roughly 40/40/20, '
      'tallest kept the rarest', () {
    final random = Random(2024);
    const sampleSize = 2000;
    final counts = {for (final tier in PortraitHeightTier.values) tier: 0};
    for (var i = 0; i < sampleSize; i++) {
      final player = generatePlayer(
        random,
        primaryPosition: Position.values[i % Position.values.length],
      );
      counts[PortraitHeightTier.of(player)] =
          counts[PortraitHeightTier.of(player)]! + 1;
    }

    final baselineShare = counts[PortraitHeightTier.baseline]! / sampleSize;
    final tallShare = counts[PortraitHeightTier.tall]! / sampleSize;
    final tallestShare = counts[PortraitHeightTier.tallest]! / sampleSize;

    expect(baselineShare, closeTo(0.42, 0.05));
    expect(tallShare, closeTo(0.38, 0.05));
    expect(tallestShare, closeTo(0.20, 0.05));
    expect(
      tallestShare,
      lessThan(baselineShare),
      reason: 'tallest tier should stay the rarest',
    );
  });
}
