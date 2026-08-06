import '../domain/season_schedule.dart';
import 'scheduled_game_json.dart';

Map<String, dynamic> seasonScheduleToJson(SeasonSchedule schedule) {
  return {
    'games': schedule.games.map(scheduledGameToJson).toList(),
    'continentalCupRound1Byes': schedule.continentalCupRound1Byes,
  };
}

SeasonSchedule seasonScheduleFromJson(Map<String, dynamic> json) {
  return SeasonSchedule(
    games: (json['games'] as List<dynamic>)
        .map((value) => scheduledGameFromJson(value as Map<String, dynamic>))
        .toList(),
    continentalCupRound1Byes:
        (json['continentalCupRound1Byes'] as List<dynamic>?)
            ?.map((value) => value as String)
            .toList(),
  );
}
