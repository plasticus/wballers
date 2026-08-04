import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/coach/domain/coach_stats.dart';

void main() {
  test('neutral is the midpoint on every stat', () {
    const stats = CoachStats.neutral;

    expect(stats.offense, 50);
    expect(stats.defense, 50);
    expect(stats.development, 50);
    expect(stats.motivation, 50);
    expect(stats.management, 50);
  });

  test('overall averages the five stats, rounded', () {
    const stats = CoachStats(
      offense: 80,
      defense: 60,
      development: 50,
      motivation: 70,
      management: 40,
    );

    // (80 + 60 + 50 + 70 + 40) / 5 = 60
    expect(stats.overall, 60);
  });

  test('overall rounds to the nearest int', () {
    const stats = CoachStats(
      offense: 99,
      defense: 99,
      development: 99,
      motivation: 99,
      management: 98,
    );

    // 494 / 5 = 98.8 -> 99
    expect(stats.overall, 99);
  });

  test('accepts the minimum rating of 1 on every stat', () {
    const stats = CoachStats(
      offense: 1,
      defense: 1,
      development: 1,
      motivation: 1,
      management: 1,
    );

    expect(stats.overall, 1);
  });

  test('accepts the maximum rating of 99 on every stat', () {
    const stats = CoachStats(
      offense: 99,
      defense: 99,
      development: 99,
      motivation: 99,
      management: 99,
    );

    expect(stats.overall, 99);
  });

  test('rejects a stat of 0', () {
    expect(
      () => CoachStats(
        offense: 0,
        defense: 50,
        development: 50,
        motivation: 50,
        management: 50,
      ),
      throwsA(isA<AssertionError>()),
    );
  });

  test('rejects a stat of 100', () {
    expect(
      () => CoachStats(
        offense: 50,
        defense: 50,
        development: 50,
        motivation: 50,
        management: 100,
      ),
      throwsA(isA<AssertionError>()),
    );
  });
}
