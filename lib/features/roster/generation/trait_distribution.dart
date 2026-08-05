import 'dart:math';

import '../../player/generation/trait_generator.dart';
import '../domain/roster_membership.dart';

/// How many total traits a freshly generated roster gets, team-wide --
/// not per player. Reframed from the original per-player 0-3 roll, which
/// produced far too many traits across a 12-player roster (~18 on
/// average) to read as special. Most traits are meant to arrive later,
/// attached to incoming draft prospects (not built yet) or earned through
/// aging/development (not built yet either) -- a freshly generated roster
/// should only carry a handful.
const _minTeamTraits = 3;
const _maxTeamTraits = 5;

/// Chance that one of the players who already got a trait gets a second,
/// different one -- deliberately small. A player having two traits should
/// read as a rare, notable exception, not something that happens on a
/// meaningful fraction of rosters.
const _secondTraitChance = 0.05;

/// Distributes [_minTeamTraits]-[_maxTeamTraits] traits across [roster],
/// each to a different player except for the rare [_secondTraitChance]
/// case. Deterministic for a given [random] stream. Returns a new list --
/// [roster] itself isn't mutated.
List<RosterMembership> distributeTraits(
  Random random,
  List<RosterMembership> roster,
) {
  final totalTraits =
      _minTeamTraits + random.nextInt(_maxTeamTraits - _minTeamTraits + 1);
  final order = List<int>.generate(roster.length, (i) => i)..shuffle(random);

  final updated = List<RosterMembership>.of(roster);
  final traitedIndices = <int>[];

  for (final index in order) {
    if (traitedIndices.length >= totalTraits) break;
    final player = updated[index].player;
    final trait = pickEligibleTrait(random, player.traits);
    if (trait == null) continue;
    updated[index] = RosterMembership(
      player: player.copyWithTraits({...player.traits, trait}),
      status: updated[index].status,
    );
    traitedIndices.add(index);
  }

  if (traitedIndices.isNotEmpty && random.nextDouble() < _secondTraitChance) {
    final index = traitedIndices[random.nextInt(traitedIndices.length)];
    final player = updated[index].player;
    final trait = pickEligibleTrait(random, player.traits);
    if (trait != null) {
      updated[index] = RosterMembership(
        player: player.copyWithTraits({...player.traits, trait}),
        status: updated[index].status,
      );
    }
  }

  return updated;
}
