/// A broad training direction -- the team-wide default (`TrainingPlan.teamFocus`)
/// and one of the two ways a training coach can point an individual player
/// (`training_plan.dart`'s the other being a specific `PlayerRatingField`).
enum TrainingFocus { offense, defense, physical, balanced }

extension TrainingFocusLabel on TrainingFocus {
  /// Abbreviated (Off/Def/Phys/Bal) rather than the full word -- the
  /// Training screen's `SegmentedButton`s were wrapping "Balanced" onto
  /// a second line at normal text scale (2026-08-07, a direct GM report
  /// with a screenshot to show it).
  String get label {
    return switch (this) {
      TrainingFocus.offense => 'Off',
      TrainingFocus.defense => 'Def',
      TrainingFocus.physical => 'Phys',
      TrainingFocus.balanced => 'Bal',
    };
  }
}
