import '../domain/player_rating_field.dart';
import '../domain/training_focus.dart';
import '../domain/training_plan.dart';

Map<String, dynamic> individualTrainingFocusToJson(
  IndividualTrainingFocus focus,
) {
  return {
    'broadFocus': focus.broadFocus?.name,
    'specificRating': focus.specificRating?.name,
  };
}

IndividualTrainingFocus individualTrainingFocusFromJson(
  Map<String, dynamic> json,
) {
  final specificRating = json['specificRating'] as String?;
  if (specificRating != null) {
    return IndividualTrainingFocus.specific(
      PlayerRatingField.values.byName(specificRating),
    );
  }
  return IndividualTrainingFocus.broad(
    TrainingFocus.values.byName(json['broadFocus'] as String),
  );
}

Map<String, dynamic> trainingCoachSlotToJson(TrainingCoachSlot slot) {
  return {
    'playerId': slot.playerId,
    'focus': slot.focus == null
        ? null
        : individualTrainingFocusToJson(slot.focus!),
  };
}

TrainingCoachSlot trainingCoachSlotFromJson(Map<String, dynamic> json) {
  final focusJson = json['focus'] as Map<String, dynamic>?;
  return TrainingCoachSlot(
    playerId: json['playerId'] as String?,
    focus: focusJson == null
        ? null
        : individualTrainingFocusFromJson(focusJson),
  );
}

Map<String, dynamic> trainingPlanToJson(TrainingPlan plan) {
  return {
    'teamFocus': plan.teamFocus.name,
    'coachSlots': plan.coachSlots.map(trainingCoachSlotToJson).toList(),
  };
}

TrainingPlan trainingPlanFromJson(Map<String, dynamic> json) {
  return TrainingPlan(
    teamFocus: TrainingFocus.values.byName(json['teamFocus'] as String),
    coachSlots: (json['coachSlots'] as List<dynamic>)
        .map(
          (value) => trainingCoachSlotFromJson(value as Map<String, dynamic>),
        )
        .toList(),
  );
}
