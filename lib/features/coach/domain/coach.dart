import 'coach_stats.dart';

/// A franchise's head coach — a hired NPC staff member, not the player.
/// The player is the General Manager (see `Franchise.gmName`); the coach
/// is who the GM instructs for in-game quarter-break/timeout decisions and
/// who drives player development, per `CoachStats`. One per franchise for
/// now, generated at onboarding (`generateCoach`) rather than player-named
/// — hiring/firing a specific coach is future GM-decision work.
///
/// Portrait appearance isn't linked here yet: the portrait system (see
/// `portraits.md`) already models coaches as a distinct entity, but the
/// Flutter asset pipeline that would back a `portraitAppearance` field here
/// is Phase 1.5 work.
class Coach {
  const Coach({required this.name, required this.stats});

  final String name;
  final CoachStats stats;
}
