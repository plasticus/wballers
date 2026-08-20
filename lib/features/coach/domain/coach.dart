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
    this.seasonsAsHeadCoach = 0,
    this.careerWins = 0,
    this.careerLosses = 0,
    this.championshipsWon = 0,
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

  /// How many full seasons this specific [Coach] has been *this*
  /// franchise's head coach -- a direct GM ask (2026-08-19): "Head coach
  /// needs a detail screen... how long they've been a head coach."
  /// [copyWithSeasonRecord] is the only writer, bumped once per real
  /// season transition (`season_transition_advancer.dart`'s
  /// `beginNextSeason`); resets to 0 for free the moment a fresh [Coach]
  /// replaces this one (`current_franchise_provider.dart`'s
  /// `hireHeadCoach`) -- tenure is with a specific coach, not the role.
  /// Deliberately GM-own-coach-only, same asymmetry every other
  /// coach-facing system in this codebase already has -- no AI team's
  /// coach has a detail screen to show this on.
  final int seasonsAsHeadCoach;

  /// This [Coach]'s real regular-season wins/losses, summed across every
  /// season she's coached this franchise -- same "career," same
  /// GM-own-coach-only scope as [seasonsAsHeadCoach]. Bumped by
  /// [copyWithSeasonRecord] once per season transition, off that
  /// season's real final standings (`currentStandings`), not
  /// re-derivable after the fact once a new season's schedule replaces
  /// the old one -- has to be tracked incrementally, not recomputed.
  final int careerWins;
  final int careerLosses;

  /// How many championships this [Coach] has won while head coach of
  /// this franchise -- the "any trophies" a direct GM ask (2026-08-19)
  /// called for. Bumped by [copyWithSeasonRecord] alongside
  /// [careerWins]/[careerLosses], off that same season's real
  /// `seasonChampion` result.
  final int championshipsWon;

  /// Returns a copy with [newAppearance] replacing [appearance] -- the only
  /// field the portrait editor needs to change.
  Coach copyWithAppearance(PortraitAppearance newAppearance) {
    return Coach(
      name: name,
      stats: stats,
      archetype: archetype,
      age: age,
      appearance: newAppearance,
      seasonsAsHeadCoach: seasonsAsHeadCoach,
      careerWins: careerWins,
      careerLosses: careerLosses,
      championshipsWon: championshipsWon,
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
      seasonsAsHeadCoach: seasonsAsHeadCoach,
      careerWins: careerWins,
      careerLosses: careerLosses,
      championshipsWon: championshipsWon,
    );
  }

  /// Returns a copy reflecting one just-finished season's real result --
  /// [seasonsAsHeadCoach] increments by 1, [wins]/[losses] add onto
  /// [careerWins]/[careerLosses], and [championshipsWon] increments by 1
  /// too if [wonChampionship]. `season_transition_advancer.dart`'s
  /// `beginNextSeason` is the only caller, exactly once per real season
  /// transition -- see [seasonsAsHeadCoach]'s own doc comment for why
  /// this can't just be recomputed later instead.
  Coach copyWithSeasonRecord({
    required int wins,
    required int losses,
    required bool wonChampionship,
  }) {
    return Coach(
      name: name,
      stats: stats,
      archetype: archetype,
      age: age,
      appearance: appearance,
      seasonsAsHeadCoach: seasonsAsHeadCoach + 1,
      careerWins: careerWins + wins,
      careerLosses: careerLosses + losses,
      championshipsWon: championshipsWon + (wonChampionship ? 1 : 0),
    );
  }
}
