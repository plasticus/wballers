import '../domain/training_coach.dart';

Map<String, dynamic> trainingCoachToJson(TrainingCoach coach) {
  return {'name': coach.name};
}

TrainingCoach trainingCoachFromJson(Map<String, dynamic> json) {
  return TrainingCoach(name: json['name'] as String);
}
