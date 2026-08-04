import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/player/domain/player.dart';
import 'package:womensbballmgr/features/player/domain/player_ratings.dart';

const _ratings = PlayerRatings(
  inside: 50,
  outside: 50,
  playmaking: 50,
  ballHandling: 50,
  defense: 50,
  rebounding: 50,
  athleticism: 50,
  stamina: 50,
  discipline: 50,
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
