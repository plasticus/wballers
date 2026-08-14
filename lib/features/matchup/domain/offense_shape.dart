import '../../player/domain/player.dart';

/// The 4 lineup shapes a real starting five can read as, purely from its
/// 5 positions -- a direct GM ask (2026-08-14, following the "Coach's
/// Board" design artifact,
/// https://claude.ai/code/artifact/6f075bb0-8dc8-416c-9db1-e29b2c8a4ea6):
/// offense should shift automatically based on who's actually on the
/// floor, with no GM dial to set. [detectOffenseShape] is the only way
/// this ever gets decided -- there's no persisted "team identity" here,
/// just a fresh read of the current starting five every time it's asked.
enum OffenseShape {
  /// 2 guards, 1 wing, 2 bigs -- the classic split. The baseline every
  /// other shape is measured against; [offenseBonusFor] gives it no
  /// bonus at all on purpose.
  traditional,

  /// 1 or 0 bigs on the floor. A false-9 lineup: no real target man, so
  /// it wins with movement and spacing instead.
  paceAndSpace,

  /// 3+ bigs on the floor. Two-plus true targets -- goes direct, works
  /// it inside.
  postUp,

  /// Anything that isn't clearly one of the 3 shapes above -- a lineup
  /// with no dominant group of positions reads as genuinely balanced,
  /// not as a coincidental miss of "traditional."
  motion,
}

/// Small rating-field nudges [OffenseShape] applies to whichever team is
/// on offense -- mirrors `defensive_tactic.dart`'s `DefenseTacticBonus`
/// shape and the existing coach-matchup bonus's own magnitude
/// (`possession_engine.dart`'s `kCoachMatchupBonusCap`, +/-5%):
/// comfortably under that cap so shape and coach bonuses can stack
/// without either swamping the other. A reasonable starting point, not a
/// precisely calibrated one -- tune empirically like every other bonus
/// constant in this engine.
typedef OffenseShapeBonus = ({
  double interior,
  double perimeter,
  double passing,
});

const _noOffenseBonus = (interior: 0.0, perimeter: 0.0, passing: 0.0);

extension OffenseShapeInfo on OffenseShape {
  /// The name shown on the pre-game screen and the Bench Order screen.
  String get label => switch (this) {
    OffenseShape.traditional => 'Traditional Halfcourt',
    OffenseShape.paceAndSpace => 'Pace & Space',
    OffenseShape.postUp => 'Post-Up',
    OffenseShape.motion => 'Motion',
  };

  /// One line explaining why this shape is what it is -- condensed from
  /// the Coach's Board artifact's own soccer-analogy copy.
  String get why => switch (this) {
    OffenseShape.traditional =>
      'Two guards, a wing, two bigs -- the classic split. Nothing exotic.',
    OffenseShape.paceAndSpace =>
      'No real target man on the floor -- wins with movement and spacing '
          'instead of a post presence.',
    OffenseShape.postUp =>
      'Two-plus true bigs -- goes direct, works it inside.',
    OffenseShape.motion =>
      'No dominant group of positions -- reads as genuinely balanced.',
  };
}

/// Counts guards (PG+SG), wings (SF), and bigs (PF+C) among
/// [startingFive] and buckets the result into one of the 4 [OffenseShape]s.
/// Order matters -- a heavy-bigs lineup is checked first, since 3+ bigs
/// always reads as [OffenseShape.postUp] regardless of how the other 2
/// spots split. Doesn't assert a length of 5 -- a defensively-safe count
/// of whatever's actually passed in, so a short list (should never happen
/// in practice; every active roster has well over 5 players) still
/// resolves to something rather than crashing.
OffenseShape detectOffenseShape(List<Player> startingFive) {
  final guards = startingFive
      .where(
        (p) =>
            p.primaryPosition == Position.pointGuard ||
            p.primaryPosition == Position.shootingGuard,
      )
      .length;
  final wings = startingFive
      .where((p) => p.primaryPosition == Position.smallForward)
      .length;
  final bigs = startingFive
      .where(
        (p) =>
            p.primaryPosition == Position.powerForward ||
            p.primaryPosition == Position.center,
      )
      .length;

  if (bigs >= 3) return OffenseShape.postUp;
  if (bigs <= 1) return OffenseShape.paceAndSpace;
  if (guards == 2 && wings == 1 && bigs == 2) return OffenseShape.traditional;
  return OffenseShape.motion;
}

/// [OffenseShape]'s rating-field nudges for whichever team is running it.
/// Pace & Space trades interior scoring for perimeter scoring and a touch
/// of ball movement; Post-Up is the mirror image; Motion keeps both
/// scoring fields neutral but rewards ball movement a little; Traditional
/// is the zero-everywhere baseline.
OffenseShapeBonus offenseBonusFor(OffenseShape shape) => switch (shape) {
  OffenseShape.traditional => _noOffenseBonus,
  OffenseShape.paceAndSpace => (
    interior: -0.035,
    perimeter: 0.035,
    passing: 0.015,
  ),
  OffenseShape.postUp => (interior: 0.035, perimeter: -0.035, passing: 0.0),
  OffenseShape.motion => (interior: 0.0, perimeter: 0.0, passing: 0.025),
};

/// The 5 players who'd carry the most minutes for [players], without
/// needing an already-resolved `Map<Player, int>` target-minutes map the
/// way [startingFiveByMinutes] does -- for display-only callers (the
/// pre-game screen) that want to preview a shape without pulling in
/// `targetMinutesForOrderedRoster`/`targetMinutesFor`'s own strict
/// "exactly 12 players" assertion, which a lightweight preview shouldn't
/// have to satisfy. [isBenchOrdered] mirrors the same convention
/// `match_engine.dart` actually simulates with: `true` for the GM's own
/// team (real bench order -- just the first 5 in list order), `false`
/// for every other side (an automatic overall-based sort, best 5 first,
/// same shape as `substitution_policy.dart`'s `targetMinutesFor`'s own
/// internal sort). Doesn't assert any particular length -- a short list
/// still resolves gracefully, same as [detectOffenseShape] itself.
List<Player> startingFiveFor(
  List<Player> players, {
  required bool isBenchOrdered,
}) {
  if (isBenchOrdered) return players.take(5).toList();
  final sorted = [...players]
    ..sort((a, b) => b.ratings.overall.compareTo(a.ratings.overall));
  return sorted.take(5).toList();
}

/// The 5 players carrying the most assigned minutes in [targetMinutes] --
/// "the starting five," for whichever convention produced this map
/// (`targetMinutesForOrderedRoster`'s bench order for the GM's own team,
/// `targetMinutesFor`'s automatic overall-based sort for every AI
/// opponent -- see `match_engine.dart`). Deliberately reads off the
/// minutes map rather than the roster list directly, since only the
/// minutes map is guaranteed to already reflect the right convention for
/// whichever side it came from. Ties among the top 5 (e.g. the 3 players
/// at the top target-minutes band) don't matter here -- only *set
/// membership* in the top 5 affects the resulting [OffenseShape], not
/// their relative order within it.
List<Player> startingFiveByMinutes(Map<Player, int> targetMinutes) {
  final byMinutes = targetMinutes.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return byMinutes.take(5).map((entry) => entry.key).toList();
}
