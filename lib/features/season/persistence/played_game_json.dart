import '../domain/played_game.dart';
import 'played_game_stat_line_json.dart';
import 'scheduled_game_json.dart';

Map<String, dynamic> playedGameToJson(PlayedGame played) {
  return {
    'game': scheduledGameToJson(played.game),
    'homeScore': played.homeScore,
    'awayScore': played.awayScore,
    'minutesByPlayerId': played.minutesByPlayerId,
    'boxScoreByPlayerId': played.boxScoreByPlayerId.map(
      (playerId, line) => MapEntry(playerId, playedGameStatLineToJson(line)),
    ),
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
    boxScoreByPlayerId:
        (json['boxScoreByPlayerId'] as Map<String, dynamic>?)?.map(
          (playerId, line) => MapEntry(
            playerId,
            playedGameStatLineFromJson(line as Map<String, dynamic>),
          ),
        ) ??
        const {},
  );
}
