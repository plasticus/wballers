import '../../../core/ratings/rating_scale.dart';

/// A coach's stat block — deliberately much smaller than player ratings
/// (see `question.md` decision 15). Each stat is on the shared 1-99 rating
/// scale (decision 16) and feeds a specific later-phase system rather than
/// being a general-purpose rating:
///
/// - [offense] / [defense]: quality of in-game tactical calls (Phase 3
///   quarter-break/timeout choices).
/// - [development]: how much this coach accelerates player growth (Phase 2
///   player development).
/// - [motivation]: team morale/chemistry management (Phase 2) and
///   close-game resilience (Phase 3).
/// - [management]: trade and draft shrewdness (Phase 2).
class CoachStats {
  const CoachStats({
    required this.offense,
    required this.defense,
    required this.development,
    required this.motivation,
    required this.management,
  }) : assert(offense >= kMinRating && offense <= kMaxRating),
       assert(defense >= kMinRating && defense <= kMaxRating),
       assert(development >= kMinRating && development <= kMaxRating),
       assert(motivation >= kMinRating && motivation <= kMaxRating),
       assert(management >= kMinRating && management <= kMaxRating);

  /// All stats at the midpoint — a neutral starting point before onboarding
  /// offers any real choice of coaching archetype.
  static const neutral = CoachStats(
    offense: 50,
    defense: 50,
    development: 50,
    motivation: 50,
    management: 50,
  );

  final int offense;
  final int defense;
  final int development;
  final int motivation;
  final int management;

  /// Simple unweighted average of the five stats, rounded to the nearest
  /// int, for a single-number summary (e.g. a coach list or detail header).
  int get overall {
    return (skillTotal / 5).round();
  }

  /// The five stats summed, not averaged -- what `coach_lifecycle.dart`'s
  /// `coachSkillTotalForAge` targets at generation/growth time, same
  /// "currency" role `PlayerRatings.skillPoints` plays for players (two
  /// coaches can share the same rounded [overall] while genuinely
  /// differing in total skill).
  int get skillTotal =>
      offense + defense + development + motivation + management;
}
