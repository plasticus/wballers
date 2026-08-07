import '../../coach/persistence/coach_json.dart';
import '../../league/persistence/league_json.dart';
import '../../league/persistence/team_json.dart';
import '../../roster/persistence/roster_membership_json.dart';
import '../../season/persistence/season_progress_json.dart';
import '../../training/persistence/training_coach_json.dart';
import '../../training/persistence/training_plan_json.dart';
import '../../training/persistence/training_report_json.dart';
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
    'replacedTeamAbbreviation': franchise.replacedTeamAbbreviation,
    'league': leagueToJson(franchise.league),
    'seasonProgress': seasonProgressToJson(franchise.seasonProgress),
    'trainingCoaches': franchise.trainingCoaches
        .map(trainingCoachToJson)
        .toList(),
    'trainingPlan': trainingPlanToJson(franchise.trainingPlan),
    'nextTrainingWeek': franchise.nextTrainingWeek,
    'trainingReports': franchise.trainingReports
        .map(trainingReportToJson)
        .toList(),
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
    replacedTeamAbbreviation: json['replacedTeamAbbreviation'] as String,
    league: leagueFromJson(json['league'] as Map<String, dynamic>),
    seasonProgress: seasonProgressFromJson(
      json['seasonProgress'] as Map<String, dynamic>,
    ),
    trainingCoaches: (json['trainingCoaches'] as List<dynamic>)
        .map((value) => trainingCoachFromJson(value as Map<String, dynamic>))
        .toList(),
    trainingPlan: trainingPlanFromJson(
      json['trainingPlan'] as Map<String, dynamic>,
    ),
    nextTrainingWeek: json['nextTrainingWeek'] as int,
    trainingReports: (json['trainingReports'] as List<dynamic>)
        .map((value) => trainingReportFromJson(value as Map<String, dynamic>))
        .toList(),
  );
}
