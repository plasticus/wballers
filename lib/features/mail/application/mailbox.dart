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
/// [kRosterCompleteMailId] once that's fixed -- always exactly one of
/// the two, never both) sort first, then every [TrainingReportMailItem]
/// newest week first -- the same "actionable before passive" priority
/// the Dashboard's own card ordering already uses.
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
  ];

  items.sort((a, b) {
    final aIsSystem = a is AssistantGmMailItem;
    final bIsSystem = b is AssistantGmMailItem;
    if (aIsSystem != bIsSystem) return aIsSystem ? -1 : 1;
    if (a is TrainingReportMailItem && b is TrainingReportMailItem) {
      return b.report.week.compareTo(a.report.week);
    }
    return 0;
  });
  return items;
}

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
      'need to sign a free agent before we can advance the season. Our '
      'starting five is already set, so I\'d skip the safe veterans and '
      'bet on upside.'
      '${prospect == null ? '' : ' Take a look at ${prospect.name} '
                '(${prospect.primaryPosition.abbreviation}) -- that '
                'ceiling is worth the roster spot.'}';
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
