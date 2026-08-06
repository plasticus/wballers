import '../../portrait/domain/portrait_appearance.dart';
import 'coach_archetype.dart';
import 'coach_stats.dart';

/// A franchise's head coach — a hired NPC staff member, not the player.
/// The player is the General Manager (see `Franchise.gmName`); the coach
/// is who the GM instructs for in-game quarter-break/timeout decisions and
/// who drives player development, per `CoachStats`. One per franchise for
/// now, generated at onboarding (`generateCoach`) rather than player-named
/// — hiring/firing a specific coach is future GM-decision work.
class Coach {
  const Coach({
    required this.name,
    required this.stats,
    required this.archetype,
    this.appearance,
  });

  final String name;
  final CoachStats stats;

  /// This coach's coaching style (`coach_archetype.dart`) -- rolled first
  /// during generation, then [stats] are biased to fit it, same shape as
  /// a player's `Archetype`.
  final CoachArchetype archetype;

  /// Portrait source data (`portraits.md`), rendered with `isCoach: true`
  /// (coach-only layers like hats/glasses/facial hair, no jersey recolor).
  /// `null` falls back to a generic placeholder rather than an error state.
  final PortraitAppearance? appearance;

  /// Returns a copy with [newAppearance] replacing [appearance] -- the only
  /// field the portrait editor needs to change.
  Coach copyWithAppearance(PortraitAppearance newAppearance) {
    return Coach(
      name: name,
      stats: stats,
      archetype: archetype,
      appearance: newAppearance,
    );
  }
}
