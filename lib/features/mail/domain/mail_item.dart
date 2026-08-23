import '../../franchise/domain/injury_report_entry.dart';
import '../../franchise/domain/league_retirement.dart';
import '../../franchise/domain/pending_retirement.dart';
import '../../league/domain/team.dart';
import '../../player/domain/player.dart';
import '../../roster/domain/roster_legality.dart';
import '../../season/domain/game_day.dart';
import '../../season/domain/played_game.dart';
import '../../season/domain/skills_competition.dart';
import '../../trade/domain/trade_offer.dart';
import '../../training/domain/training_report.dart';

/// One item in the GM's Mail inbox -- replaces the old, purely-passive
/// News feed (`0A_Completed.md`'s News-screen entry) with a real inbox a
/// direct GM ask called for: "drop the News button off the home screen,
/// should be replaced with a Mail button." [MailItem] is the shared shape
/// both kinds of item -- a proactive [AssistantGmMailItem] and an
/// archived [TrainingReportMailItem] -- present through, so
/// `mail/presentation/mail_screen.dart` can list them side by side in one
/// feed instead of two separate screens.
///
/// Mail items are never persisted themselves -- `mailboxFor`
/// (`mail/application/mailbox.dart`) re-derives the current inbox fresh
/// from live franchise state every time, the same "no cached state,
/// always re-derived" posture `currentStandings`/`seasonChampion` already
/// use. Only [id] needs to survive a save/reload, so
/// `Franchise.readMailIds` can remember which ones have been opened.
sealed class MailItem {
  const MailItem();

  /// Stable across rebuilds for a given underlying event/condition --
  /// what `Franchise.readMailIds` actually tracks.
  String get id;

  String get subject;
}

/// A proactive note from the Assistant GM -- currently only the "you're
/// short a roster spot" nudge (see `mailboxFor`'s `kRosterGapMailId`
/// branch), written to read like a real email (To/From/Subject/Message,
/// a direct GM ask) rather than a bare dashboard card. The next system
/// message this game produces (a trade offer, once that system exists)
/// is just another instance of this same class, not a new one.
class AssistantGmMailItem extends MailItem {
  const AssistantGmMailItem({
    required this.id,
    required this.subject,
    required this.body,
  });

  @override
  final String id;

  @override
  final String subject;

  final String body;
}

/// A [TrainingReport], wrapped so it can sit in the same inbox list as
/// [AssistantGmMailItem] -- the entire former `NewsScreen` folded into
/// Mail rather than kept as a second, separate archive.
class TrainingReportMailItem extends MailItem {
  const TrainingReportMailItem(this.report);

  final TrainingReport report;

  @override
  String get id => trainingReportMailId(report.week);

  @override
  // `report.weekRangeLabel` reads "Week 24" for an ordinary single-week
  // cycle, or "Weeks 20-24" when this report's minutes/growth actually
  // span several real weeks at once (`TrainingReport.fromWeek`'s own doc
  // comment) -- a direct GM report, 2026-08-19: an off-season report that
  // silently covered several weeks still only ever said "Week 24."
  String get subject => '${report.weekRangeLabel} Training Report';
}

/// The one place [TrainingReportMailItem.id]'s format is spelled out --
/// shared so `TrainingReportScreen` (which marks a report read on open)
/// and [TrainingReportMailItem] itself can never drift out of sync on
/// what a given week's report is actually called in
/// `Franchise.readMailIds`.
String trainingReportMailId(int week) => 'training_report_$week';

/// A [SkillsCompetitionResult], wrapped the same way [TrainingReportMailItem]
/// wraps a [TrainingReport] -- both events' "post-game report" ask
/// (2026-08-10, TODO.md items 5/6) needed a way to stay reachable after
/// the moment they first resolve, and Mail is where every other
/// once-a-week or once-a-season report already lives.
class SkillsCompetitionMailItem extends MailItem {
  const SkillsCompetitionMailItem(this.result);

  final SkillsCompetitionResult result;

  @override
  String get id => 'skills_competition_${result.week}';

  @override
  String get subject => 'Skills Competition Results';
}

/// A [SkillsCompetitionResult]'s squad selection, wrapped as its own mail
/// item -- a direct GM ask (2026-08-20): "At the start of the all star
/// break, I should get an email telling me if any of my players were
/// chosen." [selections] is the GM's own roster players who made either
/// conference's squad this year (`mailboxFor` cross-references
/// [SkillsCompetitionResult.squads] against [Franchise.roster] fresh each
/// time -- same "never persisted itself" posture every [MailItem]
/// already has), empty when nobody did. Distinct from
/// [SkillsCompetitionMailItem] -- that one reports the 3-event skills
/// contest itself, which honorees actually competed in and who won; this
/// one is purely the roster announcement, arriving the moment squads are
/// set (`all_star_generator.dart`'s own doc comment: squad selection and
/// the skills contest resolve together on [kSkillsCompetitionDay]), same
/// as real league news breaking before the contest airs.
class AllStarSelectionMailItem extends MailItem {
  const AllStarSelectionMailItem({
    required this.result,
    required this.selections,
  });

  final SkillsCompetitionResult result;
  final List<Player> selections;

  @override
  String get id => 'all_star_selection_${result.week}';

  @override
  String get subject => 'All-Star Selections Announced';
}

/// The All-Star Game's [PlayedGame], plus the squad selection
/// [AllStarGameResultScreen] needs to group its box score by conference
/// -- `mailboxFor` builds this fresh from [Franchise.seasonProgress]'s
/// own played-game history and [Franchise.skillsCompetitionResults],
/// same "never persisted itself" posture every [MailItem] already has.
class AllStarGameMailItem extends MailItem {
  const AllStarGameMailItem({required this.playedGame, required this.squads});

  final PlayedGame playedGame;
  final Map<Conference, List<String>> squads;

  @override
  String get id => 'all_star_game_${playedGame.game.week}';

  @override
  String get subject => 'All-Star Game Recap';
}

/// A [PendingRetirement] on the GM's own roster, plus the [player] it's
/// about -- `mailboxFor` looks that player up fresh from
/// [Franchise.roster] every time, same "never persisted itself" posture
/// every [MailItem] already has ([PendingRetirement] itself is what's
/// actually persisted, on [Franchise.pendingRetirements]). Unlike every
/// other [MailItem] here, this one is actionable -- its detail screen
/// (`player/presentation/retirement_decision_screen.dart`) is where the
/// GM actually resolves it, not just reads it.
class RetirementDecisionMailItem extends MailItem {
  const RetirementDecisionMailItem({
    required this.pending,
    required this.player,
  });

  final PendingRetirement pending;
  final Player player;

  @override
  String get id => 'retirement_decision_${pending.playerId}';

  @override
  String get subject => '${player.name} is Considering Retirement';
}

/// This season's batch of [LeagueRetirement]s -- an Assistant GM roundup
/// of every AI-team retirement the just-finished off-season resolved
/// automatically (2026-08-20, a direct GM ask: "an email from asst gm
/// notifying of all retirements"), wrapped the same way
/// [SkillsCompetitionMailItem] wraps a [SkillsCompetitionResult]. See
/// [LeagueRetirement]'s own doc comment for why the GM's own roster and
/// the narrative veteran are deliberately left off this list.
class LeagueRetirementsMailItem extends MailItem {
  const LeagueRetirementsMailItem({
    required this.season,
    required this.retirements,
  });

  final int season;
  final List<LeagueRetirement> retirements;

  @override
  String get id => 'league_retirements_$season';

  @override
  String get subject => 'League Retirements';
}

/// A live warning that the GM's own roster currently violates one or
/// more of [RosterLegality]'s rules -- re-derived fresh from
/// [Franchise.roster] every time, same "real, re-derived state, not a
/// one-time nudge" posture `mailbox.dart`'s own [kRosterGapMailId]
/// already established (2026-08-20, a direct GM ask: "I think we need to
/// build in more notifications of roster legality... I feel like I
/// should get an email right after the draft from the asst gm"). Appears
/// the moment the roster goes illegal (most commonly right after a
/// draft) and disappears the moment it's fixed -- there's nothing to
/// persist, [legality] itself is cheap to recompute.
///
/// [suggestedDrops] (2026-08-23, a direct GM design call: "Asst gm can
/// make suggestions about who to drop or what to do, but will not
/// actually do it") names real, specific players actually worth
/// considering -- `mailbox.dart`'s `suggestedRosterFixes` targets
/// whichever tier is actually over (the weakest active players when
/// roster size itself is the problem, the weakest four-star/three-star
/// players specifically when a star-tier cap is what's blown) rather
/// than a generic "trim the bottom of the roster" gesture. Purely
/// advisory -- nothing here ever touches the roster on its own; see
/// `draft_advancer.dart`'s `finalizeDraft` for why that's a deliberate
/// reversal of an earlier auto-waive ("My asst GM let 3 players go.
/// That's baloney. She can't do that!").
class RosterLegalityMailItem extends MailItem {
  const RosterLegalityMailItem({
    required this.legality,
    this.suggestedDrops = const [],
  });

  final RosterLegality legality;
  final List<Player> suggestedDrops;

  @override
  String get id => 'assistant_gm_roster_legality';

  @override
  String get subject => 'Roster Legality Issue';
}

/// The Assistant GM actively brokering trades to fix a just-finished
/// draft's roster overflow -- distinct from [RosterLegalityMailItem]'s
/// passive "here's who to consider dropping" note: this fires only when
/// there's nowhere left to put a drafted rookie at all (active *and*
/// developmental rosters both already full) and comes with real,
/// concrete trade proposals already worked out, not just a suggestion.
/// A direct GM ask (2026-08-23): "The asst gm should bust her ass trying
/// to trade out 3 players at the bottom of your roster and dev
/// slots... She should find 3x special deals just for them... She
/// should email about how she's cooking it up, and the gm needs to
/// figure it out before the week 1 game."
///
/// [candidates] are the specific players she's trying to move,
/// [proposedOffers] the real deals she's actually found for them so far
/// (`trade_offer_generator.dart`'s `assistantGmBrokeredOffers`) --
/// [proposedOffers] can be shorter than [candidates] if she genuinely
/// couldn't find a match for one of them yet, a real and honest
/// outcome, not padded to always match. Purely advisory, same posture
/// [RosterLegalityMailItem] already established -- nothing here
/// executes on its own; the GM still has to go accept one for real on
/// the Trade Board.
class AssistantGmTradeBrokeringMailItem extends MailItem {
  const AssistantGmTradeBrokeringMailItem({
    required this.candidates,
    required this.proposedOffers,
  });

  final List<Player> candidates;
  final List<TradeOffer> proposedOffers;

  @override
  String get id => 'assistant_gm_trade_brokering';

  @override
  String get subject => 'Working the Phones';
}

/// Every new injury (across the whole league, the GM's own roster
/// included) from one real game day, grouped by [week]/[day]
/// (2026-08-20, following the injuries design pass). `Franchise.injuryReports`
/// is where the flat, ungrouped records actually live -- `mailboxFor`
/// groups them into one of these per game day that produced at least one.
class InjuryReportMailItem extends MailItem {
  const InjuryReportMailItem({
    required this.week,
    required this.day,
    required this.entries,
  });

  final int week;
  final GameDay day;
  final List<InjuryReportEntry> entries;

  @override
  String get id => 'injury_report_${week}_${day.name}';

  @override
  String get subject => 'Injury Report';
}

/// [player] has fully recovered while still parked in
/// [RosterStatus.reserveInactive] -- a direct GM ask: "you should get an
/// asst gm mail when a player has fully recovered from injury if they are
/// on the reserve slots, so that you have a reminder to put them back in
/// the active roster if you want." Live-derived from
/// [RosterMembership.recoveredWhileReserved] every time, same "appears
/// until fixed" posture [RosterLegalityMailItem] already has -- see that
/// field's own doc comment for why a durable flag (not just
/// `injury == null`) is what makes this safe to re-derive.
class InjuryRecoveredMailItem extends MailItem {
  const InjuryRecoveredMailItem({required this.player});

  final Player player;

  @override
  String get id => 'injury_recovered_${player.id}';

  @override
  String get subject => '${player.name} is Ready to Play';
}
