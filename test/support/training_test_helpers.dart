import 'package:womensbballmgr/features/training/domain/training_coach.dart';

/// 3 interchangeable, fixed-rating training coaches -- fixture data for
/// tests that need a valid `Franchise.trainingCoaches` but don't care
/// about the specific values, same spirit as `testSeasonProgress`.
List<TrainingCoach> testTrainingCoaches() => const [
  TrainingCoach(name: 'Test Coach A', developmentRating: 50),
  TrainingCoach(name: 'Test Coach B', developmentRating: 50),
  TrainingCoach(name: 'Test Coach C', developmentRating: 50),
];
