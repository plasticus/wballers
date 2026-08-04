import '../../player/domain/player.dart';
import 'roster_membership.dart';
import 'roster_status.dart';
import 'starting_lineup.dart';

/// The result of checking a proposed [StartingLineup] against a roster.
/// Exposes which specific rule failed (not just pass/fail) so the lineup
/// editor can show a concrete validation warning rather than a generic
/// "invalid" message.
class LineupLegality {
  const LineupLegality({
    required this.hasAllPositionsFilled,
    required this.hasNoDuplicatePlayers,
    required this.hasOnlyEligibleActivePlayers,
  });

  final bool hasAllPositionsFilled;
  final bool hasNoDuplicatePlayers;
  final bool hasOnlyEligibleActivePlayers;

  bool get isLegal =>
      hasAllPositionsFilled &&
      hasNoDuplicatePlayers &&
      hasOnlyEligibleActivePlayers;
}

LineupLegality evaluateLineupLegality(
  StartingLineup lineup,
  List<RosterMembership> roster,
) {
  final playersById = {
    for (final membership in roster) membership.player.id: membership,
  };

  final assignedIds = lineup.startersByPosition.values.toList();

  final hasAllPositionsFilled =
      lineup.startersByPosition.length == Position.values.length;
  final hasNoDuplicatePlayers =
      assignedIds.toSet().length == assignedIds.length;

  final hasOnlyEligibleActivePlayers = lineup.startersByPosition.entries.every((
    entry,
  ) {
    final membership = playersById[entry.value];
    if (membership == null || membership.status != RosterStatus.active) {
      return false;
    }
    return StartingLineup.isEligible(membership.player, entry.key);
  });

  return LineupLegality(
    hasAllPositionsFilled: hasAllPositionsFilled,
    hasNoDuplicatePlayers: hasNoDuplicatePlayers,
    hasOnlyEligibleActivePlayers: hasOnlyEligibleActivePlayers,
  );
}
