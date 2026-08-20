import '../../player/domain/position.dart';
import '../../player/domain/retirement_reason.dart';
import '../domain/league_retirement.dart';

Map<String, dynamic> leagueRetirementToJson(LeagueRetirement retirement) {
  return {
    'playerId': retirement.playerId,
    'name': retirement.name,
    'primaryPosition': retirement.primaryPosition.name,
    'teamAbbreviation': retirement.teamAbbreviation,
    'reason': retirement.reason.name,
    'season': retirement.season,
  };
}

LeagueRetirement leagueRetirementFromJson(Map<String, dynamic> json) {
  return LeagueRetirement(
    playerId: json['playerId'] as String,
    name: json['name'] as String,
    primaryPosition: Position.values.byName(json['primaryPosition'] as String),
    teamAbbreviation: json['teamAbbreviation'] as String,
    reason: RetirementReason.values.byName(json['reason'] as String),
    season: json['season'] as int,
  );
}
