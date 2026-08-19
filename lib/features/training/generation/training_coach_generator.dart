import 'dart:math';

import '../../player/generation/name_pools_by_country.dart';
import '../domain/training_coach.dart';

/// Seed offset for training-coach generation -- keeps this random stream
/// from correlating with any other (coach=0, roster=1, league draw=2,
/// league AI rosters=3, season schedule=4, game-day advancement=5,
/// postseason=6).
const kTrainingCoachSeedOffset = 7;

/// Generates a franchise's 3 training coaches -- same random-name-pool
/// pattern `generateCoach` uses for the head coach. Name only -- no
/// independent quality rating (`TrainingCoach`'s own doc comment on why
/// not), so this still consumes exactly 2 random draws per coach (first
/// name, last name) even though it once also rolled a development value.
List<TrainingCoach> generateTrainingCoaches(Random random) {
  return List.generate(3, (_) {
    final firstName = kAllGivenNames[random.nextInt(kAllGivenNames.length)];
    final lastName = kAllSurnames[random.nextInt(kAllSurnames.length)];
    return TrainingCoach(name: '$firstName $lastName');
  });
}
