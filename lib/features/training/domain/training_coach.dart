/// One of a franchise's 3 individual-development staff -- distinct from
/// the single head `Coach` (`coach/domain/coach.dart`), who runs in-game
/// tactics and sets the team-wide development baseline via
/// `CoachStats.development`. A training coach's whole job is working
/// with whichever player they're assigned (`TrainingPlan`), pointing
/// that player's training in a different direction than the team plan
/// if the GM wants.
///
/// One per franchise slot, generated at franchise creation
/// (`training_coach_generator.dart`) -- no hire/fire flow yet, same
/// "generated once, staffing decisions are future work" posture the
/// head `Coach` already has.
class TrainingCoach {
  const TrainingCoach({required this.name, required this.developmentRating});

  final String name;

  /// 1-99, same scale as everything else (`rating_scale.dart`) -- how
  /// much this coach accelerates whichever player they're assigned to,
  /// the individual-coach equivalent of `CoachStats.development`.
  final int developmentRating;
}
