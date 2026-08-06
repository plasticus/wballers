import 'dart:math';

import '../../../core/generation/name_pools.dart';
import '../../../core/ratings/rating_scale.dart';
import '../domain/training_coach.dart';

/// Seed offset for training-coach generation -- keeps this random stream
/// from correlating with any other (coach=0, roster=1, league draw=2,
/// league AI rosters=3, season schedule=4, game-day advancement=5,
/// postseason=6).
const kTrainingCoachSeedOffset = 7;

/// Generates a franchise's 3 training coaches -- same random-name-pool
/// pattern `generateCoach` uses for the head coach, with a single 1-99
/// `developmentRating` apiece (a quality center plus jitter, no
/// archetype/bias system -- these are meant to be a simpler, more
/// interchangeable staff tier than the head coach, at least until a real
/// hiring flow exists to make them feel distinct).
List<TrainingCoach> generateTrainingCoaches(
  Random random, {
  int qualityCenter = 50,
  int qualitySpread = 15,
}) {
  return List.generate(3, (_) {
    final firstName = kFirstNames[random.nextInt(kFirstNames.length)];
    final lastName = kLastNames[random.nextInt(kLastNames.length)];
    final raw = qualityCenter + (random.nextDouble() * 2 - 1) * qualitySpread;
    return TrainingCoach(
      name: '$firstName $lastName',
      developmentRating: raw.round().clamp(kMinRating, kMaxRating),
    );
  });
}
