import '../domain/season_schedule.dart';
import 'scheduled_game_json.dart';

Map<String, dynamic> seasonScheduleToJson(SeasonSchedule schedule) {
  return {'games': schedule.games.map(scheduledGameToJson).toList()};
}

SeasonSchedule seasonScheduleFromJson(Map<String, dynamic> json) {
  return SeasonSchedule(
    games: (json['games'] as List<dynamic>)
        .map((value) => scheduledGameFromJson(value as Map<String, dynamic>))
        .toList(),
  );
}
