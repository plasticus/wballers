import 'dart:math';

import 'trait.dart';

/// The 3 injury severity tiers (`0B_Planned.md`, "Injury model, reworked"
/// 2026-08-06) -- each a fixed stat-percentage reduction for a fixed
/// number of games. Ordered mild-to-severe so [InjurySeverity.values]
/// indexing (`index - 1`) is [oneTierMilder]'s recovery step.
enum InjurySeverity {
  /// 10% reduction, 2 games.
  minor,

  /// 25% reduction, 4 games.
  moderate,

  /// 50% reduction, 6 games.
  major,
}

extension InjurySeverityRules on InjurySeverity {
  /// The rating-multiplier delta this tier costs a player who plays
  /// through it -- negative, summed into `possession_engine.dart`'s
  /// per-player bonus accumulator via [injuryBonusFor], the same slot
  /// `fatigue.dart`'s energy penalty already shares.
  double get ratingPenalty => switch (this) {
    InjurySeverity.minor => -0.10,
    InjurySeverity.moderate => -0.25,
    InjurySeverity.major => -0.50,
  };

  /// How many of the player's own team's games this tier lasts before
  /// automatically dropping a tier, if never benched sooner
  /// ([PlayerInjury.recoverAfterGame]'s "played through it, counter hits
  /// zero" branch).
  int get baseDurationGames => switch (this) {
    InjurySeverity.minor => 2,
    InjurySeverity.moderate => 4,
    InjurySeverity.major => 6,
  };

  String get label => switch (this) {
    InjurySeverity.minor => 'Minor',
    InjurySeverity.moderate => 'Moderate',
    InjurySeverity.major => 'Major',
  };

  /// One tier milder, or `null` if [this] is already [InjurySeverity.minor]
  /// -- a `null` result is a full recovery, not another tier.
  InjurySeverity? get oneTierMilder {
    final i = InjurySeverity.values.indexOf(this);
    return i == 0 ? null : InjurySeverity.values[i - 1];
  }
}

/// A player's current injury, if any -- lives on `RosterMembership`
/// (roster-relative state, not a permanent [Player] fact) rather than on
/// [Player] itself.
///
/// Recovery is bench-driven, not just time-driven (`0B_Planned.md`'s own
/// worked example): sitting a player for a full game (0 real minutes --
/// whether benched by choice or simply not in [RosterStatus.active] that
/// day) drops [severity] one full tier immediately, resetting
/// [gamesRemainingAtSeverity] to the new tier's [InjurySeverityRules.
/// baseDurationGames] -- *regardless* of how many games remained at the
/// old tier. Playing through it instead just ticks
/// [gamesRemainingAtSeverity] down by one game; hitting 0 drops a tier the
/// same way. Either path drops a [InjurySeverity.minor] injury straight to
/// fully healed (a `null` [PlayerInjury] on the roster).
class PlayerInjury {
  const PlayerInjury({
    required this.severity,
    required this.gamesRemainingAtSeverity,
  });

  /// A freshly-suffered injury, at [severity]'s own full base duration.
  factory PlayerInjury.fresh(InjurySeverity severity) => PlayerInjury(
    severity: severity,
    gamesRemainingAtSeverity: severity.baseDurationGames,
  );

  final InjurySeverity severity;

  /// Games left at [severity] before automatically dropping a tier --
  /// always positive; a drop to 0 (or a bench-driven early drop) produces
  /// a new [PlayerInjury] (or `null`, fully healed) rather than this
  /// field ever reading 0 on a live roster.
  final int gamesRemainingAtSeverity;

  /// The next state after one more of this player's own team's games --
  /// `null` means fully healed, off the roster's injury tracking entirely.
  /// [playedRealMinutes] is whether the player actually logged minutes
  /// that game; `false` covers both a deliberate bench (still on the
  /// active/on-court rotation but held out) and simply not being in
  /// [RosterStatus.active] that day (parked in Reserve/Inactive) -- both
  /// count as "sitting a full game" per the original design note.
  PlayerInjury? recoverAfterGame({required bool playedRealMinutes}) {
    if (!playedRealMinutes) {
      // Benched (by either mechanism) -- an instant full-tier drop,
      // regardless of gamesRemainingAtSeverity.
      final milder = severity.oneTierMilder;
      return milder == null ? null : PlayerInjury.fresh(milder);
    }
    // Played through it -- the ordinary one-game-closer countdown.
    if (gamesRemainingAtSeverity > 1) {
      return PlayerInjury(
        severity: severity,
        gamesRemainingAtSeverity: gamesRemainingAtSeverity - 1,
      );
    }
    final milder = severity.oneTierMilder;
    return milder == null ? null : PlayerInjury.fresh(milder);
  }
}

/// [injury]'s current rating penalty, or 0 for an uninjured (`null`)
/// player -- what `match_engine.dart`'s per-player `injuryPenalty` map
/// gets built from, one entry per active roster player, ahead of a game.
double injuryBonusFor(PlayerInjury? injury) =>
    injury?.severity.ratingPenalty ?? 0.0;

/// Base per-player-game injury chance in the regular season/Continental
/// Cup -- ~1%, only ever rolled for a player who actually logged real
/// minutes that game (`0B_Planned.md`'s own request: "resolved after
/// game," a direct GM decision round). Halved in the postseason
/// ([postseasonInjuryChance]) -- the game shouldn't actively work against
/// a GM's own title push.
const kBaseInjuryChancePerPlayerGame = 0.01;

/// [Trait.injuryProne] multiplies [kBaseInjuryChancePerPlayerGame] by
/// this; [Trait.ironMan] by [kIronManInjuryChanceMultiplier] -- both a
/// direct GM decision round ("traits modify both chance and severity
/// odds").
const kInjuryProneChanceMultiplier = 1.5;
const kIronManInjuryChanceMultiplier = 0.5;

/// The actual per-player-game injury chance to roll against, given
/// [traits] and whether it's [isPostseason]. Halves for the postseason
/// after the trait multiplier, not before -- order doesn't actually
/// change the result (both are plain multiplications) but matches how
/// the design note frames it ("base chance... halved in the postseason").
double injuryChanceFor({
  required Set<Trait> traits,
  required bool isPostseason,
}) {
  var chance = kBaseInjuryChancePerPlayerGame;
  if (traits.contains(Trait.injuryProne)) {
    chance *= kInjuryProneChanceMultiplier;
  } else if (traits.contains(Trait.ironMan)) {
    chance *= kIronManInjuryChanceMultiplier;
  }
  if (isPostseason) chance /= 2;
  return chance;
}

/// Weighted odds across the 3 [InjurySeverity] tiers (minor/moderate/
/// major, in that order) once an injury has actually been rolled -- equal
/// (1/1/1) by default per a direct GM decision round ("equal odds across
/// all 3 tiers," explicitly against a "weighted toward mild" suggestion).
/// [Trait.injuryProne] skews toward longer/more severe injuries
/// (matching `traits.md`'s own description); [Trait.ironMan] skews
/// toward shorter ones when it does happen -- both a reasonable
/// implementation of the same decision round's "traits modify... severity
/// odds" call, not separately re-confirmed number-for-number.
List<int> severityWeightsFor(Set<Trait> traits) {
  if (traits.contains(Trait.injuryProne)) return const [1, 2, 3];
  if (traits.contains(Trait.ironMan)) return const [3, 1, 1];
  return const [1, 1, 1];
}

/// Rolls a random [InjurySeverity] off [severityWeightsFor]'s weights for
/// [traits].
InjurySeverity rollInjurySeverity(Random random, Set<Trait> traits) {
  final weights = severityWeightsFor(traits);
  final total = weights.reduce((a, b) => a + b);
  var roll = random.nextInt(total);
  for (var i = 0; i < InjurySeverity.values.length; i++) {
    if (roll < weights[i]) return InjurySeverity.values[i];
    roll -= weights[i];
  }
  return InjurySeverity.values.last; // unreachable given the loop above
}
