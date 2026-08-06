import 'player_rating_field.dart';
import 'training_focus.dart';

/// What one training coach is telling their assigned player to work on --
/// either a broad category (the same shape as the team-wide goal) or one
/// specific rating to hyper-focus, never both. Mirrors [ScheduledGame]'s
/// "exactly one of these two is set" shape (`continentalCupRound`/
/// `postseasonRound`), just as a small value type instead of nullable
/// fields directly on a bigger class.
class IndividualTrainingFocus {
  const IndividualTrainingFocus.broad(TrainingFocus focus)
    : broadFocus = focus,
      specificRating = null;

  const IndividualTrainingFocus.specific(PlayerRatingField rating)
    : broadFocus = null,
      specificRating = rating;

  final TrainingFocus? broadFocus;
  final PlayerRatingField? specificRating;

  bool get isSpecific => specificRating != null;
}

/// One of a franchise's 3 training-coach slots: which coach (by index
/// into `Franchise.trainingCoaches`, implicit in list position -- see
/// `TrainingPlan.coachSlots`), which player they're assigned to (`null`
/// means idle -- the GM hasn't given this coach an assignment), and what
/// that player should work on. [playerId]/[focus] are both `null`
/// together or both set together; never one without the other.
class TrainingCoachSlot {
  const TrainingCoachSlot({this.playerId, this.focus})
    : assert(
        (playerId == null) == (focus == null),
        'playerId and focus must be both set or both null',
      );

  final String? playerId;
  final IndividualTrainingFocus? focus;

  bool get isAssigned => playerId != null;
}

/// The GM's current training instructions -- reused week to week until
/// changed (`0B_Planned.md`'s "settings are sticky" call), not re-entered
/// every training cycle. [teamFocus] is the default every player without
/// an individual coach assignment trains toward; [coachSlots] is always
/// exactly 3 entries, one per `Franchise.trainingCoaches` slot, in the
/// same order.
class TrainingPlan {
  TrainingPlan({required this.teamFocus, required this.coachSlots})
    : assert(coachSlots.length == 3, 'always exactly 3 training coach slots');

  /// A GM's default starting plan: balanced team focus, every coach idle
  /// -- assigned at franchise creation, same "sensible default,
  /// GM-overridable" pattern as the starting lineup.
  static TrainingPlan initial() => TrainingPlan(
    teamFocus: TrainingFocus.balanced,
    coachSlots: const [
      TrainingCoachSlot(),
      TrainingCoachSlot(),
      TrainingCoachSlot(),
    ],
  );

  final TrainingFocus teamFocus;
  final List<TrainingCoachSlot> coachSlots;

  /// Returns a copy with [newTeamFocus] replacing [teamFocus].
  TrainingPlan copyWithTeamFocus(TrainingFocus newTeamFocus) {
    return TrainingPlan(teamFocus: newTeamFocus, coachSlots: coachSlots);
  }

  /// Returns a copy with the slot at [coachIndex] replaced by [newSlot].
  TrainingPlan copyWithCoachSlot(int coachIndex, TrainingCoachSlot newSlot) {
    return TrainingPlan(
      teamFocus: teamFocus,
      coachSlots: [
        for (var i = 0; i < coachSlots.length; i++)
          if (i == coachIndex) newSlot else coachSlots[i],
      ],
    );
  }
}
