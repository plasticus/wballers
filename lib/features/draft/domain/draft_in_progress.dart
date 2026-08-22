import '../../trade/domain/pick_ownership.dart';
import 'draft_pick.dart';

/// One season's real draft, mid-resolution -- `0D_Season_2_Roadmap.md`'s
/// "The draft, for real" stage (2026-08-11): the single biggest missing
/// piece, per that doc's own framing -- `generateDraftOrder`/`simulateDraft`
/// already existed and worked, but nothing let a GM actually spend a pick
/// and land a player on their roster.
///
/// [order] is fixed for the whole draft (`generateDraftOrder`'s result --
/// worst-record-first via the lottery, then playoff teams reverse-seeded)
/// and repeats identically every round, same as real WNBA -- it always
/// names each *slot*'s natal team (the one that earned it by standings),
/// regardless of any trade. [picks] grows one at a time as each slot
/// resolves -- every non-GM team's pick resolves automatically
/// (`draft_advancer.dart`'s `resolvePicksUntilOwnTurn`, best player
/// available, same logic `simulateDraft` already established), the GM's
/// own pauses for a real decision (`makeOwnPick`).
///
/// [pickOwnershipOverrides] (2026-08-19, real draft-pick ownership) is a
/// frozen snapshot of `Franchise.pickOwnershipOverrides` taken the moment
/// this draft was set up (`season_transition_advancer.dart`'s
/// `beginNextSeason`) -- whatever the trade window moved around over the
/// season that just ended. [onTheClock] resolves each slot's natal team
/// through it, so a traded pick genuinely puts the *acquiring* team on
/// the clock, not just changes who gets credited in the value math.
class DraftInProgress {
  const DraftInProgress({
    required this.order,
    required this.rounds,
    this.picks = const [],
    this.pickOwnershipOverrides = const {},
    this.hasBeenOpened = false,
  });

  final List<String> order;
  final int rounds;
  final List<DraftPick> picks;
  final PickOwnershipOverrides pickOwnershipOverrides;

  /// True once the GM has actually opened `DraftDayScreen` for this draft
  /// at least once this season -- `false` for a freshly-created draft,
  /// even one whose own AI picks have already auto-resolved up to the
  /// GM's first turn (`beginNextSeason`'s own doc comment). Distinguishes
  /// the Dashboard's "Begin Season N Draft" wording (never opened yet)
  /// from "Resume Season N Draft" (backed out once already) -- a direct
  /// GM ask (2026-08-21): "I'm inevitably going to back out to look at my
  /// roster -- the draft should effectively pause until I come back and
  /// click Resume Season N Draft." [DraftInProgress.picks] alone can't
  /// stand in for this: the GM's own team rarely picks first, so picks
  /// already exist from auto-resolved AI turns before the GM ever sees
  /// the screen the first time.
  final bool hasBeenOpened;

  /// A copy with just [picks] (or, in principle, any other field) swapped
  /// in -- every other field defaults to carrying [this]'s own value
  /// forward untouched. `draft_advancer.dart`'s `_appendPick` is the one
  /// real caller, and specifically the reason this exists: reconstructing
  /// a fresh [DraftInProgress] by hand for every single pick previously
  /// silently dropped [pickOwnershipOverrides] (and would have dropped
  /// [hasBeenOpened] the same way) after the very first pick of any
  /// draft, since neither field was ever named in that manual
  /// reconstruction.
  DraftInProgress copyWith({List<DraftPick>? picks, bool? hasBeenOpened}) {
    return DraftInProgress(
      order: order,
      rounds: rounds,
      picks: picks ?? this.picks,
      pickOwnershipOverrides: pickOwnershipOverrides,
      hasBeenOpened: hasBeenOpened ?? this.hasBeenOpened,
    );
  }

  /// Every pick, across every round, has been made.
  bool get isComplete => picks.length >= order.length * rounds;

  /// Which team is actually up next -- the real current owner of that
  /// slot's pick, not necessarily the natal team that earned it by
  /// standings (see [pickOwnershipOverrides]) -- or `null` once
  /// [isComplete].
  String? get onTheClock {
    if (isComplete) return null;
    final natalTeam = order[picks.length % order.length];
    return currentPickOwner(pickOwnershipOverrides, nextRound, natalTeam);
  }

  /// The round the *next* pick belongs to, 1-based. Meaningless once
  /// [isComplete] (there is no next pick), but still computes a value
  /// rather than throwing -- callers that only care about [onTheClock]
  /// being `null` don't need to guard this too.
  int get nextRound => picks.length ~/ order.length + 1;

  /// The overall pick number (1-based, continuing across rounds) the
  /// *next* pick will be -- matches [DraftPick.pickNumber]'s own
  /// numbering.
  int get nextOverallPick => picks.length + 1;

  /// Every slot [teamAbbreviation] currently actually owns and hasn't
  /// been made yet -- their own natal slot in a round not yet reached,
  /// or one acquired via a trade ([pickOwnershipOverrides]), in round
  /// order (2026-08-22, a direct GM ask: "it should say all of my
  /// picks remaining, and their overall number"). [natalTeamAbbreviation]
  /// is [teamAbbreviation] itself for an untraded slot -- callers that
  /// want to name the trade partner only when there actually was one
  /// (`_DraftScheduleRow`'s "(from Cincinnati)" phrasing) compare the
  /// two rather than this getter deciding that for them.
  ///
  /// A slot already made (its overall pick number is `<= picks.length`)
  /// never appears here, regardless of who made it -- "remaining" means
  /// remaining across the *whole* draft, not just this team's own
  /// already-resolved turns.
  List<({int round, int overallPickNumber, String natalTeamAbbreviation})>
  remainingPicksFor(String teamAbbreviation) {
    return [
      for (var round = 1; round <= rounds; round++)
        for (var slot = 0; slot < order.length; slot++)
          if ((round - 1) * order.length + slot + 1 > picks.length &&
              currentPickOwner(pickOwnershipOverrides, round, order[slot]) ==
                  teamAbbreviation)
            (
              round: round,
              overallPickNumber: (round - 1) * order.length + slot + 1,
              natalTeamAbbreviation: order[slot],
            ),
    ];
  }
}
