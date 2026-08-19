import '../../franchise/domain/pending_retirement.dart';
import '../../league/domain/team.dart';
import '../../player/domain/player.dart';
import '../../season/domain/played_game.dart';
import '../../season/domain/skills_competition.dart';
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
