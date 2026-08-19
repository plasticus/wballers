import 'dart:math';

import '../domain/achievement.dart';

/// Candidate nicknames the game can suggest when a player earns
/// [Achievement]. Deliberately distinct wording from `Trait`/`Archetype`
/// labels so a nickname reads as its own kind of thing in the UI, not a
/// duplicate of a rating badge or play-style tag.
///
/// 25 candidates per achievement (2026-08-19, replacing the original
/// 4-per-achievement starter set with the GM's own `nicknames.md` drop) --
/// enough that [suggestNickname]'s no-repeat cycling (see its own doc
/// comment) can get a player through 25 wins of the *same* achievement
/// before it has to reuse one, a direct GM ask: "enough nicknames that a
/// player could play 25 seasons before seeing repeats."
const Map<Achievement, List<String>> kNicknamePools = {
  Achievement.leagueMvp: [
    'Golden',
    'Franchise',
    'Engine',
    'Uno',
    'The Architect',
    'The Closer',
    'The Maestro',
    'The Black Hole',
    'Blueprint',
    'Clockwork',
    'Vortex',
    'Overdrive',
    'Keystone',
    'Lights Out',
    'Apex',
    'Matrix',
    'Lockdown',
    'The Big Ticket',
    'Processor',
    'Lioness',
    'Mama Bear',
    'Ironclad',
    'Orbit',
    'Centurion',
    'Queenmaker',
  ],
  Achievement.scoringLeader: [
    'Buckets',
    'Flashfire',
    'Cash',
    'Bullseye',
    'Torch',
    'Aftershock',
    'Quickstrike',
    'Scoreboard',
    'Livewire',
    'Haymaker',
    'The Volume',
    'Point Machine',
    'Rainmaker',
    'Money',
    'The Machine',
    'Rain',
    'Airmail',
    'Silk',
    'Flamethrower',
    'Auto',
    'Heavy Artillery',
    'Green Light',
    'Range',
    'Avalanche',
    'Triple Threat',
  ],
  Achievement.defensiveMvp: [
    'Brickwall',
    'Flyswatter',
    'Pickpocket',
    'Blackout',
    'Radar',
    'Deadbolt',
    'No-Fly Zone',
    'Swarm',
    'Barricade',
    'Iron Gate',
    'The Silencer',
    'Spider',
    'Slim',
    'Warden',
    'Clamp',
    'The Vault',
    'Sentinel',
    'Steel Curtain',
    'Blanket',
    'Fortress',
    'Air Traffic',
    'Net Minder',
    'Lockdown Specialist',
    'Eraser',
    'Perimeter Cop',
  ],
  Achievement.sixthManOfTheYear: [
    'Sparkplug',
    'Instant O',
    'Wildcard',
    'Adrenaline',
    'Relief Valve',
    'Dynamo',
    'Ignition',
    'The Secret',
    'Booster',
    'The Changer',
    'Ace',
    'The Closer',
    'Sixth Sense',
    'The Spark',
    'Flash',
    'The Fixer',
    'Catalyst',
    'Turbo',
    'Nitrous',
    'Swiss Army',
    'Shockwave',
    'Fuse',
    'Reinforcement',
    'Second Gear',
    'The Antidote',
  ],
  Achievement.rookieOfTheYear: [
    'Phenom',
    'Vanguard',
    'Igniter',
    'Supernova',
    'Next Wave',
    'Trailblazer',
    'Sparkline',
    'Pacesetter',
    'Showstopper',
    'Hollywood',
    'Day One',
    'The Debut',
    'New Era',
    'Horizon',
    'Daybreak',
    'Genesis',
    'Frontier',
    'Sweet',
    'Prodigy',
    'Future Shock',
    'Epoch',
    'Fresh Cut',
    'First Light',
    'Starlet',
    'Upstart',
  ],
  Achievement.mostImprovedPlayer: [
    'Phoenix',
    'The Leap',
    'Renaissance',
    'Second Wind',
    'Breakout',
    'The Surge',
    'Levelup',
    'The Metamorphosis',
    'Comeback',
    'Ascendant',
    'Pearl',
    'The Shift',
    'Evolution',
    'Leap Year',
    'Rebirth',
    'Revamp',
    'Second Bloom',
    'Upgrade',
    'Resurgence',
    'Elevation',
    'Dark Horse',
    'Overhaul',
    'Transformed',
    'Breakthrough',
    'Next Level',
  ],
  Achievement.allStarMvp: [
    'Showtime',
    'The Headliner',
    'Marquee',
    'Brights',
    'Firework',
    'Centerstage',
    'Main Event',
    'The Reel',
    'The Mic',
    'North Star',
    'The Weekend',
    'Magic',
    'Hollywood',
    'Spotlight',
    'Big Stage',
    'Primetime',
    'Matinee',
    'Glitz',
    'High Roller',
    'Festival',
    'Encore',
    'The Attraction',
    'Headturner',
    'The Gala',
    'Sparkler',
  ],
};

/// Deterministic per-player, per-achievement draw order over the 25
/// candidates in [kNicknamePools] -- a `Random(seed)` shuffle, same
/// seeded-`Random` determinism convention every other generator in this
/// codebase already relies on, keyed off a stable hash of [playerId] and
/// [achievement] (see [_stableSeed]; not Dart's built-in
/// `String.hashCode`, which isn't guaranteed stable across platforms,
/// and would silently change a save's suggested nicknames the moment it
/// did).
List<int> _drawOrder(String playerId, Achievement achievement, int length) {
  final seed = _stableSeed(playerId, achievement);
  return List<int>.generate(length, (i) => i)..shuffle(Random(seed));
}

/// FNV-1a over [playerId]'s code units, folded with [achievement]'s
/// index -- cheap, stable across platforms, and gives every
/// (player, achievement) pair its own effectively-independent shuffle
/// order without needing any persisted state of its own.
int _stableSeed(String playerId, Achievement achievement) {
  var hash = 0x811c9dc5;
  for (final unit in playerId.codeUnits) {
    hash = (hash ^ unit) & 0xffffffff;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  hash = (hash ^ (achievement.index * 0x9e3779b9)) & 0xffffffff;
  return hash & 0x7fffffff;
}

/// Picks a nickname candidate for [playerId] earning [achievement] for
/// the ([occurrenceIndex] + 1)th time in her career (0 for the first
/// time, 1 for the second, ...) -- cycling through [kNicknamePools]'s 25
/// candidates in a fixed-but-shuffled-looking order that's the same
/// every time it's asked for this exact player/achievement pair, rather
/// than a plain independent random pick each time. A plain pick with
/// replacement could repeat within just a handful of wins (the birthday
/// paradox on a 25-item pool); cycling through a full shuffled order
/// instead guarantees no repeat until all 25 have come up once, only
/// then looping back to the start of the same order -- a direct GM ask,
/// 2026-08-19, after supplying a fresh 25-per-category pool: "enough
/// nicknames that a player could play 25 seasons before seeing repeats."
String suggestNickname(
  Achievement achievement, {
  required String playerId,
  required int occurrenceIndex,
}) {
  final pool = kNicknamePools[achievement]!;
  final order = _drawOrder(playerId, achievement, pool.length);
  return pool[order[occurrenceIndex % pool.length]];
}

/// The record and a suggested nickname for [playerId] earning
/// [achievement] in [season], as her ([occurrenceIndex] + 1)th time
/// winning this particular achievement -- see [suggestNickname]'s own
/// doc comment for what [occurrenceIndex] drives.
///
/// Doesn't decide whether to auto-apply the suggested nickname or hold it
/// for GM approval -- `FLUTTER_APP_PLAN.md` splits that by team (auto for
/// the 19 AI teams, GM's choice for their own), which is a season-end
/// ceremony policy Phase 2 owns, not something this generator can decide
/// without season/team context.
({PlayerAchievementRecord record, String suggestedNickname}) grantAchievement({
  required Achievement achievement,
  required int season,
  required String playerId,
  required int occurrenceIndex,
}) {
  return (
    record: PlayerAchievementRecord(achievement: achievement, season: season),
    suggestedNickname: suggestNickname(
      achievement,
      playerId: playerId,
      occurrenceIndex: occurrenceIndex,
    ),
  );
}
