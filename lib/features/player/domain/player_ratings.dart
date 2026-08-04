import 'dart:math';

import '../../../core/ratings/rating_scale.dart';

/// A player's basketball ratings on the shared 1-99 scale (`question.md`
/// decision 16), following the "Final Stat Architecture" in
/// `star_system.md`: four physical, four offensive, and four defensive
/// attributes, plus [potential] as a separate ceiling rating.
class PlayerRatings {
  const PlayerRatings({
    // Physical
    required this.speed,
    required this.agility,
    required this.strength,
    required this.stamina,
    // Offensive
    required this.ballControl,
    required this.passing,
    required this.insideScoring,
    required this.outsideScoring,
    // Defensive & playmaking
    required this.perimeterDefense,
    required this.interiorDefense,
    required this.disruption,
    required this.blocking,
    // Ceiling, not current ability
    required this.potential,
  }) : assert(speed >= kMinRating && speed <= kMaxRating),
       assert(agility >= kMinRating && agility <= kMaxRating),
       assert(strength >= kMinRating && strength <= kMaxRating),
       assert(stamina >= kMinRating && stamina <= kMaxRating),
       assert(ballControl >= kMinRating && ballControl <= kMaxRating),
       assert(passing >= kMinRating && passing <= kMaxRating),
       assert(insideScoring >= kMinRating && insideScoring <= kMaxRating),
       assert(outsideScoring >= kMinRating && outsideScoring <= kMaxRating),
       assert(perimeterDefense >= kMinRating && perimeterDefense <= kMaxRating),
       assert(interiorDefense >= kMinRating && interiorDefense <= kMaxRating),
       assert(disruption >= kMinRating && disruption <= kMaxRating),
       assert(blocking >= kMinRating && blocking <= kMaxRating),
       assert(potential >= kMinRating && potential <= kMaxRating);

  // Physical
  final int speed;
  final int agility;
  final int strength;
  final int stamina;

  // Offensive
  final int ballControl;
  final int passing;
  final int insideScoring;
  final int outsideScoring;

  // Defensive & playmaking
  final int perimeterDefense;
  final int interiorDefense;
  final int disruption;
  final int blocking;

  /// Ceiling, not current ability — how good this player could become, not
  /// how good they are right now. Excluded from [overall].
  final int potential;

  /// Derived, not stored — see `star_system.md`'s note on rebounding.
  /// Combines [strength] with whichever of [insideScoring] or
  /// [interiorDefense] is higher, so both scoring-oriented and
  /// defense-oriented bigs can dominate the glass. The source doc says
  /// "Strength with Inside Scoring or Defense" without specifying exactly
  /// how to combine them — this averages the two so the result stays on
  /// the same 1-99 scale as every stored rating. Flagged as an
  /// interpretation, not a confirmed formula.
  int get reboundingRating {
    final scoringOrDefense = max(insideScoring, interiorDefense);
    return ((strength + scoringOrDefense) / 2).round();
  }

  /// Unweighted average of the twelve stored current-ability ratings.
  /// [potential] is excluded (it's a ceiling, not current ability) and
  /// [reboundingRating] is excluded (it's derived from stats already in
  /// this average, so including it would double-count them). Position-aware
  /// weighting is future work once role fit exists.
  int get overall {
    final sum =
        speed +
        agility +
        strength +
        stamina +
        ballControl +
        passing +
        insideScoring +
        outsideScoring +
        perimeterDefense +
        interiorDefense +
        disruption +
        blocking;
    return (sum / 12).round();
  }
}
