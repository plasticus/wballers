import 'dart:math';

import '../../coach/domain/coach_archetype.dart';
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
/// `coach_aging_advancer.dart`), and [positionLean] locks which position
/// becomes the team's single strongest generated player at league
/// creation (`ai_roster_generator.dart`'s star slot) -- a real, mechanical
/// signal the GM can actually learn to recognize over a whole
/// playthrough, not just flavor text layered on top of pure randomness.
/// AI drafting/free-agency stays untouched, real best-player-available,
/// after that initial roster -- the lean can fade over a very long save
/// as normal roster churn happens, same as real team identities do.
///
/// Deliberately AI-only -- the GM's own team has no locked identity of
/// its own, since the GM already has full, real control over who they
/// hire and who they sign; a "locked" identity would just be fiction with
/// no mechanical backing for the one team the GM actually plays.
class TeamIdentity {
  const TeamIdentity({required this.archetype, required this.positionLean});

  final CoachArchetype archetype;
  final Position positionLean;

  /// The plain-facts scouting line -- no authored prose per team/combo
  /// (a direct GM call, 2026-08-20: "no prose, just the facts"). Shared by
  /// `MatchPreviewScreen`'s pre-game scouting note and `TeamDetailScreen`,
  /// so the two surfaces can never say something different.
  String get styleLabel =>
      'Coaching style: ${archetype.label}. Roster strength: '
      '${positionLean.label}-leaning.';
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
  return TeamIdentity(archetype: archetype, positionLean: positionLean);
}
