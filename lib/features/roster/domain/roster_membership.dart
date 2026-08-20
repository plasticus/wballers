import '../../player/domain/player.dart';
import '../../player/domain/player_injury.dart';
import 'roster_status.dart';

/// A player's placement on a franchise's roster. Legality (star-tier caps,
/// developmental eligibility) is checked separately by
/// `evaluateRosterLegality` rather than enforced here — a franchise can
/// hold an illegal roster (e.g. right after a trade) and surface it as a
/// validation warning instead of throwing.
class RosterMembership {
  const RosterMembership({
    required this.player,
    required this.status,
    this.injury,
    this.recoveredWhileReserved = false,
  });

  final Player player;
  final RosterStatus status;

  /// This player's current injury, if any (2026-08-20, `player_injury.dart`)
  /// -- roster-relative state (recovery depends on whether *this team*
  /// benches them), not a permanent [Player] fact, so it lives here rather
  /// than on [Player] itself. `null` means healthy.
  final PlayerInjury? injury;

  /// True the moment [injury] clears (via `injury_advancer.dart`'s
  /// resolver) while [status] was [RosterStatus.reserveInactive] -- a
  /// direct GM ask: "you should get an asst gm mail when a player has
  /// fully recovered from injury if they are on the reserve slots, so
  /// that you have a reminder to put them back in the active roster if
  /// you want." Deliberately a durable flag rather than something
  /// [InjuryRecoveredMailItem] tries to infer from [injury] alone --
  /// `injury == null` on its own can't distinguish "just healed, still
  /// parked" from "a healthy player parked here for an unrelated reason"
  /// (`RosterStatus.reserveInactive`'s own doc comment: it's a general
  /// catch-all, not injury-only). Self-clears the moment the GM actually
  /// acts on the reminder -- `current_franchise_provider.dart`'s
  /// `moveRosterStatus` resets it to `false` on any status change away
  /// from [RosterStatus.reserveInactive]. Only ever set for the GM's own
  /// roster -- AI teams reactivate a healed player automatically
  /// (`injury_advancer.dart`), so this flag has no meaning for them.
  final bool recoveredWhileReserved;

  RosterMembership copyWith({
    Player? player,
    RosterStatus? status,
    // A real sentinel, not just a nullable positional default -- `null`
    // needs to mean "clear the injury" (a recovery) as often as it means
    // "not given," so an ordinary `injury ?? this.injury` default would
    // never let a caller actually clear it.
    Object? injury = _unset,
    bool? recoveredWhileReserved,
  }) {
    return RosterMembership(
      player: player ?? this.player,
      status: status ?? this.status,
      injury: identical(injury, _unset) ? this.injury : injury as PlayerInjury?,
      recoveredWhileReserved:
          recoveredWhileReserved ?? this.recoveredWhileReserved,
    );
  }
}

const _unset = Object();
