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
  String get subject => 'Week ${report.week} Training Report';
}

/// The one place [TrainingReportMailItem.id]'s format is spelled out --
/// shared so `TrainingReportScreen` (which marks a report read on open)
/// and [TrainingReportMailItem] itself can never drift out of sync on
/// what a given week's report is actually called in
/// `Franchise.readMailIds`.
String trainingReportMailId(int week) => 'training_report_$week';
