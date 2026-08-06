import '../../player/domain/player_ratings.dart';

/// One of [PlayerRatings]' 12 trainable current-ability fields --
/// deliberately excludes [PlayerRatings.potential], which is a ceiling
/// training grows a player *toward*, not a field training grows
/// directly. What a training coach's "specific rating" focus
/// (`training_plan.dart`) picks from, and what the growth engine
/// (`training_advancer.dart`) reads/writes generically instead of
/// needing a switch at every call site.
enum PlayerRatingField {
  speed,
  agility,
  strength,
  stamina,
  ballControl,
  passing,
  interiorOffense,
  perimeterOffense,
  perimeterDefense,
  interiorDefense,
  disruption,
  blocking,
}

/// The 4 fields [TrainingFocus.offense] covers.
const kOffenseFields = {
  PlayerRatingField.ballControl,
  PlayerRatingField.passing,
  PlayerRatingField.interiorOffense,
  PlayerRatingField.perimeterOffense,
};

/// The 4 fields [TrainingFocus.defense] covers.
const kDefenseFields = {
  PlayerRatingField.perimeterDefense,
  PlayerRatingField.interiorDefense,
  PlayerRatingField.disruption,
  PlayerRatingField.blocking,
};

/// The 4 fields [TrainingFocus.physical] covers.
const kPhysicalFields = {
  PlayerRatingField.speed,
  PlayerRatingField.agility,
  PlayerRatingField.strength,
  PlayerRatingField.stamina,
};

extension PlayerRatingFieldLabel on PlayerRatingField {
  String get label {
    return switch (this) {
      PlayerRatingField.speed => 'Speed',
      PlayerRatingField.agility => 'Agility',
      PlayerRatingField.strength => 'Strength',
      PlayerRatingField.stamina => 'Stamina',
      PlayerRatingField.ballControl => 'Ball Control',
      PlayerRatingField.passing => 'Passing',
      PlayerRatingField.interiorOffense => 'Interior Offense',
      PlayerRatingField.perimeterOffense => 'Perimeter Offense',
      PlayerRatingField.perimeterDefense => 'Perimeter Defense',
      PlayerRatingField.interiorDefense => 'Interior Defense',
      PlayerRatingField.disruption => 'Disruption',
      PlayerRatingField.blocking => 'Blocking',
    };
  }
}

extension PlayerRatingFieldAccess on PlayerRatings {
  /// Reads whichever field [field] names -- the generic counterpart to
  /// writing one field at a time via [copyWithField].
  int valueOf(PlayerRatingField field) {
    return switch (field) {
      PlayerRatingField.speed => speed,
      PlayerRatingField.agility => agility,
      PlayerRatingField.strength => strength,
      PlayerRatingField.stamina => stamina,
      PlayerRatingField.ballControl => ballControl,
      PlayerRatingField.passing => passing,
      PlayerRatingField.interiorOffense => interiorOffense,
      PlayerRatingField.perimeterOffense => perimeterOffense,
      PlayerRatingField.perimeterDefense => perimeterDefense,
      PlayerRatingField.interiorDefense => interiorDefense,
      PlayerRatingField.disruption => disruption,
      PlayerRatingField.blocking => blocking,
    };
  }

  /// Returns a copy with [field] set to [value] -- the generic
  /// counterpart to [valueOf], so the growth engine can apply one
  /// player's per-field deltas in a loop rather than a hand-written
  /// switch per call site.
  PlayerRatings copyWithField(PlayerRatingField field, int value) {
    return switch (field) {
      PlayerRatingField.speed => copyWith(speed: value),
      PlayerRatingField.agility => copyWith(agility: value),
      PlayerRatingField.strength => copyWith(strength: value),
      PlayerRatingField.stamina => copyWith(stamina: value),
      PlayerRatingField.ballControl => copyWith(ballControl: value),
      PlayerRatingField.passing => copyWith(passing: value),
      PlayerRatingField.interiorOffense => copyWith(interiorOffense: value),
      PlayerRatingField.perimeterOffense => copyWith(perimeterOffense: value),
      PlayerRatingField.perimeterDefense => copyWith(perimeterDefense: value),
      PlayerRatingField.interiorDefense => copyWith(interiorDefense: value),
      PlayerRatingField.disruption => copyWith(disruption: value),
      PlayerRatingField.blocking => copyWith(blocking: value),
    };
  }
}
