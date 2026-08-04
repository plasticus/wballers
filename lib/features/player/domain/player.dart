import 'archetype.dart';
import 'player_ratings.dart';
import 'position.dart';
import 'trait.dart';

export 'position.dart';

enum Handedness { left, right }

/// A fictional athlete.
///
/// Deliberately excluded for now, pending systems that don't exist yet:
/// - Status (e.g. healthy/injured): depends on Phase 2's injury system.
/// - Derived capabilities beyond [PlayerRatings.overall] — role fit, lineup
///   chemistry, fatigue/readiness, morale, injury risk, development
///   trajectory — all depend on roster or simulation context, not just
///   this player alone.
/// - Star-tier classification (5-star/4-star/etc.): it's a roster-legality
///   concern, not a player attribute — see `StarTier.of` in the roster
///   feature, which computes it from [PlayerRatings.overall] on demand.
/// - Portrait appearance: the Flutter asset pipeline that would back it is
///   Phase 1.5 work (same reasoning as `Coach`).
/// - Roster placement (active/developmental/reserve): a roster-membership
///   concern, not a player attribute — see `RosterStatus` in the roster
///   feature. [yearsOfService] lives here because it's intrinsic to the
///   player (age doesn't imply it — international rookies can enter the
///   league well into their late twenties), but whether that qualifies
///   them for a developmental slot is evaluated by the roster feature.
class Player {
  Player({
    required this.id,
    required this.name,
    required this.age,
    required this.yearsOfService,
    required this.hometown,
    required this.primaryPosition,
    this.secondaryPositions = const {},
    required this.handedness,
    required this.biography,
    required this.ratings,
    required this.archetype,
    this.traits = const {},
  }) : assert(age > 0, 'age must be positive'),
       assert(yearsOfService >= 0, 'yearsOfService must not be negative'),
       assert(
         !secondaryPositions.contains(primaryPosition),
         'secondaryPositions must not repeat primaryPosition',
       ),
       assert(
         isArchetypeValidForPosition(archetype, primaryPosition),
         'archetype must be valid for primaryPosition',
       ),
       assert(
         traits.every((trait) {
           final opposite = oppositeOf(trait);
           return opposite == null || !traits.contains(opposite);
         }),
         'traits must not contain both sides of an opposite pair',
       );

  /// Stable identifier, independent of object identity or roster list
  /// position -- both are lost across a save/reload, but a lineup slot
  /// (`StartingLineup`, roster feature) needs to keep pointing at the same
  /// player.
  final String id;

  final String name;
  final int age;

  /// Years played in the league. Not derived from [age] — a rookie can
  /// enter the league at almost any age (e.g. an international veteran
  /// making their league debut at 28), so this is tracked independently.
  final int yearsOfService;

  final String hometown;
  final Position primaryPosition;

  /// Additional positions this player can credibly play, for depth-chart
  /// flexibility. Never contains [primaryPosition] itself.
  final Set<Position> secondaryPositions;

  final Handedness handedness;
  final String biography;
  final PlayerRatings ratings;

  /// This player's position-specific play style (`archetypes.md`). Always
  /// one of [kArchetypesByPosition]'s entries for [primaryPosition].
  final Archetype archetype;

  /// Earned/assigned personality, career, and skill-badge traits
  /// (`traits.md`). Never contains both sides of an opposite pair (e.g.
  /// [Trait.leader] and [Trait.malcontent] together).
  final Set<Trait> traits;
}
