import '../../player/domain/college.dart';
import '../../player/persistence/player_json.dart';
import '../domain/draft_prospect.dart';

Map<String, dynamic> draftProspectToJson(DraftProspect prospect) {
  return {
    'player': playerToJson(prospect.player),
    // Just the abbreviation -- [kColleges] is the stable source of truth,
    // same convention `player_json.dart`'s own `Player.college` uses.
    'college': prospect.college.abbreviation,
  };
}

DraftProspect draftProspectFromJson(Map<String, dynamic> json) {
  return DraftProspect(
    player: playerFromJson(json['player'] as Map<String, dynamic>),
    college: kColleges.firstWhere(
      (college) => college.abbreviation == json['college'] as String,
    ),
  );
}
