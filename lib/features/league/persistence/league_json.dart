import '../domain/league.dart';
import 'ai_team_roster_json.dart';

Map<String, dynamic> leagueToJson(League league) {
  return {
    'aiTeams': league.aiTeams
        .map((aiTeamRoster) => aiTeamRosterToJson(aiTeamRoster))
        .toList(),
  };
}

League leagueFromJson(Map<String, dynamic> json) {
  return League(
    aiTeams: (json['aiTeams'] as List<dynamic>)
        .map((value) => aiTeamRosterFromJson(value as Map<String, dynamic>))
        .toList(),
  );
}
