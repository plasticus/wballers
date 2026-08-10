/// One of a franchise's 3 individual-development staff -- distinct from
/// the single head `Coach` (`coach/domain/coach.dart`), who runs in-game
/// tactics and sets development speed for *everyone* via
/// `CoachStats.development`, individually-slotted players included. A
/// training coach's whole job is working with whichever player they're
/// assigned (`TrainingPlan`), pointing that player's training in a
/// different direction than the team plan if the GM wants -- purely a
/// *focus* choice, not a quality one.
///
/// Deliberately carries no rating of its own (2026-08-10, a direct GM
/// design call: "I hate the idea of those 3 being different from one
/// another. They should all simply be an extension of the head coach's
/// capabilities" -- an earlier version had each of the 3 independently
/// rolling its own 1-99 `developmentRating`, which `training_advancer.dart`
/// used instead of the head coach's own rating for an individually-slotted
/// player). One per franchise slot, generated at franchise creation
/// (`training_coach_generator.dart`) -- no hire/fire flow yet, same
/// "generated once, staffing decisions are future work" posture the
/// head `Coach` already has.
class TrainingCoach {
  const TrainingCoach({required this.name});

  final String name;
}
