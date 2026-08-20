import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/coach/domain/coach.dart';
import 'package:womensbballmgr/features/coach/domain/coach_archetype.dart';
import 'package:womensbballmgr/features/coach/domain/coach_stats.dart';
import 'package:womensbballmgr/features/coach/persistence/coach_json.dart';

void main() {
  test(
    'round-trips seasonsAsHeadCoach/careerWins/careerLosses/'
    'championshipsWon (2026-08-19, a direct GM ask: "Head coach needs a '
    'detail screen... career wins/losses, any trophies, how long '
    'they\'ve been a head coach")',
    () {
      const coach = Coach(
        name: 'Jordan Ellis',
        stats: CoachStats.neutral,
        archetype: CoachArchetype.steadyHand,
        age: 55,
        seasonsAsHeadCoach: 5,
        careerWins: 120,
        careerLosses: 80,
        championshipsWon: 2,
      );

      final restored = coachFromJson(coachToJson(coach));

      expect(restored.seasonsAsHeadCoach, 5);
      expect(restored.careerWins, 120);
      expect(restored.careerLosses, 80);
      expect(restored.championshipsWon, 2);
    },
  );

  test('career fields round-trip at their 0 default', () {
    const coach = Coach(
      name: 'Jordan Ellis',
      stats: CoachStats.neutral,
      archetype: CoachArchetype.steadyHand,
    );

    final restored = coachFromJson(coachToJson(coach));

    expect(restored.seasonsAsHeadCoach, 0);
    expect(restored.careerWins, 0);
    expect(restored.careerLosses, 0);
    expect(restored.championshipsWon, 0);
  });
}
