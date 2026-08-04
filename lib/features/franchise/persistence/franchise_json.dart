import '../../coach/persistence/coach_json.dart';
import '../../league/persistence/team_json.dart';
import '../../roster/persistence/roster_membership_json.dart';
import '../domain/franchise.dart';

Map<String, dynamic> franchiseToJson(Franchise franchise) {
  return {
    'id': franchise.id,
    'gmName': franchise.gmName,
    'team': teamToJson(franchise.team),
    'coach': coachToJson(franchise.coach),
    'roster': franchise.roster
        .map((membership) => rosterMembershipToJson(membership))
        .toList(),
    'simulationSeed': franchise.simulationSeed,
  };
}

Franchise franchiseFromJson(Map<String, dynamic> json) {
  return Franchise(
    id: json['id'] as String,
    gmName: json['gmName'] as String,
    team: teamFromJson(json['team'] as Map<String, dynamic>),
    coach: coachFromJson(json['coach'] as Map<String, dynamic>),
    roster: (json['roster'] as List<dynamic>)
        .map((value) => rosterMembershipFromJson(value as Map<String, dynamic>))
        .toList(),
    simulationSeed: json['simulationSeed'] as int,
  );
}
