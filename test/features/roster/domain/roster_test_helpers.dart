import 'package:womensbballmgr/features/player/domain/archetype.dart';
import 'package:womensbballmgr/features/player/domain/player.dart';
import 'package:womensbballmgr/features/player/domain/player_ratings.dart';
import 'package:womensbballmgr/features/player/domain/trait.dart';

int _playerIdCounter = 0;

/// A player whose twelve stored ratings are all [overall], so
/// `ratings.overall` equals exactly [overall] (their unweighted average).
/// Gets a unique [id] by default; pass one explicitly when a test needs to
/// reference a specific player's id (e.g. building a `StartingLineup`).
/// Defaults [archetype] to the first option valid for [primaryPosition]
/// when not given, and [traits] to none.
Player playerWithOverall(
  int overall, {
  String name = 'Test Player',
  String? id,
  int age = 24,
  int yearsOfService = 5,
  Position primaryPosition = Position.pointGuard,
  Set<Position> secondaryPositions = const {},
  Archetype? archetype,
  Set<Trait> traits = const {},
}) {
  return Player(
    id: id ?? 'test-player-${_playerIdCounter++}',
    name: name,
    age: age,
    yearsOfService: yearsOfService,
    hometown: 'Fictional City',
    primaryPosition: primaryPosition,
    secondaryPositions: secondaryPositions,
    handedness: Handedness.right,
    biography: '',
    archetype: archetype ?? kArchetypesByPosition[primaryPosition]!.first,
    traits: traits,
    ratings: PlayerRatings(
      speed: overall,
      agility: overall,
      strength: overall,
      stamina: overall,
      ballControl: overall,
      passing: overall,
      interiorOffense: overall,
      perimeterOffense: overall,
      perimeterDefense: overall,
      interiorDefense: overall,
      disruption: overall,
      blocking: overall,
      potential: overall,
    ),
  );
}
