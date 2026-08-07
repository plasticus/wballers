import 'dart:math';

import '../../player/domain/player.dart';
import '../../player/generation/player_generator.dart';
import '../../player/generation/trait_generator.dart';

/// Seed offset for the free-agent pool -- keeps this stream from
/// correlating with any other (coach=0, roster=1, league draw=2, league
/// AI rosters=3, season schedule=4, game-day advancement=5, postseason=6,
/// training coaches=7, training advancement=8). Generated once at
/// franchise creation, same as [Franchise.roster] itself, then persisted
/// (`franchise_json.dart`) and only ever shrinks from there as the GM
/// signs players off it -- never regenerated.
const kFreeAgentPoolSeedOffset = 12;

/// How many free agents populate a new franchise's pool at creation -- a
/// real market to browse, not just the one signing the GM actually needs
/// to make.
const kFreeAgentPoolSize = 12;

/// Below-replacement-level quality center/spread for the pool's filler
/// players -- these are players nobody rostered, so a below-average
/// center is the point. Tuned (via a real sampling diagnostic, not a
/// guess) so a 12-player pool's realistic ceiling sits around 65 OVR --
/// "maximum OVR should probably be around 65," a direct GM ask -- without
/// hard-clamping to it.
const _fillerQualityCenter = 54;
const _fillerQualitySpread = 14;

/// Fillers also get their own potential capped, not left to
/// `generatePlayer`'s normal age-based roll -- that roll depends only on
/// age, not on quality center, so an ordinary young filler could
/// otherwise coincidentally roll a *higher* potential than the
/// deliberately-planted decent prospect below. Capped comfortably under
/// [kDecentFreeAgentPotential]'s floor so the decent prospect is always,
/// reliably the pool's actual standout -- the Day-0 Assistant GM mail
/// (`dashboard/dashboard_screen.dart`) finds them by scanning for the
/// highest potential in the pool, which only works if fillers can't
/// occasionally outroll them.
const _fillerPotentialCap = 66;
const _fillerPotentialCapSpread = 6;

/// The one deliberately-planted "decent" free agent every new pool gets --
/// a direct GM ask, paired with the Day-0 Assistant GM mail
/// (`dashboard/dashboard_screen.dart`) that nudges toward exactly this
/// kind of pickup: "try to find a high-potential player." High potential
/// is the *only* thing deliberately shaped about them -- current ability,
/// position, and age are all left to `generatePlayer`'s own defaults
/// ("everything else about them should be random"), unlike the starting
/// roster's other hand-placed narrative players, which shape quality
/// center and age too.
const kDecentFreeAgentPotential = 80;
const _decentFreeAgentPotentialSpread = 3;

/// Generates a new franchise's starting free-agent pool: [count] players,
/// one of them the deliberately-planted "decent" prospect (landing at a
/// random position within the pool, not always slot 0), the rest random
/// filler. Deterministic for a given [random] stream.
List<Player> generateFreeAgentPool(
  Random random, {
  int count = kFreeAgentPoolSize,
}) {
  final decentIndex = random.nextInt(count);
  return [
    for (var i = 0; i < count; i++)
      i == decentIndex
          ? _generateDecentFreeAgent(random)
          : _generateFillerFreeAgent(random),
  ];
}

Player _generateDecentFreeAgent(Random random) {
  final position = Position.values[random.nextInt(Position.values.length)];
  final player = generatePlayer(
    random,
    primaryPosition: position,
    potentialOverride: kDecentFreeAgentPotential,
    potentialOverrideSpread: _decentFreeAgentPotentialSpread,
  );
  final traits = generateTraits(random);
  return traits.isEmpty ? player : player.copyWithTraits(traits);
}

Player _generateFillerFreeAgent(Random random) {
  final position = Position.values[random.nextInt(Position.values.length)];
  final player = generatePlayer(
    random,
    primaryPosition: position,
    qualityCenter: _fillerQualityCenter,
    qualitySpread: _fillerQualitySpread,
    potentialOverride: _fillerPotentialCap,
    potentialOverrideSpread: _fillerPotentialCapSpread,
  );
  final traits = generateTraits(random);
  return traits.isEmpty ? player : player.copyWithTraits(traits);
}
