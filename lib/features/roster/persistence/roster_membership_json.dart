import '../../player/persistence/player_json.dart';
import '../domain/roster_membership.dart';
import '../domain/roster_status.dart';

Map<String, dynamic> rosterMembershipToJson(RosterMembership membership) {
  return {
    'player': playerToJson(membership.player),
    'status': membership.status.name,
  };
}

RosterMembership rosterMembershipFromJson(Map<String, dynamic> json) {
  return RosterMembership(
    player: playerFromJson(json['player'] as Map<String, dynamic>),
    status: RosterStatus.values.byName(json['status'] as String),
  );
}
