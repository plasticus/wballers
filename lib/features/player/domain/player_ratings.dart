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

  /// Returns a copy with any given fields replaced -- training
  /// (`features/training/`) is the only thing that ever nudges individual
  /// ratings after generation, one or two fields at a time, so a single
  /// generic `copyWith` covers it without a dozen single-field methods.
  PlayerRatings copyWith({
    int? speed,
    int? agility,
    int? strength,
    int? stamina,
    int? ballControl,
    int? passing,
    int? interiorOffense,
    int? perimeterOffense,
    int? perimeterDefense,
    int? interiorDefense,
    int? disruption,
    int? blocking,
    int? potential,
  }) {
    return PlayerRatings(
      speed: speed ?? this.speed,
      agility: agility ?? this.agility,
      strength: strength ?? this.strength,
      stamina: stamina ?? this.stamina,
      ballControl: ballControl ?? this.ballControl,
      passing: passing ?? this.passing,
      interiorOffense: interiorOffense ?? this.interiorOffense,
      perimeterOffense: perimeterOffense ?? this.perimeterOffense,
      perimeterDefense: perimeterDefense ?? this.perimeterDefense,
      interiorDefense: interiorDefense ?? this.interiorDefense,
      disruption: disruption ?? this.disruption,
      blocking: blocking ?? this.blocking,
      potential: potential ?? this.potential,
    );
  }

  /// The raw sum of the twelve stored current-ability ratings, before
  /// [overall] averages and rounds it down to one display number --
  /// exposed on its own (2026-08-19, the trading-system work) because
  /// [overall] alone can't tell two players apart who happen to round to
  /// the same displayed number: a 900 and a 905 both read as "75 OVR,"
  /// but they aren't equally good, and a trade that swaps one for the
  /// other isn't really the even deal it looks like. This is the
  /// finer-grained currency `trade_value.dart` actually trades in.
  int get skillPoints =>
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

  /// Unweighted average of the twelve stored current-ability ratings.
  /// [potential] is excluded — it's a ceiling, not current ability.
  /// Position-aware weighting is future work once role fit exists.
  int get overall => (skillPoints / 12).round();

  /// Unweighted average of the four physical ratings -- a roster-screen
  /// summary number, not consumed by simulation (which uses the individual
  /// ratings directly per the universal Physical + Skill/Defensive formula).
  int get physicalOverall =>
      ((speed + agility + strength + stamina) / 4).round();

  /// Unweighted average of the four offensive ratings.
  int get offenseOverall =>
      ((ballControl + passing + interiorOffense + perimeterOffense) / 4)
          .round();

  /// Unweighted average of the four defensive/playmaking ratings.
  int get defenseOverall =>
      ((perimeterDefense + interiorDefense + disruption + blocking) / 4)
          .round();
}
