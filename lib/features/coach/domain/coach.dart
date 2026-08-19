import '../../portrait/domain/portrait_appearance.dart';
import 'coach_archetype.dart';
import 'coach_stats.dart';

/// A franchise's head coach — a hired NPC staff member, not the player.
/// The player is the General Manager (see `Franchise.gmName`); the coach
/// is who the GM instructs for in-game quarter-break/timeout decisions and
/// who drives player development, per `CoachStats`. One per franchise,
/// generated at onboarding (`generateCoach`) and hirable again any
/// off-season thereafter (`current_franchise_provider.dart`'s
/// `hireHeadCoach`, `AvailableHeadCoachesScreen`) -- not player-named.
class Coach {
  const Coach({
    required this.name,
    required this.stats,
    required this.archetype,
    this.age = 50,
    this.appearance,
  });

  final String name;
  final CoachStats stats;

  /// This coach's coaching style (`coach_archetype.dart`) -- rolled first
  /// during generation, then [stats] are biased to fit it, same shape as
  /// a player's `Archetype`.
  final CoachArchetype archetype;

  /// Drives both [stats]' starting total (`coach_lifecycle.dart`'s
  /// `coachSkillTotalForAge`) and, every off-season,
  /// `coach_aging_advancer.dart`'s `growCoach`/mandatory-retirement check
  /// -- see that file's own doc comments for the full age/growth/
  /// retirement design. Defaults to 50 (the rough middle of a real
  /// coach's career) so the many test fixtures built before this field
  /// existed don't all need updating just to compile.
  final int age;

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
      age: age,
      appearance: newAppearance,
    );
  }

  /// Returns a copy with [newAge]/[newStats] replacing [age]/[stats] --
  /// `coach_aging_advancer.dart`'s `growCoach` is the only caller, one
  /// off-season's worth of aging and stat growth at a time.
  Coach copyWithGrowth({required int newAge, required CoachStats newStats}) {
    return Coach(
      name: name,
      stats: newStats,
      archetype: archetype,
      age: newAge,
      appearance: appearance,
    );
  }
}
