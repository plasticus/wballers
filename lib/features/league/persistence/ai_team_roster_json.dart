import '../../roster/persistence/roster_membership_json.dart';
import '../domain/ai_team_roster.dart';
import 'team_json.dart';

Map<String, dynamic> aiTeamRosterToJson(AiTeamRoster aiTeamRoster) {
  return {
    'team': teamToJson(aiTeamRoster.team),
    'roster': aiTeamRoster.roster
        .map((membership) => rosterMembershipToJson(membership))
        .toList(),
  };
}

AiTeamRoster aiTeamRosterFromJson(Map<String, dynamic> json) {
  return AiTeamRoster(
    team: teamFromJson(json['team'] as Map<String, dynamic>),
    roster: (json['roster'] as List<dynamic>)
        .map((value) => rosterMembershipFromJson(value as Map<String, dynamic>))
        .toList(),
  );
}
