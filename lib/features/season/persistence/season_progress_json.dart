import '../domain/season_progress.dart';
import 'played_game_json.dart';
import 'season_schedule_json.dart';

Map<String, dynamic> seasonProgressToJson(SeasonProgress progress) {
  return {
    'schedule': seasonScheduleToJson(progress.schedule),
    'playedGames': progress.playedGames.map(playedGameToJson).toList(),
    'nextWeek': progress.nextWeek,
  };
}

SeasonProgress seasonProgressFromJson(Map<String, dynamic> json) {
  return SeasonProgress(
    schedule: seasonScheduleFromJson(json['schedule'] as Map<String, dynamic>),
    playedGames: (json['playedGames'] as List<dynamic>)
        .map((value) => playedGameFromJson(value as Map<String, dynamic>))
        .toList(),
    nextWeek: json['nextWeek'] as int,
  );
}
