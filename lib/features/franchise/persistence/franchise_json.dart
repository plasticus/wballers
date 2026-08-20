import '../../coach/persistence/coach_json.dart';
import '../../draft/persistence/draft_in_progress_json.dart';
import '../../draft/persistence/draft_prospect_json.dart';
import '../../league/persistence/league_json.dart';
import '../../league/persistence/team_json.dart';
import '../../player/persistence/player_json.dart';
import '../../portrait/persistence/portrait_appearance_json.dart';
import '../../roster/persistence/roster_membership_json.dart';
import '../../season/persistence/season_progress_json.dart';
import '../../season/persistence/skills_competition_json.dart';
import '../../training/persistence/training_coach_json.dart';
import '../../training/persistence/training_plan_json.dart';
import '../../training/persistence/training_report_json.dart';
import '../domain/franchise.dart';
import 'former_player_record_json.dart';
import 'league_retirement_json.dart';
import 'pending_retirement_json.dart';

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
    'season': franchise.season,
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
    'seasonEndAgingResults': franchise.seasonEndAgingResults
        .map(playerGrowthResultToJson)
        .toList(),
    'skillsCompetitionResults': franchise.skillsCompetitionResults
        .map(skillsCompetitionResultToJson)
        .toList(),
    'leagueRetirements': franchise.leagueRetirements
        .map(leagueRetirementToJson)
        .toList(),
    'freeAgents': franchise.freeAgents.map(playerToJson).toList(),
    'readMailIds': franchise.readMailIds.toList(),
    'pendingRetirements': franchise.pendingRetirements
        .map(pendingRetirementToJson)
        .toList(),
    'draftClass': franchise.draftClass.map(draftProspectToJson).toList(),
    // Null nearly always -- only non-null while a draft is actually
    // mid-resolution (`0D_Season_2_Roadmap.md`'s "The draft, for real").
    'draftInProgress': franchise.draftInProgress == null
        ? null
        : draftInProgressToJson(franchise.draftInProgress!),
    'seasonStartOverallByPlayerId': franchise.seasonStartOverallByPlayerId,
    'narrativeVeteranPlayerId': franchise.narrativeVeteranPlayerId,
    'narrativeVeteranName': franchise.narrativeVeteranName,
    'narrativeVeteranAppearance': franchise.narrativeVeteranAppearance == null
        ? null
        : portraitAppearanceToJson(franchise.narrativeVeteranAppearance!),
    'tradeBlockPlayerId': franchise.tradeBlockPlayerId,
    'resolvedTradeOfferIds': franchise.resolvedTradeOfferIds.toList(),
    'pickOwnershipOverrides': franchise.pickOwnershipOverrides.map(
      (draftSeason, byRound) => MapEntry(
        '$draftSeason',
        byRound.map((round, byTeam) => MapEntry('$round', byTeam)),
      ),
    ),
    'narrativeVeteranRetired': franchise.narrativeVeteranRetired,
    'formerPlayers': franchise.formerPlayers
        .map(formerPlayerRecordToJson)
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
    season: json['season'] as int,
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
    seasonEndAgingResults: (json['seasonEndAgingResults'] as List<dynamic>)
        .map(
          (value) => playerGrowthResultFromJson(value as Map<String, dynamic>),
        )
        .toList(),
    skillsCompetitionResults:
        (json['skillsCompetitionResults'] as List<dynamic>)
            .map(
              (value) => skillsCompetitionResultFromJson(
                value as Map<String, dynamic>,
              ),
            )
            .toList(),
    leagueRetirements: (json['leagueRetirements'] as List<dynamic>)
        .map(
          (value) => leagueRetirementFromJson(value as Map<String, dynamic>),
        )
        .toList(),
    freeAgents: (json['freeAgents'] as List<dynamic>)
        .map((value) => playerFromJson(value as Map<String, dynamic>))
        .toList(),
    readMailIds: (json['readMailIds'] as List<dynamic>)
        .map((value) => value as String)
        .toSet(),
    pendingRetirements: (json['pendingRetirements'] as List<dynamic>)
        .map(
          (value) => pendingRetirementFromJson(value as Map<String, dynamic>),
        )
        .toList(),
    draftClass: (json['draftClass'] as List<dynamic>)
        .map((value) => draftProspectFromJson(value as Map<String, dynamic>))
        .toList(),
    draftInProgress: json['draftInProgress'] == null
        ? null
        : draftInProgressFromJson(
            json['draftInProgress'] as Map<String, dynamic>,
          ),
    seasonStartOverallByPlayerId:
        (json['seasonStartOverallByPlayerId'] as Map<String, dynamic>).map(
          (key, value) => MapEntry(key, value as int),
        ),
    narrativeVeteranPlayerId: json['narrativeVeteranPlayerId'] as String,
    narrativeVeteranName: json['narrativeVeteranName'] as String,
    narrativeVeteranAppearance: json['narrativeVeteranAppearance'] == null
        ? null
        : portraitAppearanceFromJson(
            json['narrativeVeteranAppearance'] as Map<String, dynamic>,
          ),
    tradeBlockPlayerId: json['tradeBlockPlayerId'] as String?,
    resolvedTradeOfferIds: (json['resolvedTradeOfferIds'] as List<dynamic>)
        .map((value) => value as String)
        .toSet(),
    pickOwnershipOverrides:
        (json['pickOwnershipOverrides'] as Map<String, dynamic>).map(
          (draftSeason, byRound) => MapEntry(
            int.parse(draftSeason),
            (byRound as Map<String, dynamic>).map(
              (round, byTeam) => MapEntry(
                int.parse(round),
                (byTeam as Map<String, dynamic>).map(
                  (originalTeam, currentOwner) =>
                      MapEntry(originalTeam, currentOwner as String),
                ),
              ),
            ),
          ),
        ),
    narrativeVeteranRetired: json['narrativeVeteranRetired'] as bool,
    formerPlayers: (json['formerPlayers'] as List<dynamic>)
        .map(
          (value) => formerPlayerRecordFromJson(value as Map<String, dynamic>),
        )
        .toList(),
  );
}
