import '../../portrait/domain/portrait_appearance.dart';
import 'coach_stats.dart';

/// A franchise's head coach — a hired NPC staff member, not the player.
/// The player is the General Manager (see `Franchise.gmName`); the coach
/// is who the GM instructs for in-game quarter-break/timeout decisions and
/// who drives player development, per `CoachStats`. One per franchise for
/// now, generated at onboarding (`generateCoach`) rather than player-named
/// — hiring/firing a specific coach is future GM-decision work.
class Coach {
  const Coach({required this.name, required this.stats, this.appearance});

  final String name;
  final CoachStats stats;

  /// Portrait source data (`portraits.md`), rendered with `isCoach: true`
  /// (coach-only layers like hats/glasses/facial hair, no jersey recolor).
  /// `null` falls back to a generic placeholder rather than an error state.
  final PortraitAppearance? appearance;
}
