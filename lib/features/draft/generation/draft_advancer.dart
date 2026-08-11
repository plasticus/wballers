import 'dart:math';

import '../../franchise/domain/franchise.dart';
import '../../league/domain/ai_team_roster.dart';
import '../../league/domain/league.dart';
import '../../roster/domain/roster_membership.dart';
import '../../roster/domain/roster_status.dart';
import '../../roster/generation/jersey_number_assignment.dart';
import '../domain/draft_in_progress.dart';
import '../domain/draft_pick.dart';
import '../domain/draft_prospect.dart';
import 'draft_generator.dart';

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

DraftInProgress _appendPick(DraftInProgress draft, DraftProspect selected) {
  return DraftInProgress(
    order: draft.order,
    rounds: draft.rounds,
    picks: [
      ...draft.picks,
      DraftPick(
        round: draft.nextRound,
        pickNumber: draft.nextOverallPick,
        teamAbbreviation: draft.onTheClock!,
        prospect: selected,
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
/// remaining pool, nothing here rolls anything.
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
}) {
  var current = draft;
  while (!current.isComplete && current.onTheClock != ownTeamAbbreviation) {
    final available = _availableProspects(draftClass, current.picks);
    assert(available.isNotEmpty, 'no prospects left for an AI team to draft');
    final best = available.reduce(
      (a, b) => draftProspectValue(a) >= draftProspectValue(b) ? a : b,
    );
    current = _appendPick(current, best);
  }
  return current;
}

/// Records the GM's own pick: [selected] must actually still be available
/// (not already drafted by anyone) and it must actually be
/// [ownTeamAbbreviation]'s turn -- both asserted, since the only caller
/// (`current_franchise_provider.dart`'s draft methods) is expected to
/// have already checked both before ever offering a prospect list to pick
/// from.
DraftInProgress makeOwnPick({
  required DraftInProgress draft,
  required List<DraftProspect> draftClass,
  required String ownTeamAbbreviation,
  required DraftProspect selected,
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
  return _appendPick(draft, selected);
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
Franchise finalizeDraft(Random random, Franchise franchise) {
  final draft = franchise.draftInProgress;
  assert(draft != null, 'no draft is in progress to finalize');
  assert(draft!.isComplete, 'the draft still has outstanding picks');

  var updated = franchise;
  for (final pick in draft!.picks) {
    if (pick.teamAbbreviation == updated.team.abbreviation) {
      final signed = assignJerseyNumberAvoiding(
        random,
        pick.prospect.player,
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
          _addToAiRoster(random, aiTeam, pick.prospect)
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
  DraftProspect prospect,
) {
  final signed = assignJerseyNumberAvoiding(
    random,
    prospect.player,
    aiTeam.roster,
  );
  return aiTeam.copyWithRoster([
    ...aiTeam.roster,
    RosterMembership(player: signed, status: RosterStatus.active),
  ]);
}
