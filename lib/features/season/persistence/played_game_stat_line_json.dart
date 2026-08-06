import '../domain/played_game_stat_line.dart';

Map<String, dynamic> playedGameStatLineToJson(PlayedGameStatLine line) {
  return {
    'minutesPlayed': line.minutesPlayed,
    'points': line.points,
    'fieldGoalsMade': line.fieldGoalsMade,
    'fieldGoalAttempts': line.fieldGoalAttempts,
    'threePointersMade': line.threePointersMade,
    'threePointAttempts': line.threePointAttempts,
    'freeThrowsMade': line.freeThrowsMade,
    'freeThrowAttempts': line.freeThrowAttempts,
    'offensiveRebounds': line.offensiveRebounds,
    'defensiveRebounds': line.defensiveRebounds,
    'assists': line.assists,
    'steals': line.steals,
    'blocks': line.blocks,
    'turnovers': line.turnovers,
    'personalFouls': line.personalFouls,
  };
}

PlayedGameStatLine playedGameStatLineFromJson(Map<String, dynamic> json) {
  return PlayedGameStatLine(
    minutesPlayed: (json['minutesPlayed'] as num).toDouble(),
    points: json['points'] as int,
    fieldGoalsMade: json['fieldGoalsMade'] as int,
    fieldGoalAttempts: json['fieldGoalAttempts'] as int,
    threePointersMade: json['threePointersMade'] as int,
    threePointAttempts: json['threePointAttempts'] as int,
    freeThrowsMade: json['freeThrowsMade'] as int,
    freeThrowAttempts: json['freeThrowAttempts'] as int,
    offensiveRebounds: json['offensiveRebounds'] as int,
    defensiveRebounds: json['defensiveRebounds'] as int,
    assists: json['assists'] as int,
    steals: json['steals'] as int,
    blocks: json['blocks'] as int,
    turnovers: json['turnovers'] as int,
    personalFouls: json['personalFouls'] as int,
  );
}
