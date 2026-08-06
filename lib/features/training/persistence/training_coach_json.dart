import '../domain/training_coach.dart';

Map<String, dynamic> trainingCoachToJson(TrainingCoach coach) {
  return {'name': coach.name, 'developmentRating': coach.developmentRating};
}

TrainingCoach trainingCoachFromJson(Map<String, dynamic> json) {
  return TrainingCoach(
    name: json['name'] as String,
    developmentRating: json['developmentRating'] as int,
  );
}
