import '../domain/scheduled_game.dart';

Map<String, dynamic> scheduledGameToJson(ScheduledGame game) {
  return {
    'week': game.week,
    'homeTeamAbbreviation': game.homeTeamAbbreviation,
    'awayTeamAbbreviation': game.awayTeamAbbreviation,
    'type': game.type.name,
    'continentalCupRound': game.continentalCupRound,
    'postseasonRound': game.postseasonRound,
  };
}

ScheduledGame scheduledGameFromJson(Map<String, dynamic> json) {
  return ScheduledGame(
    week: json['week'] as int,
    homeTeamAbbreviation: json['homeTeamAbbreviation'] as String,
    awayTeamAbbreviation: json['awayTeamAbbreviation'] as String,
    type: GameType.values.byName(json['type'] as String),
    continentalCupRound: json['continentalCupRound'] as int?,
    postseasonRound: json['postseasonRound'] as int?,
  );
}
