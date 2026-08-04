import '../../player/domain/player.dart';
import 'roster_status.dart';

/// A player's placement on a franchise's roster. Legality (star-tier caps,
/// developmental eligibility) is checked separately by
/// `evaluateRosterLegality` rather than enforced here — a franchise can
/// hold an illegal roster (e.g. right after a trade) and surface it as a
/// validation warning instead of throwing.
class RosterMembership {
  const RosterMembership({required this.player, required this.status});

  final Player player;
  final RosterStatus status;
}
