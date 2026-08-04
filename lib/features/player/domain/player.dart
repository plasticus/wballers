import 'player_ratings.dart';

enum Position { pointGuard, shootingGuard, smallForward, powerForward, center }

enum Handedness { left, right }

/// A fictional athlete.
///
/// Deliberately excluded for now, pending systems that don't exist yet:
/// - Personality/archetype: no defined taxonomy yet.
/// - Status (e.g. healthy/injured): depends on Phase 2's injury system.
/// - Derived capabilities beyond [PlayerRatings.overall] — role fit, lineup
///   chemistry, fatigue/readiness, morale, injury risk, development
///   trajectory — all depend on roster or simulation context, not just
///   this player alone.
/// - Star-tier classification (5-star/4-star/etc., see `star_system.md`):
///   it's a roster-legality concern, computed from [PlayerRatings.overall]
///   once the roster system that enforces it exists.
/// - Portrait appearance: the Flutter asset pipeline that would back it is
///   Phase 1.5 work (same reasoning as `Coach`).
class Player {
  Player({
    required this.name,
    required this.age,
    required this.hometown,
    required this.primaryPosition,
    this.secondaryPositions = const {},
    required this.handedness,
    required this.biography,
    required this.ratings,
  }) : assert(age > 0, 'age must be positive'),
       assert(
         !secondaryPositions.contains(primaryPosition),
         'secondaryPositions must not repeat primaryPosition',
       );

  final String name;
  final int age;
  final String hometown;
  final Position primaryPosition;

  /// Additional positions this player can credibly play, for depth-chart
  /// flexibility. Never contains [primaryPosition] itself.
  final Set<Position> secondaryPositions;

  final Handedness handedness;
  final String biography;
  final PlayerRatings ratings;
}
