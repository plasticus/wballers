import '../../roster/domain/roster_legality.dart';
import '../../roster/domain/roster_status.dart';
import 'franchise.dart';

/// Splits [franchise]'s roster by [RosterStatus] and checks it against the
/// active-roster and developmental-roster rules. Reserve/Inactive members
/// are excluded entirely — they're unconstrained by design.
RosterLegality evaluateFranchiseLegality(Franchise franchise) {
  final active = franchise.roster
      .where((membership) => membership.status == RosterStatus.active)
      .map((membership) => membership.player)
      .toList();
  final developmental = franchise.roster
      .where((membership) => membership.status == RosterStatus.developmental)
      .map((membership) => membership.player)
      .toList();

  return evaluateRosterLegality(active: active, developmental: developmental);
}
