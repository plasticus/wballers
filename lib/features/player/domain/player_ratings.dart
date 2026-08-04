import '../../../core/ratings/rating_scale.dart';

/// A player's basketball ratings, all on the shared 1-99 scale (`question.md`
/// decision 16). Shooting is two ratings, not three — [inside] and
/// [outside] — with no separate Finishing rating (decision 17).
class PlayerRatings {
  const PlayerRatings({
    required this.inside,
    required this.outside,
    required this.playmaking,
    required this.ballHandling,
    required this.defense,
    required this.rebounding,
    required this.athleticism,
    required this.stamina,
    required this.discipline,
    required this.potential,
  }) : assert(inside >= kMinRating && inside <= kMaxRating),
       assert(outside >= kMinRating && outside <= kMaxRating),
       assert(playmaking >= kMinRating && playmaking <= kMaxRating),
       assert(ballHandling >= kMinRating && ballHandling <= kMaxRating),
       assert(defense >= kMinRating && defense <= kMaxRating),
       assert(rebounding >= kMinRating && rebounding <= kMaxRating),
       assert(athleticism >= kMinRating && athleticism <= kMaxRating),
       assert(stamina >= kMinRating && stamina <= kMaxRating),
       assert(discipline >= kMinRating && discipline <= kMaxRating),
       assert(potential >= kMinRating && potential <= kMaxRating);

  /// Layups and other close-range shots at the rim.
  final int inside;

  /// One combined rating spanning mid-range through three-point shooting.
  final int outside;

  final int playmaking;
  final int ballHandling;
  final int defense;
  final int rebounding;
  final int athleticism;
  final int stamina;
  final int discipline;

  /// Ceiling, not current ability — how good this player could become, not
  /// how good they are right now. Deliberately excluded from [overall].
  final int potential;

  /// Unweighted average of the nine current-ability ratings — [potential]
  /// is a ceiling, not a current-ability stat, so it's excluded or it would
  /// inflate the rating of a raw-but-promising player. Position-aware
  /// weighting (a center's rebounding should count for more than a
  /// guard's) is future work once role fit exists.
  int get overall {
    final sum =
        inside +
        outside +
        playmaking +
        ballHandling +
        defense +
        rebounding +
        athleticism +
        stamina +
        discipline;
    return (sum / 9).round();
  }
}
