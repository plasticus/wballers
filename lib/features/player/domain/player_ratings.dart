import '../../../core/ratings/rating_scale.dart';

/// A player's basketball ratings on the shared 1-99 scale (`question.md`
/// decision 16), following the "Final Stat Architecture" in
/// `star_system.md`: four physical, four offensive, and four defensive
/// attributes, plus [potential] as a separate ceiling rating.
///
/// There's no stored or derived rebounding rating here. Rebounding isn't
/// special — it's the same universal Physical + Skill/Defensive formula
/// every other in-game action uses (offensive rebound: [strength] +
/// [interiorOffense]; defensive rebound: [strength] + [interiorDefense]).
/// That check happens at simulation time in Phase 3's engine, not here.
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
    required this.interiorOffense,
    required this.perimeterOffense,
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
       assert(interiorOffense >= kMinRating && interiorOffense <= kMaxRating),
       assert(perimeterOffense >= kMinRating && perimeterOffense <= kMaxRating),
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

  /// Layups, post moves, offensive rebounding instinct, boxing out —
  /// everything offensive that happens in the paint, not just finishing.
  final int interiorOffense;

  /// Jump shooting, shot fakes, and footwork from mid-range through the
  /// three-point line — everything offensive that happens on the perimeter,
  /// not just makes/misses.
  final int perimeterOffense;

  // Defensive & playmaking
  final int perimeterDefense;
  final int interiorDefense;
  final int disruption;
  final int blocking;

  /// Ceiling, not current ability — how good this player could become, not
  /// how good they are right now. Excluded from [overall].
  final int potential;

  /// Unweighted average of the twelve stored current-ability ratings.
  /// [potential] is excluded — it's a ceiling, not current ability.
  /// Position-aware weighting is future work once role fit exists.
  int get overall {
    final sum =
        speed +
        agility +
        strength +
        stamina +
        ballControl +
        passing +
        interiorOffense +
        perimeterOffense +
        perimeterDefense +
        interiorDefense +
        disruption +
        blocking;
    return (sum / 12).round();
  }
}
