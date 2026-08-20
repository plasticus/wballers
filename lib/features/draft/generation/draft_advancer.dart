import 'dart:math';

import '../../franchise/domain/franchise.dart';
import '../../league/domain/ai_team_roster.dart';
import '../../league/domain/league.dart';
import '../../league/domain/team_identity.dart';
import '../../player/domain/draft_record.dart';
import '../../player/domain/player.dart';
import '../../roster/domain/roster_membership.dart';
import '../../roster/domain/roster_status.dart';
import '../../roster/generation/jersey_number_assignment.dart';
import '../domain/draft_in_progress.dart';
import '../domain/draft_pick.dart';
import '../domain/draft_prospect.dart';
import 'draft_generator.dart';
import 'hidden_gem.dart';

/// How close a prospect's own [draftProspectValue] has to be to the best
/// available prospect's before an AI team's [TeamIdentity.positionLean]
/// breaks the tie -- a direct GM call (2026-08-20), narrower than "always
/// draft our lean position": "I DON'T want a team drafting a PG first
/// every draft... they'd always have at least one or 2 good ones on the
/// roster, and if they have a star player, they want it to be a PG."
/// Best-player-available always wins outright once the gap exceeds this;
/// only a genuine near-tie ever gets nudged.
const kPositionLeanTiebreakTolerance = 4;

/// Seed offset for [finalizeDraft]'s jersey-number assignment -- once per
/// season, right after a real draft completes. Next free number after
/// `draft_generator.dart`'s [kRealDraftOrderSeedOffset] (20).
const kDraftFinalizeSeedOffset = 21;

List<DraftProspect> _availableProspects(
  List<DraftProspect> draftClass,
  List<DraftPick> picks,
) {
  final pickedIds = {for (final pick in picks) pick.prospect.player.id};
  return draftClass
      .where((prospect) => !pickedIds.contains(prospect.player.id))
      .toList();
}

/// Appends a pick for [draft.onTheClock] taking [selected] -- applies
/// [managementByAbbreviation]'s Hidden Gems bonus (`hidden_gem.dart`) for
/// that team's own coach first, so what actually lands on the roster
/// (via [DraftPick.prospect]) already reflects it, not just what's shown
/// on a pick announcement. `null`/a missing entry in
/// [managementByAbbreviation] reads as no bonus at all (the neutral,
/// no-Management-data-available default every other coach-driven system
/// in this codebase already uses).
DraftInProgress _appendPick(
  DraftInProgress draft,
  DraftProspect selected,
  Map<String, int> managementByAbbreviation,
) {
  final management = managementByAbbreviation[draft.onTheClock] ?? 0;
  final bonus = hiddenGemBonus(round: draft.nextRound, management: management);
  final boosted = bonus <= 0
      ? selected
      : DraftProspect(
          player: applyHiddenGemBonus(selected.player, bonus),
          college: selected.college,
        );
  return DraftInProgress(
    order: draft.order,
    rounds: draft.rounds,
    picks: [
      ...draft.picks,
      DraftPick(
        round: draft.nextRound,
        pickNumber: draft.nextOverallPick,
        teamAbbreviation: draft.onTheClock!,
        prospect: boosted,
      ),
    ],
  );
}

/// Resolves [draft] one pick at a time -- "best player available," the
/// exact same ranking [draftProspectValue] gives `simulateDraft`'s
/// whole-draft preview -- for every team *except* [ownTeamAbbreviation],
/// stopping the instant that team is [DraftInProgress.onTheClock] (or the
/// draft is [DraftInProgress.isComplete]). No `Random` needed -- same as
/// `simulateDraft`, "best player available" is a pure function of the
/// remaining pool, nothing here rolls anything (Hidden Gems' own
/// distribution is deterministic too -- see `hidden_gem.dart`).
///
/// [managementByAbbreviation] (2026-08-19, `hidden_gem.dart`) is each AI
/// team's own head coach's `CoachStats.management` -- omitted entries
/// (or the whole map omitted) read as no Hidden Gems bonus for that
/// team, same neutral-default posture every other coach-driven system
/// already has.
///
/// Models draft day as "every AI pick between the GM's turns resolves
/// instantly," rather than a fully turn-by-turn animated board -- with
/// [DraftInProgress.order] fixed and 20 teams, the GM's own team is only
/// ever on the clock a handful of times per round, so this keeps the real
/// decision points (the GM's own picks) while skipping the ceremony for
/// picks nobody's actually making a choice on.
DraftInProgress resolveAiPicksUntilOwnTurn({
  required DraftInProgress draft,
  required List<DraftProspect> draftClass,
  required String ownTeamAbbreviation,
  Map<String, int> managementByAbbreviation = const {},
}) {
  var current = draft;
  while (!current.isComplete && current.onTheClock != ownTeamAbbreviation) {
    final available = _availableProspects(draftClass, current.picks);
    assert(available.isNotEmpty, 'no prospects left for an AI team to draft');
    final best = available.reduce(
      (a, b) => draftProspectValue(a) >= draftProspectValue(b) ? a : b,
    );
    final selected = _preferLeanPositionOnNearTie(
      available,
      best,
      identityFor(current.onTheClock!).positionLean,
    );
    current = _appendPick(current, selected, managementByAbbreviation);
  }
  return current;
}

/// [best] unless a genuinely near-tied prospect at [positionLean] exists
/// in [available] -- see [kPositionLeanTiebreakTolerance]'s own doc
/// comment for why this is a tiebreak, not a hard preference. Ties among
/// qualifying lean-position prospects break on [draftProspectValue] too
/// (the best of the ones close enough to matter), then list order.
DraftProspect _preferLeanPositionOnNearTie(
  List<DraftProspect> available,
  DraftProspect best,
  Position positionLean,
) {
  final bestValue = draftProspectValue(best);
  final leanCandidates = available.where(
    (p) =>
        p.player.primaryPosition == positionLean &&
        bestValue - draftProspectValue(p) <= kPositionLeanTiebreakTolerance,
  );
  if (leanCandidates.isEmpty) return best;
  return leanCandidates.reduce(
    (a, b) => draftProspectValue(a) >= draftProspectValue(b) ? a : b,
  );
}

/// Records the GM's own pick: [selected] must actually still be available
/// (not already drafted by anyone) and it must actually be
/// [ownTeamAbbreviation]'s turn -- both asserted, since the only caller
/// (`current_franchise_provider.dart`'s draft methods) is expected to
/// have already checked both before ever offering a prospect list to pick
/// from. [ownCoachManagement] (2026-08-19, `hidden_gem.dart`) is the
/// GM's own head coach's Management -- `0` (no bonus) if omitted.
DraftInProgress makeOwnPick({
  required DraftInProgress draft,
  required List<DraftProspect> draftClass,
  required String ownTeamAbbreviation,
  required DraftProspect selected,
  int ownCoachManagement = 0,
}) {
  assert(!draft.isComplete, 'the draft is already complete');
  assert(
    draft.onTheClock == ownTeamAbbreviation,
    'it is not the GM\'s own turn to pick',
  );
  final available = _availableProspects(draftClass, draft.picks);
  assert(
    available.any((p) => p.player.id == selected.player.id),
    'the selected prospect is not actually available',
  );
  return _appendPick(draft, selected, {
    ownTeamAbbreviation: ownCoachManagement,
  });
}

/// Lands every pick in [franchise]'s (assumed complete)
/// [Franchise.draftInProgress] onto the right roster -- the GM's own team
/// via [Franchise.copyWithRoster], every AI team via its own
/// [AiTeamRoster.copyWithRoster] -- assigning each drafted player a real
/// jersey number ([assignJerseyNumberAvoiding], seeded off [random]) that
/// doesn't collide with their new teammates. Every landed player starts
/// [RosterStatus.active] -- rookies fresh off the board haven't earned a
/// developmental/reserve assignment, same posture a free-agent signing
/// defaults to. Clears both [Franchise.draftInProgress] (back to `null`)
/// and [Franchise.draftClass] (undrafted prospects don't stay
/// draft-eligible into next season either -- `beginNextSeason` already
/// fully replaces the class every season regardless).
///
/// Asserts the draft is actually [DraftInProgress.isComplete] --
/// finalizing a draft with picks still outstanding would silently strand
/// those teams without the players they were about to take.
///
/// Also stamps every drafted player's real [PlayerDraftRecord] (season/
/// round/overall pick) on the way onto a roster -- a direct GM ask
/// (2026-08-19): "After the first season, when you click on a player who
/// was drafted, we should see what season, round, and pick they were
/// drafted." [Franchise.season] has already been bumped to the season
/// this draft belongs to by the time it resolves (`beginNextSeason` sets
/// [Franchise.draftInProgress] as part of the same transition), so
/// [updated.season] here is exactly right.
Franchise finalizeDraft(Random random, Franchise franchise) {
  final draft = franchise.draftInProgress;
  assert(draft != null, 'no draft is in progress to finalize');
  assert(draft!.isComplete, 'the draft still has outstanding picks');

  var updated = franchise;
  for (final pick in draft!.picks) {
    final draftedPlayer = pick.prospect.player.copyWithDraftRecord(
      PlayerDraftRecord(
        season: updated.season,
        round: pick.round,
        pickNumber: pick.pickNumber,
      ),
    );

    if (pick.teamAbbreviation == updated.team.abbreviation) {
      final signed = assignJerseyNumberAvoiding(
        random,
        draftedPlayer,
        updated.roster,
      );
      updated = updated.copyWithRoster([
        ...updated.roster,
        RosterMembership(player: signed, status: RosterStatus.active),
      ]);
      continue;
    }

    final aiTeams = [
      for (final aiTeam in updated.league.aiTeams)
        if (aiTeam.team.abbreviation == pick.teamAbbreviation)
          _addToAiRoster(random, aiTeam, draftedPlayer)
        else
          aiTeam,
    ];
    updated = updated.copyWithLeague(League(aiTeams: aiTeams));
  }

  return updated.copyWithDraftInProgress(null).copyWithDraftClass(const []);
}

AiTeamRoster _addToAiRoster(
  Random random,
  AiTeamRoster aiTeam,
  Player draftedPlayer,
) {
  final signed = assignJerseyNumberAvoiding(
    random,
    draftedPlayer,
    aiTeam.roster,
  );
  return aiTeam.copyWithRoster([
    ...aiTeam.roster,
    RosterMembership(player: signed, status: RosterStatus.active),
  ]);
}
