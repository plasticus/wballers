import '../../player/domain/position.dart';

/// One player waived off the GM's own active roster purely to make room
/// for this season's just-finished draft class -- `draft_advancer.dart`'s
/// `_waiveDownToLegal` is the real mechanism (roster crunch, weakest
/// pre-existing active player waived to free agency); this is just
/// enough of a snapshot for `mailbox.dart`'s draft-recap mail to name
/// them for real (2026-08-22, a direct GM ask: "lament the loss of some
/// good bench players to maintain a legal roster").
///
/// [Franchise.draftWaivedPlayers] resets to empty every season transition
/// (`copyWithNewSeason`), same season-scoped posture
/// [Franchise.leagueRetirements] already has -- this is specifically
/// *this* draft's casualties, not a running history.
class DraftWaivedPlayer {
  const DraftWaivedPlayer({required this.name, required this.primaryPosition});

  final String name;
  final Position primaryPosition;
}
