/// Which of the GM's stated retirement triggers fired for a player
/// (`season/generation/retirement_advancer.dart`'s `evaluateRetirement`/
/// `evaluateRetirementEligibility`, 2026-08-11). Lives in the player
/// domain, not the generation layer, since `PendingRetirement`
/// (`franchise/domain/pending_retirement.dart`) -- a persisted, GM-facing
/// fact -- needs it too, and a domain class importing a generation file
/// would run the dependency the wrong way.
enum RetirementReason {
  /// Hit the mandatory retirement age outright.
  hitMandatoryAge,

  /// Dropped far enough below their own recorded career-peak overall.
  declinedFromPeak,

  /// Old enough, and on the team that just won the championship.
  wonChampionshipLate,

  /// The franchise's own scripted narrative veteran, retiring at the end
  /// of the franchise's very first season on a fixed story beat rather
  /// than any stat-driven trigger (`retirement_advancer.dart`'s
  /// `resolveNarrativeVeteranRetirement`) -- she starts at 33-34, well
  /// under the mandatory retirement age (38 here, `kMandatoryRetirementAge`),
  /// so nothing else would ever retire her this early.
  narrativeVeteran,
}

/// A short, mail-ready sentence explaining why a player is
/// retirement-eligible -- what `RetirementDecisionMailItem`'s detail
/// screen shows the GM.
extension RetirementReasonLabel on RetirementReason {
  String get label => switch (this) {
    RetirementReason.hitMandatoryAge =>
      'She\'s hit the age where she\'s ready to call it a career.',
    RetirementReason.declinedFromPeak =>
      'She\'s fallen well off her career-best form, and it doesn\'t look '
          'like it\'s coming back.',
    RetirementReason.wonChampionshipLate =>
      'She\'s thinking about going out on top after this championship.',
    RetirementReason.narrativeVeteran =>
      'She\'s decided this season was her last -- word is there\'s a '
          'front-row seat waiting for her on the Analyst desk.',
  };
}
