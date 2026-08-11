import '../domain/draft_pick.dart';
import 'draft_prospect_json.dart';

Map<String, dynamic> draftPickToJson(DraftPick pick) {
  return {
    'round': pick.round,
    'pickNumber': pick.pickNumber,
    'teamAbbreviation': pick.teamAbbreviation,
    'prospect': draftProspectToJson(pick.prospect),
  };
}

DraftPick draftPickFromJson(Map<String, dynamic> json) {
  return DraftPick(
    round: json['round'] as int,
    pickNumber: json['pickNumber'] as int,
    teamAbbreviation: json['teamAbbreviation'] as String,
    prospect: draftProspectFromJson(json['prospect'] as Map<String, dynamic>),
  );
}
