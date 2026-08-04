import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/player/domain/player.dart';
import 'package:womensbballmgr/features/player/domain/player_ratings.dart';

const _ratings = PlayerRatings(
  speed: 50,
  agility: 50,
  strength: 50,
  stamina: 50,
  ballControl: 50,
  passing: 50,
  interiorOffense: 50,
  perimeterOffense: 50,
  perimeterDefense: 50,
  interiorDefense: 50,
  disruption: 50,
  blocking: 50,
  potential: 50,
);

void main() {
  test('stores identity fields and defaults to no secondary positions', () {
    final player = Player(
      name: 'Riley Okafor',
      age: 24,
      hometown: 'Fictional City',
      primaryPosition: Position.pointGuard,
      handedness: Handedness.right,
      biography: 'A steady floor general.',
      ratings: _ratings,
    );

    expect(player.name, 'Riley Okafor');
    expect(player.primaryPosition, Position.pointGuard);
    expect(player.secondaryPositions, isEmpty);
  });

  test('allows secondary positions distinct from the primary', () {
    final player = Player(
      name: 'Riley Okafor',
      age: 24,
      hometown: 'Fictional City',
      primaryPosition: Position.pointGuard,
      secondaryPositions: const {Position.shootingGuard},
      handedness: Handedness.right,
      biography: 'A steady floor general.',
      ratings: _ratings,
    );

    expect(player.secondaryPositions, {Position.shootingGuard});
  });

  test('rejects a secondary position that repeats the primary', () {
    expect(
      () => Player(
        name: 'Riley Okafor',
        age: 24,
        hometown: 'Fictional City',
        primaryPosition: Position.pointGuard,
        secondaryPositions: const {Position.pointGuard},
        handedness: Handedness.right,
        biography: 'A steady floor general.',
        ratings: _ratings,
      ),
      throwsA(isA<AssertionError>()),
    );
  });

  test('rejects a non-positive age', () {
    expect(
      () => Player(
        name: 'Riley Okafor',
        age: 0,
        hometown: 'Fictional City',
        primaryPosition: Position.pointGuard,
        handedness: Handedness.right,
        biography: 'A steady floor general.',
        ratings: _ratings,
      ),
      throwsA(isA<AssertionError>()),
    );
  });
}
