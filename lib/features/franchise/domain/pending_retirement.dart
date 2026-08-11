import '../../player/domain/retirement_reason.dart';

/// A GM-own-roster player who's tripped one of the retirement triggers
/// (`season/generation/retirement_advancer.dart`'s
/// `evaluateRetirementEligibility`) and is waiting on a real decision --
/// "let them retire" or "have the coach try to convince them to stay"
/// (`RetirementDecisionMailItem`, `current_franchise_provider.dart`'s
/// `resolvePendingRetirement`). Unlike the AI-side triggers, which
/// resolve themselves the same season, this deliberately sits in
/// [Franchise.pendingRetirements] until the GM actually opens the mail
/// and picks one.
class PendingRetirement {
  const PendingRetirement({required this.playerId, required this.reason});

  final String playerId;
  final RetirementReason reason;
}

/// What actually happened when the GM resolved a [PendingRetirement] --
/// `current_franchise_provider.dart`'s `resolvePendingRetirement` return
/// value, for the decision screen to show a real outcome message rather
/// than just popping silently.
enum RetirementDecisionOutcome {
  /// The GM chose to let the player retire, no persuasion attempted.
  letRetire,

  /// The coach tried to convince the player to stay, and it worked.
  persuadedToStay,

  /// The coach tried to convince the player to stay, and it didn't.
  persuasionFailed,
}
