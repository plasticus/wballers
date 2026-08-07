import 'dart:math';

import 'package:womensbballmgr/features/franchise/domain/franchise.dart';
import 'package:womensbballmgr/features/roster/domain/roster_membership.dart';
import 'package:womensbballmgr/features/roster/domain/roster_status.dart';
import 'package:womensbballmgr/features/roster/generation/jersey_number_assignment.dart';

/// Tops a franchise's active roster up to a full 12 by signing the first
/// player in [Franchise.freeAgents] -- `createExpansionFranchise` now
/// deliberately starts a franchise one player short (see
/// `starting_roster_generator.dart`'s doc comment), which the match
/// engine's own `homeRoster.length == 12` assert won't tolerate. Tests
/// that need to actually simulate a game for the GM's own team (most of
/// them) should run their franchise through this first; tests
/// specifically about the free-agent-signing gate itself should not.
/// No-op if there are no free agents to sign from.
Franchise withFullActiveRoster(Franchise franchise) {
  if (franchise.freeAgents.isEmpty) return franchise;
  final signee = assignJerseyNumberAvoiding(
    Random(0),
    franchise.freeAgents.first,
    franchise.roster,
  );
  return franchise.copyWithRosterAndFreeAgents(
    newRoster: [
      ...franchise.roster,
      RosterMembership(player: signee, status: RosterStatus.active),
    ],
    newFreeAgents: franchise.freeAgents.skip(1).toList(),
  );
}
