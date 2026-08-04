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
      offense: 100,
      defense: 100,
      development: 100,
      motivation: 100,
      management: 99,
    );

    // 499 / 5 = 99.8 -> 100
    expect(stats.overall, 100);
  });

  test('rejects a stat below 0', () {
    expect(
      () => CoachStats(
        offense: -1,
        defense: 50,
        development: 50,
        motivation: 50,
        management: 50,
      ),
      throwsA(isA<AssertionError>()),
    );
  });

  test('rejects a stat above 100', () {
    expect(
      () => CoachStats(
        offense: 50,
        defense: 50,
        development: 50,
        motivation: 50,
        management: 101,
      ),
      throwsA(isA<AssertionError>()),
    );
  });
}
