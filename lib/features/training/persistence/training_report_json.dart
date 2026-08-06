import '../domain/player_rating_field.dart';
import '../domain/training_report.dart';

Map<String, dynamic> playerGrowthResultToJson(PlayerGrowthResult result) {
  return {
    'playerId': result.playerId,
    'fieldDeltas': {
      for (final entry in result.fieldDeltas.entries)
        entry.key.name: entry.value,
    },
    'overallBefore': result.overallBefore,
    'overallAfter': result.overallAfter,
  };
}

PlayerGrowthResult playerGrowthResultFromJson(Map<String, dynamic> json) {
  return PlayerGrowthResult(
    playerId: json['playerId'] as String,
    fieldDeltas: (json['fieldDeltas'] as Map<String, dynamic>).map(
      (key, value) =>
          MapEntry(PlayerRatingField.values.byName(key), value as int),
    ),
    overallBefore: json['overallBefore'] as int,
    overallAfter: json['overallAfter'] as int,
  );
}

Map<String, dynamic> trainingReportToJson(TrainingReport report) {
  return {
    'week': report.week,
    'results': report.results.map(playerGrowthResultToJson).toList(),
  };
}

TrainingReport trainingReportFromJson(Map<String, dynamic> json) {
  return TrainingReport(
    week: json['week'] as int,
    results: (json['results'] as List<dynamic>)
        .map(
          (value) => playerGrowthResultFromJson(value as Map<String, dynamic>),
        )
        .toList(),
  );
}
