import 'dart:math';

import '../../coach/domain/coach_archetype.dart';
import '../../matchup/domain/offense_shape.dart';
import '../../player/domain/position.dart';

/// A team's persistent flavor -- a real, stable characteristic of the
/// club itself, not something a league draw or a save's own randomness
/// ever varies (2026-08-20, a direct GM ask: "team identities... like
/// what type of coach/players they'll go after... I want it to slowly,
/// lightly, develop story/character/feel for the human GM. Like they see
/// they're about to play Cincinnati, and they're like, oh damn, I know
/// I'm playing against a huge front court and huge defense today").
///
/// Deliberately simple, not a deep system: [archetype] locks every coach
/// this team ever hires (initial + every future replacement,
/// `league_generator.dart`/`coach_free_agency_advancer.dart`/
/// `coach_aging_advancer.dart`), [positionLean] locks which position
/// becomes the team's single strongest generated player at league
/// creation (`ai_roster_generator.dart`'s star slot), and [preferredShape]
/// is what [substitution_policy.dart]'s `targetMinutesFor` tries to put on
/// the floor every game (2026-08-21, a direct GM report: "almost every
/// team I'm playing is doing Pace & Space... having a variety of teams
/// [is] a fun aspect of the game... I think that TeamIdentity looking for
/// a shape should also fall into a similar ratio -- 50% would try for the
/// standard shape, and 50% other stuff"). All 3 are real, mechanical
/// signals the GM can actually learn to recognize over a whole
/// playthrough, not just flavor text layered on top of pure randomness.
/// AI drafting/free-agency stays untouched, real best-player-available,
/// after the initial roster -- [positionLean] can fade over a very long
/// save as normal roster churn happens, same as real team identities do;
/// [preferredShape] instead re-asserts itself every single game (it's a
/// per-game lineup construction rule, not a one-time roster nudge), so it
/// doesn't fade the same way.
///
/// Deliberately AI-only -- the GM's own team has no locked identity of
/// its own, since the GM already has full, real control over who they
/// hire and who they sign; a "locked" identity would just be fiction with
/// no mechanical backing for the one team the GM actually plays.
class TeamIdentity {
  const TeamIdentity({
    required this.archetype,
    required this.positionLean,
    required this.preferredShape,
  });

  final CoachArchetype archetype;
  final Position positionLean;
  final OffenseShape preferredShape;

  /// The plain-facts scouting line -- no authored prose per team/combo
  /// (a direct GM call, 2026-08-20: "no prose, just the facts"). Shared by
  /// `MatchPreviewScreen`'s pre-game scouting note and `TeamDetailScreen`,
  /// so the two surfaces can never say something different.
  String get styleLabel =>
      'Coaching style: ${archetype.label}. Roster strength: '
      '${positionLean.label}-leaning. Preferred shape: '
      '${preferredShape.label}.';
}

/// A stable hash of [abbreviation]'s own characters -- deliberately *not*
/// [String.hashCode] (never guaranteed stable across Dart runs/platforms
/// by spec, and this has to reproduce identically forever, save or no
/// save) -- a plain, hand-rolled polynomial hash instead.
int _stableSeedFor(String abbreviation) {
  var seed = 0;
  for (final unit in abbreviation.codeUnits) {
    seed = seed * 31 + unit;
  }
  return seed;
}

/// [team]'s permanent [TeamIdentity] -- a pure function of its own
/// abbreviation, not stored anywhere and not re-rolled per league draw or
/// per save, so the *same* team (e.g. Cincinnati) always has the *same*
/// identity across every playthrough, the same way its name/colors/emoji
/// already do (`teams.md`'s own static catalog). Recomputed on demand
/// wherever it's needed, same "recompute, don't persist" posture this
/// codebase already uses for anything derivable from stable inputs.
TeamIdentity identityFor(String teamAbbreviation) {
  final random = Random(_stableSeedFor(teamAbbreviation));
  final archetype =
      CoachArchetype.values[random.nextInt(CoachArchetype.values.length)];
  final positionLean = Position.values[random.nextInt(Position.values.length)];
  return TeamIdentity(
    archetype: archetype,
    positionLean: positionLean,
    preferredShape: _preferredShapeFor(random),
  );
}

/// Half the league targets [OffenseShape.traditional] outright, a real
/// standard lineup every game; the other half is evenly split across the
/// 3 remaining shapes -- a direct GM call (2026-08-21): "I still think 50%
/// of teams should be a classic shape... 50% would try for the standard
/// shape, and 50% other stuff." Shares [random] (already seeded off the
/// team's own stable hash) rather than re-seeding, so this is still a
/// pure function of the team's abbreviation like every other
/// [TeamIdentity] field.
OffenseShape _preferredShapeFor(Random random) {
  if (random.nextDouble() < 0.5) return OffenseShape.traditional;
  const others = [
    OffenseShape.paceAndSpace,
    OffenseShape.postUp,
    OffenseShape.motion,
  ];
  return others[random.nextInt(others.length)];
}
