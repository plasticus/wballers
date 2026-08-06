import '../domain/played_game.dart';
import 'scheduled_game_json.dart';

Map<String, dynamic> playedGameToJson(PlayedGame played) {
  return {
    'game': scheduledGameToJson(played.game),
    'homeScore': played.homeScore,
    'awayScore': played.awayScore,
  };
}

PlayedGame playedGameFromJson(Map<String, dynamic> json) {
  return PlayedGame(
    game: scheduledGameFromJson(json['game'] as Map<String, dynamic>),
    homeScore: json['homeScore'] as int,
    awayScore: json['awayScore'] as int,
  );
}
