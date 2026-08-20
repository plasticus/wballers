import 'dart:math';

import '../../player/domain/player.dart';
import '../../player/generation/player_generator.dart';
import '../../portrait/domain/portrait_weights.dart';
import '../domain/roster_membership.dart';
import '../domain/roster_status.dart';
import 'jersey_number_assignment.dart';
import 'roster_position_plan.dart';
import 'trait_distribution.dart';

/// Target composition for a freshly generated AI team (`0B_Planned.md`):
/// exactly one 4-star player, leaning veteran, plus three high-quality
/// players with a young/mid/old age spread -- four 3-star-or-better total,
/// comfortably inside `star_system.md`'s caps (<=2 four-star, <=6
/// three-star-or-better combined). The other eight are role players,
/// centered well below the three-star threshold so the roster still reads
/// as a real team with a top-heavy shape, not 12 similar bodies.
/// Tight and close to the ceiling on purpose: `generatePlayer` now also
/// layers an archetype-specific bias on top of the position bias
/// (`_archetypeBias`, `player_generator.dart`), and clamping to the 1-99
/// scale isn't symmetric for a center this high -- a stat that would
/// exceed 99 just gets capped there (no headroom lost), but one pulled
/// down by a negative archetype delta has nothing to compensate,
/// dragging the 12-stat average down. 94/3 let real archetype+position
/// combinations occasionally land below the 90 four-star cutoff; 97/2
/// verified empirically (500-roster sample) to always clear it.
const _starQualityCenter = 97;
const _starQualitySpread = 2;
const _starMinAge = 29;
const _starMaxAge = 34;

const _quarterStarQualityCenter = 83;
const _quarterStarQualitySpread = 5;

/// (minAge, maxAge) for the three near-elite slots, in order: young,
/// mid-career, veteran -- "a mixed young/mid/old spread" rather than three
/// same-aged players. Named for the old 4-tier system (this was the
/// "quarter star" -- i.e. second-from-top -- tier); still second-from-top
/// under the current `StarTier` bands, just not guaranteed to land in any
/// one specific band the way [_starQualityCenter]'s tier is (see
/// `ai_roster_generator_test.dart`'s own comment on why).
const _quarterStarAgeRanges = <(int, int)>[(20, 24), (25, 29), (30, 34)];

const _roleQualityCenter = 65;
const _roleQualitySpread = 10;

/// A per-team quality shift applied to the quarter-star and role tiers
/// (11 of a team's 12 players) before generating them -- a direct GM ask
/// (2026-08-10, `Aug9bugs.md` #11): "I'd like to see a wider spread of
/// team quality on league creation," after a blowout loss made the
/// previous, effectively-flat spread obvious. Without this, every AI
/// team's *shape* (1 elite + 3 near-elite + 8 role players) was identical
/// and only individual-player jitter varied between teams -- which mostly
/// cancels out over a 12-player average (verified empirically: league-wide
/// team overall used to cluster in a ~72-76 band, barely 4 points wide).
/// Shifting most of a team's quality center together instead -- a
/// genuinely stronger or weaker supporting cast, not just better-or-worse
/// luck on individual rolls -- widens that spread to roughly 69-76 (also
/// verified empirically, 800-team sample) while leaving each team's
/// internal shape untouched.
///
/// Deliberately **excludes the star tier**: [_starQualityCenter]'s own doc
/// comment already explains why 97/2 is a tight, empirically-verified
/// minimum to *always* clear the 90 four-star cutoff -- an offset this
/// negative applied there too would eat that safety margin and start
/// producing AI teams with zero four-star players, breaking a real,
/// tested invariant (`ai_roster_generator_test.dart`'s "always includes
/// exactly one four-star player"). Every team keeps its guaranteed
/// franchise player; what varies is the strength of the 11 players around
/// her.
const _teamQualityOffsetMin = -7;
const _teamQualityOffsetMax = 2;

/// Generates one AI-controlled team's 12-player active roster. Deterministic
/// for a given [random] stream, same contract as `generateStartingRoster`
/// -- pass the same stream across multiple teams to generate a whole
/// league's rosters from one seed.
///
/// Positions are drawn from `kTwelvePlayerPositionPlan`, shuffled first so
/// which position ends up with the star/quality slots varies -- otherwise
/// every AI team's best player would always play the same position.
///
/// [starPositionLean] (2026-08-20, `league/domain/team_identity.dart`'s
/// `TeamIdentity`, a direct GM ask for lightweight team identities), when
/// given, forces the single star slot (`positions[0]`, always this
/// team's one 4-star franchise player) to land on that exact position --
/// swapped to the front of the already-shuffled list rather than
/// reshuffling around it, so every other slot's position assignment stays
/// exactly as random as before. `null` (the default, e.g. for tests that
/// don't care) leaves the shuffle's own natural pick in place.
List<RosterMembership> generateAiRoster(
  Random random, {
  PortraitWeights? portraitWeights,
  Position? starPositionLean,
}) {
  final positions = List<Position>.of(kTwelvePlayerPositionPlan)
    ..shuffle(random);
  if (starPositionLean != null) {
    final leanIndex = positions.indexOf(starPositionLean);
    if (leanIndex > 0) {
      positions[leanIndex] = positions[0];
      positions[0] = starPositionLean;
    }
  }
  final qualityOffset =
      _teamQualityOffsetMin +
      random.nextInt(_teamQualityOffsetMax - _teamQualityOffsetMin + 1);

  // Every surname already placed on this team so far -- threaded into
  // each [generatePlayer] call below so it rerolls away from a repeat
  // (2026-08-11, TODO.md: "no duplicate surnames allowed on a single
  // team").
  final usedSurnames = <String>{};

  RosterMembership build(
    Position position, {
    required int qualityCenter,
    required int qualitySpread,
    required int minAge,
    required int maxAge,
  }) {
    final player = generatePlayer(
      random,
      primaryPosition: position,
      qualityCenter: qualityCenter,
      qualitySpread: qualitySpread,
      minAge: minAge,
      maxAge: maxAge,
      portraitWeights: portraitWeights,
      excludeSurnames: usedSurnames,
    );
    usedSurnames.add(player.name.split(' ').skip(1).join(' '));
    return RosterMembership(player: player, status: RosterStatus.active);
  }

  final roster = <RosterMembership>[
    // Not offset -- see [_teamQualityOffsetMin]'s doc comment on why the
    // star tier stays fixed.
    build(
      positions[0],
      qualityCenter: _starQualityCenter,
      qualitySpread: _starQualitySpread,
      minAge: _starMinAge,
      maxAge: _starMaxAge,
    ),
  ];

  for (var i = 0; i < _quarterStarAgeRanges.length; i++) {
    final (minAge, maxAge) = _quarterStarAgeRanges[i];
    roster.add(
      build(
        positions[1 + i],
        qualityCenter: _quarterStarQualityCenter + qualityOffset,
        qualitySpread: _quarterStarQualitySpread,
        minAge: minAge,
        maxAge: maxAge,
      ),
    );
  }

  for (var i = 1 + _quarterStarAgeRanges.length; i < positions.length; i++) {
    roster.add(
      build(
        positions[i],
        qualityCenter: _roleQualityCenter + qualityOffset,
        qualitySpread: _roleQualitySpread,
        minAge: 20,
        maxAge: 34,
      ),
    );
  }

  return assignJerseyNumbers(random, distributeTraits(random, roster));
}
