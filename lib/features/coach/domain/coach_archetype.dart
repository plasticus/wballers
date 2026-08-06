/// A coach's coaching style/identity (`0B_Planned.md`'s coach-archetype
/// item) -- much simpler than `Archetype` on the player side: no
/// position-validity constraint, just one flat list. `coach_generator.dart`
/// rolls this first and biases `CoachStats` to fit it, the same
/// archetype-then-bias shape `player_generator.dart` already uses.
enum CoachArchetype {
  offensiveInnovator,
  defensiveMastermind,
  playersCoach,
  talentDeveloper,
  programBuilder,
  oldSchoolDisciplinarian,
  fieryCompetitor,
  steadyHand,
}

extension CoachArchetypeLabel on CoachArchetype {
  String get label => switch (this) {
    CoachArchetype.offensiveInnovator => 'Offensive Innovator',
    CoachArchetype.defensiveMastermind => 'Defensive Mastermind',
    CoachArchetype.playersCoach => "Player's Coach",
    CoachArchetype.talentDeveloper => 'Talent Developer',
    CoachArchetype.programBuilder => 'Program Builder',
    CoachArchetype.oldSchoolDisciplinarian => 'Old-School Disciplinarian',
    CoachArchetype.fieryCompetitor => 'Fiery Competitor',
    CoachArchetype.steadyHand => 'Steady Hand',
  };
}
