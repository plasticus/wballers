import '../../player/persistence/player_injury_json.dart';
import '../../player/persistence/player_json.dart';
import '../domain/roster_membership.dart';
import '../domain/roster_status.dart';

Map<String, dynamic> rosterMembershipToJson(RosterMembership membership) {
  return {
    'player': playerToJson(membership.player),
    'status': membership.status.name,
    if (membership.injury != null)
      'injury': playerInjuryToJson(membership.injury!),
    if (membership.recoveredWhileReserved) 'recoveredWhileReserved': true,
  };
}

RosterMembership rosterMembershipFromJson(Map<String, dynamic> json) {
  final injuryJson = json['injury'] as Map<String, dynamic>?;
  return RosterMembership(
    player: playerFromJson(json['player'] as Map<String, dynamic>),
    status: RosterStatus.values.byName(json['status'] as String),
    injury: injuryJson == null ? null : playerInjuryFromJson(injuryJson),
    recoveredWhileReserved: json['recoveredWhileReserved'] as bool? ?? false,
  );
}
