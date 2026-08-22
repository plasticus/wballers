import '../../franchise/domain/draft_waived_player.dart';
import '../../franchise/domain/franchise.dart';
import '../../franchise/domain/franchise_legality.dart';
import '../../franchise/domain/injury_report_entry.dart';
import '../../franchise/domain/league_retirement.dart';
import '../../player/domain/player.dart';
import '../../player/domain/player_injury.dart';
import '../../player/domain/retirement_reason.dart';
import '../../roster/domain/roster_legality.dart';
import '../../roster/domain/roster_membership.dart';
import '../../roster/domain/roster_status.dart';
import '../../season/domain/game_day.dart';
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

/// Stable id for an own-roster player's injury recommendation, one per
/// [Player.id] -- exported so `mailboxFor` and any test asserting on it
/// share the exact same format. See [assistantGmInjuryRecommendationMessage].
String injuryRecommendationMailId(String playerId) =>
    '$_kInjuryRecommendationPrefix$playerId';

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
    // [kRosterGapMailId] is a scripted Day-0 onboarding beat, not a
    // recurring "you're short a player" nudge -- a direct GM report
    // (2026-08-20): a mid-career retirement reopened a roster spot and
    // resurrected the exact same "Last Roster Spot" email a fresh
    // expansion team gets on day one, which read as though the game
    // thought this was still a brand-new franchise. A second report
    // (2026-08-21) found `franchise.season == 0` alone still wasn't
    // tight enough -- season 0 itself runs a full ~24 weeks, so an
    // ordinary mid-season roster dip (an injury benching, say) kept
    // resurrecting it too. [isFranchiseDayZero] is the real, narrow gate
    // now -- see its own doc comment. `leagueRetirements`/a real
    // off-season report is the actual notification a later gap
    // deserves, not this one; a same-season, non-Day-0 gap has no
    // notification of its own yet beyond whatever specific cause (an
    // injury) already gets one (`assistantGmInjuryRecommendationMessage`).
    // [kRosterCompleteMailId]'s own condition is untouched -- it isn't
    // part of this bug, and stays keyed to the whole of season 0 (its
    // own doc comment already explains why it needs to persist, not
    // vanish, once shown).
    if (isFranchiseDayZero(franchise) && activeCount < kActiveRosterSize)
      AssistantGmMailItem(
        id: kRosterGapMailId,
        subject: 'Last Roster Spot',
        body: assistantGmRosterGapMessage(franchise),
      )
    else if (franchise.season == 0 && activeCount >= kActiveRosterSize)
      AssistantGmMailItem(
        id: kRosterCompleteMailId,
        subject: 'Roster Set',
        body: assistantGmRosterCompleteMessage,
      ),
    if (franchise.leagueRetirements
            .where((r) => r.teamAbbreviation != franchise.team.abbreviation)
            .toList()
        case final aiRetirements when aiRetirements.isNotEmpty)
      LeagueRetirementsMailItem(
        season: franchise.season,
        retirements: aiRetirements,
      ),
    // One real, per-player mail for the GM's own roster specifically --
    // a direct GM report (2026-08-22): "Couldn't tell if my star player
    // retired. I skimmed the end season report a little too fast...
    // possibly also a mail from my asst that the star player retired,
    // and will need to be replaced asap." [LeagueRetirement]'s own doc
    // comment explains why this one list now covers both AI and the
    // GM's own roster, filtered apart right here.
    for (final retirement in franchise.leagueRetirements)
      if (retirement.teamAbbreviation == franchise.team.abbreviation)
        AssistantGmMailItem(
          id: ownRetirementMailId(retirement.playerId),
          subject: '${retirement.name} Has Retired',
          body: assistantGmOwnRetirementMessage(retirement),
        ),
    // A real, per-draft recap -- a direct GM ask (2026-08-22): "I need
    // to get an email after the draft noting who I drafted, and how
    // excited she is for them to join the team. Advise to make use of
    // development slots, and lament the loss of some good bench
    // players to maintain a legal roster." [_draftedThisSeason] and
    // [Franchise.draftWaivedPlayers] both naturally go stale the moment
    // the *next* season's own draft finishes (the former no longer
    // matches [Franchise.season], the latter's already been reset by
    // `copyWithNewSeason`), so this needs no separate "already
    // announced" flag of its own.
    if (_draftedThisSeason(franchise) case final drafted
        when drafted.isNotEmpty)
      AssistantGmMailItem(
        id: draftRecapMailId(franchise.season),
        subject: 'Draft Recap',
        body: assistantGmDraftRecapMessage(
          drafted: drafted,
          waived: franchise.draftWaivedPlayers,
        ),
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
    for (final group in _injuryReportsByGameDay(franchise.injuryReports))
      InjuryReportMailItem(week: group.$1, day: group.$2, entries: group.$3),
    for (final membership in franchise.roster)
      if (membership.recoveredWhileReserved)
        InjuryRecoveredMailItem(player: membership.player),
    // A real, per-player recommendation -- the actual replacement for the
    // scripted "sign a free agent" message that used to wrongly re-fire
    // here (2026-08-21, a direct GM report: pulling an injured player out
    // of the lineup triggered the Day-0 roster-gap script all over
    // again). Live-derived off [RosterMembership.injury] the same
    // "appears until fixed" way [InjuryRecoveredMailItem] is -- only
    // while she's still sitting [RosterStatus.active] with the injury,
    // since moving her to Injured/Inactive is exactly the action being
    // recommended below.
    for (final membership in franchise.roster)
      if (membership.status == RosterStatus.active && membership.injury != null)
        AssistantGmMailItem(
          id: injuryRecommendationMailId(membership.player.id),
          subject: '${membership.player.name} is Hurt',
          body: assistantGmInjuryRecommendationMessage(membership),
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
    item is InjuryRecoveredMailItem ||
    (item is AssistantGmMailItem &&
        (item.id == kRosterGapMailId ||
            item.id.startsWith(_kInjuryRecommendationPrefix) ||
            item.id.startsWith(_kOwnRetirementPrefix)));

/// Shared with [injuryRecommendationMailId] -- kept as its own constant so
/// [_isPinned]'s prefix check can never drift out of sync with the id
/// format that function actually produces.
const _kInjuryRecommendationPrefix = 'injury_recommendation_';

/// Shared with [ownRetirementMailId] -- same reasoning as
/// [_kInjuryRecommendationPrefix].
const _kOwnRetirementPrefix = 'own_retirement_';

/// Shared with [draftRecapMailId] -- same reasoning as
/// [_kInjuryRecommendationPrefix], used by [_recencyWeek]'s own prefix
/// match rather than [_isPinned] (the draft recap isn't actionable, so
/// it sorts by recency like any other report instead of pinning).
const _kDraftRecapPrefix = 'draft_recap_';

/// Stable id for one season's draft-recap mail -- exported so
/// `mailboxFor` and any test asserting on it share the exact same
/// format. See [assistantGmDraftRecapMessage].
String draftRecapMailId(int season) => '$_kDraftRecapPrefix$season';

/// Every player [franchise]'s own roster picked up in this exact
/// season's own draft, sorted earliest pick first -- [PlayerDraftRecord]
/// is the real signal (`draft_advancer.dart`'s `finalizeDraft`), never
/// just `yearsOfService == 0`, so a free-agent rookie signing is never
/// miscredited as a draft pick here.
List<Player> _draftedThisSeason(Franchise franchise) {
  return [
    for (final membership in franchise.roster)
      if (membership.player.draftRecord?.season == franchise.season)
        membership.player,
  ]..sort(
    (a, b) => a.draftRecord!.pickNumber.compareTo(b.draftRecord!.pickNumber),
  );
}

/// Stable id for the GM's own roster player's retirement mail, one per
/// [Player.id] -- exported so `mailboxFor` and any test asserting on it
/// share the exact same format. See [assistantGmOwnRetirementMessage].
String ownRetirementMailId(String playerId) =>
    '$_kOwnRetirementPrefix$playerId';

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
  InjuryReportMailItem(:final week) => week,
  AssistantGmMailItem(id: kRosterCompleteMailId) => -1,
  // Same off-season bucket as [LeagueRetirementsMailItem] above -- the
  // draft has no real calendar week of its own to key off either.
  AssistantGmMailItem(:final id) when id.startsWith(_kDraftRecapPrefix) =>
    kPostseasonFinalsWeek,
  AssistantGmMailItem() ||
  RetirementDecisionMailItem() ||
  RosterLegalityMailItem() ||
  InjuryRecoveredMailItem() => null,
};

/// Groups [entries] (`Franchise.injuryReports`' flat, ungrouped records)
/// into one tuple per (week, day) pair that has at least one -- what
/// [mailboxFor] turns into one [InjuryReportMailItem] per game day. Order
/// follows [entries]' own append order (chronological, since
/// `injury_advancer.dart`'s `resolveInjuries` only ever appends in the
/// order games were actually played), deduplicated by first occurrence of
/// each (week, day) pair.
List<(int, GameDay, List<InjuryReportEntry>)> _injuryReportsByGameDay(
  List<InjuryReportEntry> entries,
) {
  final order = <(int, GameDay)>[];
  final byKey = <(int, GameDay), List<InjuryReportEntry>>{};
  for (final entry in entries) {
    final key = (entry.week, entry.day);
    if (!byKey.containsKey(key)) {
      order.add(key);
      byKey[key] = [];
    }
    byKey[key]!.add(entry);
  }
  return [for (final key in order) (key.$1, key.$2, byKey[key]!)];
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
      'need to sign a free agent before we can advance the season. Four '
      'of our five starting spots are already locked in -- this last '
      'one\'s still open, so I\'d fill it with someone worth building '
      'around, not just a stopgap.'
      '${prospect == null ? '' : ' Take a look at ${prospect.name} '
                '(${prospect.primaryPosition.abbreviation}) -- she can '
                'start for us today, and that ceiling\'s worth the roster '
                'spot too.'}';
}

/// The Assistant GM's real per-player injury recommendation -- replaces
/// the old scripted "sign a free agent" mis-fire with actual advice
/// (2026-08-21, a direct GM ask): names [membership]'s player, her injury
/// grade, and how many games until she's back to full strength, then
/// recommends [InjurySeverity.minor] play through it, anything worse move
/// her to Injured/Inactive to recover as fast as possible (both branches
/// spelled out by name, per the ask). Always closes by naming a
/// short-term free-agent signing as the other option for covering the
/// spot, exactly as asked.
String assistantGmInjuryRecommendationMessage(RosterMembership membership) {
  final player = membership.player;
  final injury = membership.injury!;
  final recommendation = injury.severity == InjurySeverity.minor
      ? 'My read: it\'s minor, so let her play through it -- she\'ll shake '
            'it off in a couple games.'
      : 'My read: don\'t risk making it worse. Move her to an '
            'Injured/Inactive slot so she\'s back to full health as soon as '
            'possible.';
  return 'Boss -- ${player.name} is banged up. ${injury.severity.label} '
      'injury, ${injury.gamesRemainingAtSeverity} game'
      '${injury.gamesRemainingAtSeverity == 1 ? '' : 's'} until she\'s '
      'back to full strength. $recommendation If you need to cover the '
      'spot in the meantime, a short-term free-agent signing works too.';
}

/// The Assistant GM's real notice that [retirement] -- a GM's-own-roster
/// player -- has actually retired, naming her, her position, why, and
/// recommending a replacement (2026-08-22, a direct GM ask: "a mail from
/// my asst that the star player retired, and will need to be replaced
/// asap"). [RetirementReasonLabel.label] is written as a GM-facing
/// *pending*-decision sentence ("She's hit the age... ready to call it a
/// career") -- reused here as-is rather than a separate past-tense
/// wording, since it still reads sensibly as the reason a done decision
/// was made.
String assistantGmOwnRetirementMessage(LeagueRetirement retirement) {
  return 'Boss -- ${retirement.name} '
      '(${retirement.primaryPosition.abbreviation}) has retired. '
      '${retirement.reason.label} We\'re down a player at that spot now '
      '-- take a look at the Player Market to fill it, sooner rather '
      'than later.';
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

/// The Assistant GM's real draft recap, naming every [drafted] player
/// (round/pick included) with genuine enthusiasm, a nudge toward
/// [RosterStatus.developmental] slots, and -- only when [waived] isn't
/// empty -- an honest note about who had to go to make room (2026-08-22,
/// a direct GM ask: "I need to get an email after the draft noting who
/// I drafted, and how excited she is for them to join the team. Advise
/// to make use of development slots, and lament the loss of some good
/// bench players to maintain a legal roster.").
String assistantGmDraftRecapMessage({
  required List<Player> drafted,
  required List<DraftWaivedPlayer> waived,
}) {
  final names = [
    for (final player in drafted)
      '${player.primaryPosition.abbreviation} ${player.name} '
          '(Round ${player.draftRecord!.round}, '
          'Pick ${player.draftRecord!.pickNumber})',
  ];
  final intro = drafted.length == 1
      ? 'Boss -- welcome the newest addition to the roster:'
      : 'Boss -- welcome the ${drafted.length} newest additions to the '
            'roster:';
  final waivedNote = waived.isEmpty
      ? ''
      : '\n\nTo make room, we had to let '
            '${waived.map((p) => '${p.primaryPosition.abbreviation} ${p.name}').join(', ')} '
            'go. Tough call${waived.length == 1 ? '' : 's'}, but good '
            'depth -- the roster\'s legal again.';

  return '$intro\n\n'
      '${names.join('\n')}\n\n'
      'I\'m genuinely excited about this class. Get them into camp and '
      'make good use of the Developmental slots on the ones with '
      'real upside -- that\'s exactly what those spots are there for.'
      '$waivedNote';
}
