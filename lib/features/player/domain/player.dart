import '../../portrait/domain/portrait_appearance.dart';
import 'achievement.dart';
import 'archetype.dart';
import 'college.dart';
import 'player_ratings.dart';
import 'position.dart';
import 'trait.dart';

export 'college.dart';
export 'position.dart';

enum Handedness { left, right }

/// Bounds for [Player.heightInches] -- 5'2" to 7'0", wide enough to cover a
/// generated player at any position (including outliers -- a tall point
/// guard or a shorter center) without producing an implausible height.
const kMinHeightInches = 62;
const kMaxHeightInches = 84;

/// Formats a height in inches as feet'inches" (e.g. `74` -> `6'2"`).
String formatHeightInches(int heightInches) {
  final feet = heightInches ~/ 12;
  final inches = heightInches % 12;
  return "$feet'$inches\"";
}

/// A fictional athlete.
///
/// Deliberately excluded for now, pending systems that don't exist yet:
/// - Status (e.g. healthy/injured): depends on Phase 2's injury system.
/// - Derived capabilities beyond [PlayerRatings.overall] — role fit, lineup
///   chemistry, fatigue/readiness, morale, injury risk, development
///   trajectory — all depend on roster or simulation context, not just
///   this player alone.
/// - Star-tier classification (4-star/3-star/etc.): it's a roster-legality
///   concern, not a player attribute — see `StarTier.of` in the roster
///   feature, which computes it from [PlayerRatings.overall] on demand.
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
    required this.heightInches,
    required this.archetype,
    this.traits = const {},
    this.appearance,
    this.achievements = const [],
    this.nickname,
    this.jerseyNumber,
    this.college,
  }) : assert(age > 0, 'age must be positive'),
       assert(
         jerseyNumber == null || (jerseyNumber >= 0 && jerseyNumber <= 99),
         'jerseyNumber must be within [0, 99]',
       ),
       assert(yearsOfService >= 0, 'yearsOfService must not be negative'),
       assert(
         heightInches >= kMinHeightInches && heightInches <= kMaxHeightInches,
         'heightInches must be within [$kMinHeightInches, $kMaxHeightInches]',
       ),
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
  /// needs to keep pointing at the same player.
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

  /// Standing height in inches. A physical fact, not a 1-99 [ratings]
  /// entry -- see `kMinHeightInches`/`kMaxHeightInches` for its range.
  /// Generated per-position with enough spread to allow real outliers (a
  /// tall point guard, a shorter center), rather than being implied by
  /// [primaryPosition] alone.
  final int heightInches;

  /// This player's position-specific play style (`archetypes.md`). Always
  /// one of [kArchetypesByPosition]'s entries for [primaryPosition].
  final Archetype archetype;

  /// Earned/assigned personality, career, and skill-badge traits
  /// (`traits.md`). Never contains both sides of an opposite pair (e.g.
  /// [Trait.leader] and [Trait.malcontent] together).
  final Set<Trait> traits;

  /// Portrait source data (`portraits.md`); `null` means none has been
  /// generated yet (e.g. `PortraitWeights` wasn't available at creation
  /// time) -- the portrait UI falls back to a generic placeholder rather
  /// than treating this as an error state.
  final PortraitAppearance? appearance;

  /// On-court awards this player has earned (`achievement.dart`) -- empty
  /// until Phase 2's season simulation exists to determine a winner.
  final List<PlayerAchievementRecord> achievements;

  /// Game-suggested nickname, earned through play, that the GM can
  /// override (`FLUTTER_APP_PLAN.md`'s earned identity system). `null`
  /// means none earned. Deliberately *not* a general-purpose rename field
  /// -- a GM can't assign one to an arbitrary player on a whim; it only
  /// becomes settable in response to a real [PlayerAchievementRecord],
  /// which needs Phase 2's season simulation to ever occur. No UI exposes
  /// this yet for exactly that reason.
  final String? nickname;

  /// This player's number on their current team's jersey, 0-99. `null`
  /// until they're actually placed on a roster (`assignJerseyNumbers`,
  /// `roster/generation/`) -- a draft prospect or a player generated
  /// standalone (e.g. in a test) doesn't have one yet, same reasoning as
  /// [nickname] being assigned later rather than at generation time.
  final int? jerseyNumber;

  /// The fictional college this player went to -- `null` means
  /// international rather than "unknown": `generatePlayer` assigns one to
  /// every player generated from a domestic `Country` (USA or Canada,
  /// `CountryLabel.isDomestic`) and leaves this `null` for everyone else,
  /// never both and never neither. `PlayerDetailScreen` uses that mutual
  /// exclusivity directly: show [college] if set, otherwise parse a
  /// country out of [hometown] -- a direct GM ask (2026-08-10, `Aug9bugs.md`
  /// #18) for the page to show "what college they went to, OR if they're
  /// international, the country they're from."
  final College? college;

  /// The surname off of [name] ("Danielle Tran" -> "Tran") -- every
  /// generated name is "First Last" (`player_generator.dart`'s
  /// `kFirstNames`/`kLastNames` pools, no multi-word entries in either),
  /// so splitting on the last space is safe. Used anywhere a compact row
  /// (bench order, box scores) wants just the surname rather than the
  /// full name.
  String get lastName => name.split(' ').last;

  /// Returns a copy with [newAppearance] replacing [appearance] -- the only
  /// field the portrait editor needs to change.
  Player copyWithAppearance(PortraitAppearance newAppearance) {
    return Player(
      id: id,
      name: name,
      age: age,
      yearsOfService: yearsOfService,
      hometown: hometown,
      primaryPosition: primaryPosition,
      secondaryPositions: secondaryPositions,
      handedness: handedness,
      biography: biography,
      ratings: ratings,
      heightInches: heightInches,
      archetype: archetype,
      traits: traits,
      appearance: newAppearance,
      achievements: achievements,
      nickname: nickname,
      jerseyNumber: jerseyNumber,
      college: college,
    );
  }

  /// Returns a copy with [newTraits] replacing [traits] -- used by
  /// `distributeTraits` (`trait_generator.dart`), which assigns traits
  /// across a roster after every player in it already exists.
  Player copyWithTraits(Set<Trait> newTraits) {
    return Player(
      id: id,
      name: name,
      age: age,
      yearsOfService: yearsOfService,
      hometown: hometown,
      primaryPosition: primaryPosition,
      secondaryPositions: secondaryPositions,
      handedness: handedness,
      biography: biography,
      ratings: ratings,
      heightInches: heightInches,
      archetype: archetype,
      traits: newTraits,
      appearance: appearance,
      achievements: achievements,
      nickname: nickname,
      jerseyNumber: jerseyNumber,
      college: college,
    );
  }

  /// Returns a copy with [newNickname] replacing [nickname].
  Player copyWithNickname(String? newNickname) {
    return Player(
      id: id,
      name: name,
      age: age,
      yearsOfService: yearsOfService,
      hometown: hometown,
      primaryPosition: primaryPosition,
      secondaryPositions: secondaryPositions,
      handedness: handedness,
      biography: biography,
      ratings: ratings,
      heightInches: heightInches,
      archetype: archetype,
      traits: traits,
      appearance: appearance,
      achievements: achievements,
      nickname: newNickname,
      jerseyNumber: jerseyNumber,
      college: college,
    );
  }

  /// Returns a copy with [record] appended to [achievements].
  Player copyWithAchievement(PlayerAchievementRecord record) {
    return Player(
      id: id,
      name: name,
      age: age,
      yearsOfService: yearsOfService,
      hometown: hometown,
      primaryPosition: primaryPosition,
      secondaryPositions: secondaryPositions,
      handedness: handedness,
      biography: biography,
      ratings: ratings,
      heightInches: heightInches,
      archetype: archetype,
      traits: traits,
      appearance: appearance,
      achievements: [...achievements, record],
      nickname: nickname,
      jerseyNumber: jerseyNumber,
      college: college,
    );
  }

  /// Returns a copy with [newJerseyNumber] replacing [jerseyNumber] --
  /// used by `assignJerseyNumbers` (`roster/generation/`), which assigns
  /// numbers across a roster after every player in it already exists,
  /// same pattern as [copyWithTraits]/`distributeTraits`. Also how
  /// `current_franchise_provider.dart`'s `dropPlayer` clears a released
  /// player's number (`null`) on the way back to free agency -- no free
  /// agent generated fresh ever has one, and `signFreeAgent` assigns a new
  /// one anyway the moment someone signs them back onto a roster.
  Player copyWithJerseyNumber(int? newJerseyNumber) {
    return Player(
      id: id,
      name: name,
      age: age,
      yearsOfService: yearsOfService,
      hometown: hometown,
      primaryPosition: primaryPosition,
      secondaryPositions: secondaryPositions,
      handedness: handedness,
      biography: biography,
      ratings: ratings,
      heightInches: heightInches,
      archetype: archetype,
      traits: traits,
      appearance: appearance,
      achievements: achievements,
      nickname: nickname,
      jerseyNumber: newJerseyNumber,
      college: college,
    );
  }

  /// Returns a copy with [newRatings] replacing [ratings] -- what training
  /// (`features/training/`) applies each week's growth/decline through.
  Player copyWithRatings(PlayerRatings newRatings) {
    return Player(
      id: id,
      name: name,
      age: age,
      yearsOfService: yearsOfService,
      hometown: hometown,
      primaryPosition: primaryPosition,
      secondaryPositions: secondaryPositions,
      handedness: handedness,
      biography: biography,
      ratings: newRatings,
      heightInches: heightInches,
      archetype: archetype,
      traits: traits,
      appearance: appearance,
      achievements: achievements,
      nickname: nickname,
      jerseyNumber: jerseyNumber,
      college: college,
    );
  }
}
