import '../../coach/persistence/coach_json.dart';
import '../../roster/persistence/roster_membership_json.dart';
import '../domain/ai_team_roster.dart';
import 'team_json.dart';

Map<String, dynamic> aiTeamRosterToJson(AiTeamRoster aiTeamRoster) {
  return {
    'team': teamToJson(aiTeamRoster.team),
    'roster': aiTeamRoster.roster
        .map((membership) => rosterMembershipToJson(membership))
        .toList(),
    'coach': coachToJson(aiTeamRoster.coach),
    'coachHiredSeason': aiTeamRoster.coachHiredSeason,
  };
}

AiTeamRoster aiTeamRosterFromJson(Map<String, dynamic> json) {
  return AiTeamRoster(
    team: teamFromJson(json['team'] as Map<String, dynamic>),
    roster: (json['roster'] as List<dynamic>)
        .map((value) => rosterMembershipFromJson(value as Map<String, dynamic>))
        .toList(),
    // No legacy-save fallback -- pre-release schema churn gets a fresh
    // save, not defensive parsing (0C_Vision_and_Ideas.md).
    coach: coachFromJson(json['coach'] as Map<String, dynamic>),
    coachHiredSeason: json['coachHiredSeason'] as int,
  );
}
