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
  const TrainingReport({
    int? fromWeek,
    required this.week,
    required this.results,
  }) : fromWeek = fromWeek ?? week;

  /// The schedule week this training cycle resolved for (see
  /// `lastFullyCompletedWeek`) -- not a literal calendar day, just which
  /// week's accumulated minutes this report is based on.
  final int week;

  /// The earliest week this report's minutes/growth actually cover --
  /// equal to [week] for an ordinary single-week cycle, but
  /// [runTraining] (`training_advancer.dart`) always sums minutes across
  /// `franchise.nextTrainingWeek..week`, which can span several real
  /// weeks at once (a bye week with no game to trigger training, or a
  /// multi-week off-season gap where nothing called [runTraining] until
  /// several weeks had piled up). [weekRangeLabel] is where this actually
  /// shows up. A real bug, live on-device (2026-08-19, a direct GM
  /// report): "simulated the off-season, and only for one training
  /// report (week24). I don't think that's right. Maybe give me an
  /// off-season training report that covers weeks 20 through 24" -- the
  /// growth math already *did* cover that whole gap (`_minutesInWeekRange`
  /// was never missing anything); only the report's own label was
  /// silently collapsing it down to the single ending week.
  final int fromWeek;

  /// "Week 24", or "Weeks 20-24" when [fromWeek] and [week] differ.
  String get weekRangeLabel =>
      fromWeek == week ? 'Week $week' : 'Weeks $fromWeek-$week';

  /// Only players who actually changed -- someone with zero minutes that
  /// week and nothing else pushing them doesn't get an entry.
  final List<PlayerGrowthResult> results;
}

/// Aggregates a season's worth of training history into one
/// [PlayerGrowthResult] per player who moved at all -- field deltas
/// summed across every entry in [weeklyReports] (chronological order,
/// same as [Franchise.trainingReports] itself), with [seasonEndAging]'s
/// one-time lump folded in on top as if it were simply the last entry.
/// `SeasonRecapScreen`'s player-development section (TODO.md item 2) is
/// the only consumer -- `TrainingReportScreen` shows one week's own
/// [TrainingReport.results] directly, with no aggregation needed there.
///
/// [PlayerGrowthResult.overallBefore] on a returned result is the
/// player's overall before *any* training this season (the first report
/// they appear in); [PlayerGrowthResult.overallAfter] is after the *last*
/// thing that touched them (the season-end lump if it did, otherwise
/// their most recent weekly report) -- so
/// [PlayerGrowthResult.overallDelta] reads as a genuine season-long
/// swing, not just whichever single entry happened to be summed last.
List<PlayerGrowthResult> aggregateSeasonGrowth({
  required List<TrainingReport> weeklyReports,
  required List<PlayerGrowthResult> seasonEndAging,
}) {
  final fieldDeltasByPlayer = <String, Map<PlayerRatingField, int>>{};
  final overallBeforeByPlayer = <String, int>{};
  final overallAfterByPlayer = <String, int>{};

  void fold(PlayerGrowthResult result) {
    final deltas = fieldDeltasByPlayer.putIfAbsent(result.playerId, () => {});
    for (final entry in result.fieldDeltas.entries) {
      deltas[entry.key] = (deltas[entry.key] ?? 0) + entry.value;
    }
    overallBeforeByPlayer.putIfAbsent(
      result.playerId,
      () => result.overallBefore,
    );
    overallAfterByPlayer[result.playerId] = result.overallAfter;
  }

  for (final report in weeklyReports) {
    for (final result in report.results) {
      fold(result);
    }
  }
  for (final result in seasonEndAging) {
    fold(result);
  }

  return [
    for (final playerId in fieldDeltasByPlayer.keys)
      PlayerGrowthResult(
        playerId: playerId,
        fieldDeltas: fieldDeltasByPlayer[playerId]!,
        overallBefore: overallBeforeByPlayer[playerId]!,
        overallAfter: overallAfterByPlayer[playerId]!,
      ),
  ];
}
