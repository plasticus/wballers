import 'player_rating_field.dart';

/// One player's outcome from a single training resolution -- which
/// fields moved and by how much, plus the resulting overall shift as a
/// quick headline number (`PlayerRatings.overall` is derived, not stored,
/// so this is a convenience snapshot, not a second source of truth).
/// [fieldDeltas] only ever contains fields that actually changed --
/// most players' most fields don't move in any given week.
class PlayerGrowthResult {
  const PlayerGrowthResult({
    required this.playerId,
    required this.fieldDeltas,
    required this.overallBefore,
    required this.overallAfter,
  });

  final String playerId;
  final Map<PlayerRatingField, int> fieldDeltas;
  final int overallBefore;
  final int overallAfter;

  int get overallDelta => overallAfter - overallBefore;
}

/// What one training cycle produced -- the training-screen equivalent of
/// `GameDayAdvance`/`PostseasonAdvance`: a record of what just happened,
/// meant to be shown once (the surfaced "training report" moment
/// `0B_Planned.md` calls for) rather than kept as a second source of
/// truth for player ratings, which live on the `Player` objects
/// themselves.
class TrainingReport {
  const TrainingReport({required this.week, required this.results});

  /// The schedule week this training cycle resolved for (see
  /// `lastFullyCompletedWeek`) -- not a literal calendar day, just which
  /// week's accumulated minutes this report is based on.
  final int week;

  /// Only players who actually changed -- someone with zero minutes that
  /// week and nothing else pushing them doesn't get an entry.
  final List<PlayerGrowthResult> results;
}
