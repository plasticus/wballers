import '../../player/domain/retirement_reason.dart';
import '../domain/pending_retirement.dart';

Map<String, dynamic> pendingRetirementToJson(PendingRetirement pending) {
  return {'playerId': pending.playerId, 'reason': pending.reason.name};
}

PendingRetirement pendingRetirementFromJson(Map<String, dynamic> json) {
  return PendingRetirement(
    playerId: json['playerId'] as String,
    reason: RetirementReason.values.byName(json['reason'] as String),
  );
}
