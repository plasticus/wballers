import '../domain/played_game.dart';
import 'scheduled_game_json.dart';

Map<String, dynamic> playedGameToJson(PlayedGame played) {
  return {
    'game': scheduledGameToJson(played.game),
    'homeScore': played.homeScore,
    'awayScore': played.awayScore,
    'minutesByPlayerId': played.minutesByPlayerId,
  };
}

PlayedGame playedGameFromJson(Map<String, dynamic> json) {
  return PlayedGame(
    game: scheduledGameFromJson(json['game'] as Map<String, dynamic>),
    homeScore: json['homeScore'] as int,
    awayScore: json['awayScore'] as int,
    minutesByPlayerId:
        (json['minutesByPlayerId'] as Map<String, dynamic>?)?.map(
          (key, value) => MapEntry(key, (value as num).toDouble()),
        ) ??
        const {},
  );
}
