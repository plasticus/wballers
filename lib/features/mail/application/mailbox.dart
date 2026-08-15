import '../../franchise/domain/franchise.dart';
import '../../player/domain/position.dart';
import '../../roster/domain/roster_legality.dart';
import '../../roster/domain/roster_status.dart';
import '../../season/domain/scheduled_game.dart';
import '../domain/mail_item.dart';

/// Stable id for the "sign a free agent" system message -- a fresh
/// expansion roster starts one player short of [kActiveRosterSize] on
/// purpose (`roster/generation/starting_roster_generator.dart`'s doc
/// comment), and this is the Assistant GM's nudge about it, per a direct
/// GM ask for a real Day-0 hook. Exported so `Franchise.readMailIds` can
/// be checked/updated against the exact same constant everywhere it's
/// used, instead of a string literal drifting between call sites.
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
/// System messages ([kRosterGapMailId] while short a player, then
/// [kRosterCompleteMailId] once that's fixed -- never both at once) and
/// every [RetirementDecisionMailItem] sort first (both need real GM
/// action). Everything else sorts newest-first by [_recencyWeek] -- the
/// same "actionable before passive, then newest on top" priority the
/// Dashboard's own card ordering already uses.
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
    for (final report in franchise.trainingReports)
      TrainingReportMailItem(report),
    for (final result in franchise.skillsCompetitionResults)
      SkillsCompetitionMailItem(result),
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
    // Actionable before passive -- a retirement decision needs the GM to
    // actually do something, same footing the system messages already
    // have.
    final aIsSystem =
        a is AssistantGmMailItem || a is RetirementDecisionMailItem;
    final bIsSystem =
        b is AssistantGmMailItem || b is RetirementDecisionMailItem;
    if (aIsSystem != bIsSystem) return aIsSystem ? -1 : 1;
    final aWeek = _recencyWeek(a);
    final bWeek = _recencyWeek(b);
    if (aWeek != null && bWeek != null) return bWeek.compareTo(aWeek);
    return 0;
  });
  return items;
}

/// The season week a given [MailItem] is "about", for newest-first
/// sorting -- `null` for the two actionable types ([AssistantGmMailItem],
/// [RetirementDecisionMailItem]), which sort by the bucket rule above
/// instead. Every report-like mail type is compared here, not just
/// [TrainingReportMailItem], so e.g. a Week 10 Skills Competition result
/// correctly outranks a Week 8 Training Report instead of falling back to
/// build-order (2026-08-15, a direct GM ask: "new emails at the top").
int? _recencyWeek(MailItem item) => switch (item) {
  TrainingReportMailItem(:final report) => report.week,
  SkillsCompetitionMailItem(:final result) => result.week,
  AllStarGameMailItem(:final playedGame) => playedGame.game.week,
  AssistantGmMailItem() || RetirementDecisionMailItem() => null,
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
