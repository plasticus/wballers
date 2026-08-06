import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/coach/domain/coach.dart';
import 'package:womensbballmgr/features/coach/domain/coach_archetype.dart';
import 'package:womensbballmgr/features/coach/domain/coach_stats.dart';
import 'package:womensbballmgr/features/portrait/domain/portrait_appearance.dart';
import 'package:womensbballmgr/features/portrait/generation/portrait_generator.dart';

void main() {
  test('stores the coach\'s name and stats', () {
    const coach = Coach(
      name: 'Jordan Ellis',
      stats: CoachStats.neutral,
      archetype: CoachArchetype.steadyHand,
    );

    expect(coach.name, 'Jordan Ellis');
    expect(coach.stats.overall, 50);
  });

  test('copyWithAppearance replaces only the appearance', () {
    const coach = Coach(
      name: 'Jordan Ellis',
      stats: CoachStats.neutral,
      archetype: CoachArchetype.steadyHand,
    );
    const newAppearance = PortraitAppearance(
      baseSprite: kDefaultBaseSprite,
      skinTone: 'deep',
      hairColor: 'black',
      eyes: 'eyes_1center',
      nose: 'nose_1',
      mouth: 'mouth_1',
      isCoach: true,
    );

    final updated = coach.copyWithAppearance(newAppearance);

    expect(updated.name, coach.name);
    expect(updated.stats.overall, coach.stats.overall);
    expect(updated.appearance, newAppearance);
  });
}
