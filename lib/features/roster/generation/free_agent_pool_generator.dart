import 'dart:math';

import '../../player/domain/country.dart';
import '../../player/domain/player.dart';
import '../../player/generation/player_generator.dart';
import '../../player/generation/trait_generator.dart';
import '../../portrait/domain/portrait_weights.dart';

/// Every non-domestic [Country] -- the pool [_generateDecentFreeAgent]
/// rolls from to guarantee the planted prospect reads as international.
final _kNonDomesticCountries = Country.values
    .where((country) => !country.isDomestic)
    .toList();

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
/// kind of pickup: "try to find a high-potential player." Current ability
/// used to be left at `generatePlayer`'s flat default center (50), until a
/// real problem surfaced (`Aug9bugs.md` #11): a player generated around 50
/// OVR is *below* every other player on a fresh 11-player starting roster,
/// so signing "the good free agent" the Assistant GM specifically pointed
/// to actively *lowered* the team's overall rating -- the opposite of the
/// "found a gem" signing it was supposed to read as.
///
/// Re-tuned again 2026-08-14 (a direct GM ask, alongside
/// `starting_roster_generator.dart`'s 4-narrative-slot revision): she
/// should read as "worth training for a season or two, then good depth,"
/// not a multi-year project -- [_decentFreeAgentQualityCenter] (70) and
/// [kDecentFreeAgentPotential] (82) hold a moderate, closeable gap instead
/// of the original wide-open one. Age, experience, and hometown are also
/// pinned (2026-08-09 originally, bumped to 24 on the same 2026-08-14
/// revision: "the age should be [24], an international rookie... give
/// them a little runway to grow"). Position is no longer left to
/// `generatePlayer`'s own random default either -- see
/// [generateFreeAgentPool]'s `plantedPosition` parameter: this player is
/// meant to complete the GM's starting five at a specific position, not
/// land wherever chance puts her.
const kDecentFreeAgentPotential = 82;
const _decentFreeAgentPotentialSpread = 3;
const _decentFreeAgentQualityCenter = 70;
const _decentFreeAgentQualitySpread = 5;

/// The planted decent free agent's pinned age -- see
/// [kDecentFreeAgentPotential]'s doc comment. 24 (bumped from 23 on the
/// 2026-08-14 revision) reads as "just arrived," old enough to already be
/// a real, evaluable prospect (not a total question mark) but young
/// enough that -- combined with [_kDecentFreeAgentYearsOfService] pinning
/// her as a rookie -- most of [kDecentFreeAgentPotential]'s (now moderate,
/// not wide-open) gap-to-potential growth is still ahead of her rather
/// than behind her.
const kDecentFreeAgentAge = 24;

/// Pinned to 0 (`generatePlayer`'s own "freshly drafted prospect" value,
/// same one `draft_generator.dart` uses) rather than left to the normal
/// debut-age roll, which could otherwise put a handful of "years of
/// service" behind a player who's supposed to read as a rookie taking her
/// very first pro contract.
const _kDecentFreeAgentYearsOfService = 0;

/// Generates a new franchise's starting free-agent pool: [count] players,
/// one of them the deliberately-planted "decent" prospect (landing at a
/// random position within the pool, not always slot 0), the rest random
/// filler. Deterministic for a given [random] stream.
///
/// [plantedPosition] is optional -- when given, the decent prospect
/// generates at exactly that position instead of a random one (a direct
/// GM ask, 2026-08-14: she should complete the GM's starting five at
/// whichever position `starting_roster_generator.dart`'s 4 narrative
/// slots left uncovered, not land wherever chance puts her -- see
/// `missingStartingPosition`). Omitted, she falls back to the original
/// fully-random position, same as every pre-existing caller (mostly
/// tests).
///
/// [portraitWeights] is optional and threads straight through to
/// [generatePlayer] -- omitted (e.g. in tests), every free agent's
/// [Player.appearance] stays `null`, same fallback [generatePlayer] itself
/// already documents. This was missing entirely until a GM playtest bug
/// report (2026-08-09, `Aug9bugs.md` #2: "free agents should have a
/// face") -- every other generated roster (`generateStartingRoster`,
/// `generateLeague`, `generateCoach`) already threaded it through from
/// `expansion_franchise_factory.dart`; free agents were the one pool that
/// didn't, so every free agent generated before this fix has `null`
/// appearance and renders as the portrait system's generic placeholder
/// instead of a real face.
List<Player> generateFreeAgentPool(
  Random random, {
  int count = kFreeAgentPoolSize,
  PortraitWeights? portraitWeights,
  Position? plantedPosition,
}) {
  final decentIndex = random.nextInt(count);
  return [
    for (var i = 0; i < count; i++)
      i == decentIndex
          ? _generateDecentFreeAgent(random, portraitWeights, plantedPosition)
          : _generateFillerFreeAgent(random, portraitWeights),
  ];
}

Player _generateDecentFreeAgent(
  Random random,
  PortraitWeights? portraitWeights,
  Position? plantedPosition,
) {
  final position =
      plantedPosition ??
      Position.values[random.nextInt(Position.values.length)];
  final country =
      _kNonDomesticCountries[random.nextInt(_kNonDomesticCountries.length)];
  final player = generatePlayer(
    random,
    primaryPosition: position,
    qualityCenter: _decentFreeAgentQualityCenter,
    qualitySpread: _decentFreeAgentQualitySpread,
    minAge: kDecentFreeAgentAge,
    maxAge: kDecentFreeAgentAge,
    yearsOfService: _kDecentFreeAgentYearsOfService,
    countryOverride: country,
    potentialOverride: kDecentFreeAgentPotential,
    potentialOverrideSpread: _decentFreeAgentPotentialSpread,
    portraitWeights: portraitWeights,
  );
  final traits = generateTraits(random, position: position);
  return traits.isEmpty ? player : player.copyWithTraits(traits);
}

Player _generateFillerFreeAgent(
  Random random,
  PortraitWeights? portraitWeights,
) {
  final position = Position.values[random.nextInt(Position.values.length)];
  final player = generatePlayer(
    random,
    primaryPosition: position,
    qualityCenter: _fillerQualityCenter,
    qualitySpread: _fillerQualitySpread,
    potentialOverride: _fillerPotentialCap,
    potentialOverrideSpread: _fillerPotentialCapSpread,
    portraitWeights: portraitWeights,
  );
  final traits = generateTraits(random, position: position);
  return traits.isEmpty ? player : player.copyWithTraits(traits);
}
