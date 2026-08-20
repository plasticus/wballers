import '../../franchise/domain/franchise.dart';
import '../../franchise/domain/franchise_legality.dart';
import '../../player/domain/position.dart';
import '../../roster/domain/roster_legality.dart';
import '../../roster/domain/roster_status.dart';
import '../../season/domain/scheduled_game.dart';
import '../../season/generation/season_schedule_generator.dart'
    show kPostseasonFinalsWeek;
import '../domain/mail_item.dart';

/// Stable id for the "sign a free agent" system message -- a fresh
/// expansion roster starts one player short of [kActiveRosterSize] on
/// purpose (`roster/generation/starting_roster_generator.dart`'s doc
/// comment), and this is the Assistant GM's nudge about it, per a direct
/// GM ask for a real Day-0 hook. Exported so `Franchise.readMailIds` can
/// be checked/updated against the exact same constant everywhere it's
/// used, instead of a string literal drifting between call sites.
///
/// [mailboxFor] only ever emits this (and [kRosterCompleteMailId]) during
/// [Franchise.season] 0 -- a direct GM report (2026-08-20): a mid-career
/// retirement reopened a roster spot in a later season and resurrected
/// this exact scripted "sign a free agent" nudge, which read as though
/// the game thought the franchise was brand new all over again. A later
/// season's roster gap is real news the GM should hear about, just not
/// through this one-time Day-0 script -- [LeagueRetirementsMailItem] is
/// the real notification instead, whenever the gap traces back to a
/// retirement (a later-season gap from any other cause has no
/// notification yet, left for future work).
const kRosterGapMailId = 'assistant_gm_roster_gap';

/// Stable id for the "roster's full, here's what to do next" system
/// message -- the Assistant GM's follow-up once [kRosterGapMailId]'s own
/// ask gets fulfilled (2026-08-10, a direct GM ask: "after you hire a
/// free agent, the Assistant GM should then send you another email
/// saying that you should take a look at the roster, set up training,
/// and order the roster"). Every fresh expansion roster starts exactly
/// one player short of [kActiveRosterSize]
/// (`starting_roster_generator.dart`'s doc comment), so reaching a full
/// active roster only ever happens by signing a free agent -- no
/// separate "a signing just happened" event log needed to know this
/// message is warranted.
const kRosterCompleteMailId = 'assistant_gm_roster_complete';

/// The GM's current inbox, freshly derived from [franchise] -- see
/// [MailItem]'s doc comment for why nothing here is persisted directly.
/// [kRosterGapMailId] and every [RetirementDecisionMailItem] sort first --
/// both are genuinely actionable (a signing/decision the GM still has to
/// make). Everything else, [kRosterCompleteMailId] included, sorts
/// newest-first by [_recencyWeek] -- the same "actionable before passive,
/// then newest on top" priority the Dashboard's own card ordering already
/// uses.
///
/// [kRosterCompleteMailId] used to share the pinned-forever bucket with
/// [kRosterGapMailId] -- reasonable the moment it first arrives (right
/// after the Day-0 signing, before a single game's been played), but with
/// nothing to actually act on, it just sat glued to the top of the inbox
/// forever afterward while every real week's mail piled up underneath it
/// (2026-08-18, a direct GM report: "still clinging to the top of my
/// inbox in perpetuity... I want new emails to push it down, like a real
/// inbox"). [_recencyWeek] gives it a fixed, always-oldest week (-1, below
/// even Week 0) instead, so it sorts and sinks exactly like any other
/// piece of mail once there's anything newer to push it down with.
///
/// (2026-08-11 originally had [kRosterCompleteMailId] drop out for good
/// the instant it was read, meant to satisfy "the Roster Set email should
/// delete after a couple weeks" -- but reading mail deleting it outright,
/// with no "couple weeks" grace at all, turned out to be exactly the
/// "asst GM mail vanishes right after I read it" bug reported 2026-08-15.
/// Read mail now behaves like every other [MailItem]: [Franchise.readMailIds]
/// marks it read, but it stays in the inbox and simply sorts wherever its
/// recency puts it -- no more read-triggered removal for any mail type.)
List<MailItem> mailboxFor(Franchise franchise) {
  final activeCount = franchise.roster
      .where((m) => m.status == RosterStatus.active)
      .length;

  final items = <MailItem>[
    // Both messages are a scripted Day-0 onboarding beat, not a recurring
    // "you're short a player" nudge -- a direct GM report (2026-08-20):
    // a mid-career retirement reopened a roster spot and resurrected the
    // exact same "Last Roster Spot" email a fresh expansion team gets on
    // day one, which read as though the game thought this was still a
    // brand-new franchise. `leagueRetirements`/a real off-season report
    // is the actual notification a later-season roster gap deserves, not
    // this one. See [kRosterGapMailId]'s own doc comment.
    if (franchise.season == 0)
      if (activeCount < kActiveRosterSize)
        AssistantGmMailItem(
          id: kRosterGapMailId,
          subject: 'Last Roster Spot',
          body: assistantGmRosterGapMessage(franchise),
        )
      else
        AssistantGmMailItem(
          id: kRosterCompleteMailId,
          subject: 'Roster Set',
          body: assistantGmRosterCompleteMessage,
        ),
    if (franchise.leagueRetirements.isNotEmpty)
      LeagueRetirementsMailItem(
        season: franchise.season,
        retirements: franchise.leagueRetirements,
      ),
    if (evaluateFranchiseLegality(franchise) case final legality
        when !legality.isLegal)
      RosterLegalityMailItem(legality: legality),
    for (final report in franchise.trainingReports)
      TrainingReportMailItem(report),
    for (final result in franchise.skillsCompetitionResults) ...[
      AllStarSelectionMailItem(
        result: result,
        selections: [
          for (final membership in franchise.roster)
            if (result.squads.values.any(
              (ids) => ids.contains(membership.player.id),
            ))
              membership.player,
        ],
      ),
      SkillsCompetitionMailItem(result),
    ],
    for (final played in franchise.seasonProgress.playedGames)
      if (played.game.type == GameType.allStarGame)
        AllStarGameMailItem(
          playedGame: played,
          squads: franchise.skillsCompetitionResults
              .firstWhere((r) => r.week == played.game.week)
              .squads,
        ),
    for (final pending in franchise.pendingRetirements)
      RetirementDecisionMailItem(
        pending: pending,
        player: franchise.roster
            .firstWhere((m) => m.player.id == pending.playerId)
            .player,
      ),
  ];

  items.sort((a, b) {
    // Actionable before passive -- a real signing decision or a
    // retirement decision both need the GM to actually do something.
    // [kRosterCompleteMailId] is deliberately *not* included here
    // anymore -- see this function's own doc comment for why.
    final aIsPinned = _isPinned(a);
    final bIsPinned = _isPinned(b);
    if (aIsPinned != bIsPinned) return aIsPinned ? -1 : 1;
    final aWeek = _recencyWeek(a);
    final bWeek = _recencyWeek(b);
    if (aWeek != null && bWeek != null) return bWeek.compareTo(aWeek);
    return 0;
  });
  return items;
}

bool _isPinned(MailItem item) =>
    item is RetirementDecisionMailItem ||
    item is RosterLegalityMailItem ||
    (item is AssistantGmMailItem && item.id == kRosterGapMailId);

/// The season week a given [MailItem] is "about", for newest-first
/// sorting -- `null` for [RetirementDecisionMailItem], [RosterLegalityMailItem],
/// and the genuinely pinned [kRosterGapMailId], which sort by the bucket
/// rule above instead.
/// Every report-like mail type is compared here, not just
/// [TrainingReportMailItem], so e.g. a Week 10 Skills Competition result
/// correctly outranks a Week 8 Training Report instead of falling back to
/// build-order (2026-08-15, a direct GM ask: "new emails at the top").
/// [kRosterCompleteMailId] gets a fixed, always-oldest week (below even
/// Week 0) rather than `null` -- see [mailboxFor]'s own doc comment.
int? _recencyWeek(MailItem item) => switch (item) {
  TrainingReportMailItem(:final report) => report.week,
  AllStarSelectionMailItem(:final result) => result.week,
  SkillsCompetitionMailItem(:final result) => result.week,
  AllStarGameMailItem(:final playedGame) => playedGame.game.week,
  // Retirements resolve right after the Finals, alongside every other
  // off-season pass -- there's no real per-item week to key off (unlike
  // a single played game), so this pins to the Finals' own calendar week,
  // the same moment the rest of the off-season report lands.
  LeagueRetirementsMailItem() => kPostseasonFinalsWeek,
  AssistantGmMailItem(id: kRosterCompleteMailId) => -1,
  AssistantGmMailItem() ||
  RetirementDecisionMailItem() ||
  RosterLegalityMailItem() => null,
};

/// How many items [mailboxFor] would return that aren't yet in
/// [Franchise.readMailIds] -- what the Mail tab's red unread badge shows.
int unreadMailCount(Franchise franchise) {
  return mailboxFor(
    franchise,
  ).where((item) => !franchise.readMailIds.contains(item.id)).length;
}

/// The Assistant GM's "sign a free agent" message body -- shared by
/// [mailboxFor] (the Mail tab's real inbox entry) and the Dashboard's own
/// `_AssistantGmMailCard`, so the two surfaces can never say something
/// different. Names the actual best pickup in `Franchise.freeAgents` by
/// finding whoever has the highest `potential` -- the one
/// deliberately-planted "decent" free agent every pool gets
/// (`roster/generation/free_agent_pool_generator.dart`) stands out from
/// the filler by a wide margin, so no explicit "this is the one" flag is
/// needed on the player itself.
String assistantGmRosterGapMessage(Franchise franchise) {
  final prospect = franchise.freeAgents.isEmpty
      ? null
      : franchise.freeAgents.reduce(
          (a, b) => a.ratings.potential > b.ratings.potential ? a : b,
        );

  return 'Boss -- we\'re one player short of a full active roster. We '
      'need to sign a free agent before we can advance the season. Four '
      'of our five starting spots are already locked in -- this last '
      'one\'s still open, so I\'d fill it with someone worth building '
      'around, not just a stopgap.'
      '${prospect == null ? '' : ' Take a look at ${prospect.name} '
                '(${prospect.primaryPosition.abbreviation}) -- she can '
                'start for us today, and that ceiling\'s worth the roster '
                'spot too.'}';
}

/// The Assistant GM's follow-up once the roster's actually full
/// ([kRosterCompleteMailId]) -- a gentle nudge toward the 3 things worth
/// double-checking before the next game, rather than just going quiet
/// once the Day-0 signing is done. No franchise-specific detail to fold
/// in (unlike [assistantGmRosterGapMessage], which names a real
/// prospect), so this is a plain constant, not a function.
const assistantGmRosterCompleteMessage =
    'Boss -- roster\'s full and we\'re ready to go. Before the next game, '
    'take a look at three things: the Team page (make sure the lineup '
    'reads the way you want it to), Training (a focus for the group, '
    'and whether anyone should get one-on-one attention), and Bench '
    'Order (who\'s actually getting minutes). Let\'s build something.';
