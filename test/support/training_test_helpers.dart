import 'package:womensbballmgr/features/training/domain/training_coach.dart';

/// 3 interchangeable training coaches -- fixture data for tests that need
/// a valid `Franchise.trainingCoaches` but don't care about the specific
/// values, same spirit as `testSeasonProgress`.
List<TrainingCoach> testTrainingCoaches() => const [
  TrainingCoach(name: 'Test Coach A'),
  TrainingCoach(name: 'Test Coach B'),
  TrainingCoach(name: 'Test Coach C'),
];
