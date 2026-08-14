/// The 4 defensive tactics a GM can pick before a game, at the bottom of
/// the pre-game screen (below The Analysts) -- a direct GM ask
/// (2026-08-14, following the "Coach's Board" design artifact,
/// https://claude.ai/code/artifact/6f075bb0-8dc8-416c-9db1-e29b2c8a4ea6):
/// no separate gameplanning screen, just a short menu right there, always
/// defaulting to [balanced] even when another option would clearly be
/// better -- the GM has to actively choose to deviate. AI opponents
/// always play [balanced], every game, with no exception -- there's no
/// AI-decision code anywhere for this, "always balanced" *is* the
/// implementation (see `match_engine.dart`'s default param value).
enum DefensiveTactic {
  /// The default -- man-to-man, no tradeoff either way.
  balanced,

  /// Key on the opponent's best player specifically, at the cost of
  /// covering everyone else a little thinner.
  faceGuardStar,

  /// Trade perimeter defense for interior defense -- good against a big,
  /// physical front court.
  packThePaint,

  /// Trade interior defense for perimeter defense and disruption -- good
  /// against a team that lives and dies by the three.
  extendAndPressure,
}

/// Small rating-field nudges [DefensiveTactic] applies to whichever team
/// is on defense. [targetedBonus]/[spreadThinPenalty] only ever matter
/// for [DefensiveTactic.faceGuardStar] -- every other tactic leaves both
/// at 0, so a defender-side call site can always add
/// `targetedBonus`-or-`spreadThinPenalty` without needing to know which
/// tactic is actually active. Same magnitude discipline as
/// `offense_shape.dart`'s `OffenseShapeBonus` -- comfortably under
/// `possession_engine.dart`'s +/-5% coach-bonus cap, a reasonable
/// starting point to tune empirically.
typedef DefenseTacticBonus = ({
  double interior,
  double perimeter,
  double disruption,
  double targetedBonus,
  double spreadThinPenalty,
});

const _noDefenseBonus = (
  interior: 0.0,
  perimeter: 0.0,
  disruption: 0.0,
  targetedBonus: 0.0,
  spreadThinPenalty: 0.0,
);

extension DefensiveTacticInfo on DefensiveTactic {
  /// The name shown on the pre-game screen's tactic picker.
  String get label => switch (this) {
    DefensiveTactic.balanced => 'Balanced',
    DefensiveTactic.faceGuardStar => 'Face-Guard the Star',
    DefensiveTactic.packThePaint => 'Pack the Paint',
    DefensiveTactic.extendAndPressure => 'Extend & Pressure',
  };

  /// A quick shorthand of what the tactic is and when to use it -- a
  /// direct GM ask, so each option reads at a glance without having to
  /// guess. Condensed from the Coach's Board artifact's own copy.
  String get shorthand => switch (this) {
    DefensiveTactic.balanced =>
      'Man-to-man, no tradeoff. The default -- start here.',
    DefensiveTactic.faceGuardStar =>
      'Shadow their best player. Use when one player is doing all the '
          'damage.',
    DefensiveTactic.packThePaint =>
      'Protect the rim, dare them to shoot from outside. Use against a '
          'big, physical front court.',
    DefensiveTactic.extendAndPressure =>
      'Push up, deny the perimeter. Use against a team that lives and '
          'dies by the three.',
  };
}

/// [DefensiveTactic]'s rating-field nudges for whichever team is running
/// it. Pack the Paint and Extend & Pressure are mirror-image tradeoffs
/// (interior-vs-perimeter); Face-Guard the Star instead concentrates a
/// large bonus on whichever single opposing player is flagged as the
/// target (`match_engine.dart`'s per-game "best player" lookup) at a
/// small cost everywhere else; Balanced is the zero-everywhere baseline.
DefenseTacticBonus defenseBonusFor(DefensiveTactic tactic) => switch (tactic) {
  DefensiveTactic.balanced => _noDefenseBonus,
  DefensiveTactic.packThePaint => (
    interior: 0.04,
    perimeter: -0.03,
    disruption: 0.0,
    targetedBonus: 0.0,
    spreadThinPenalty: 0.0,
  ),
  DefensiveTactic.extendAndPressure => (
    interior: -0.03,
    perimeter: 0.03,
    disruption: 0.03,
    targetedBonus: 0.0,
    spreadThinPenalty: 0.0,
  ),
  DefensiveTactic.faceGuardStar => (
    interior: 0.0,
    perimeter: 0.0,
    disruption: 0.0,
    targetedBonus: 0.09,
    spreadThinPenalty: -0.015,
  ),
};
