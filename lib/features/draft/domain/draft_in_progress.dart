import 'draft_pick.dart';

/// One season's real draft, mid-resolution -- `0D_Season_2_Roadmap.md`'s
/// "The draft, for real" stage (2026-08-11): the single biggest missing
/// piece, per that doc's own framing -- `generateDraftOrder`/`simulateDraft`
/// already existed and worked, but nothing let a GM actually spend a pick
/// and land a player on their roster.
///
/// [order] is fixed for the whole draft (`generateDraftOrder`'s result --
/// worst-record-first via the lottery, then playoff teams reverse-seeded)
/// and repeats identically every round, same as real WNBA. [picks] grows
/// one at a time as each slot resolves -- every non-GM team's pick
/// resolves automatically (`draft_advancer.dart`'s
/// `resolvePicksUntilOwnTurn`, best player available, same logic
/// `simulateDraft` already established), the GM's own pauses for a real
/// decision (`makeOwnPick`).
class DraftInProgress {
  const DraftInProgress({
    required this.order,
    required this.rounds,
    this.picks = const [],
  });

  final List<String> order;
  final int rounds;
  final List<DraftPick> picks;

  /// Every pick, across every round, has been made.
  bool get isComplete => picks.length >= order.length * rounds;

  /// Which team is up next, or `null` once [isComplete].
  String? get onTheClock =>
      isComplete ? null : order[picks.length % order.length];

  /// The round the *next* pick belongs to, 1-based. Meaningless once
  /// [isComplete] (there is no next pick), but still computes a value
  /// rather than throwing -- callers that only care about [onTheClock]
  /// being `null` don't need to guard this too.
  int get nextRound => picks.length ~/ order.length + 1;

  /// The overall pick number (1-based, continuing across rounds) the
  /// *next* pick will be -- matches [DraftPick.pickNumber]'s own
  /// numbering.
  int get nextOverallPick => picks.length + 1;
}
