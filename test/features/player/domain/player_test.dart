import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/player/domain/archetype.dart';
import 'package:womensbballmgr/features/player/domain/player.dart';
import 'package:womensbballmgr/features/player/domain/player_ratings.dart';
import 'package:womensbballmgr/features/player/domain/trait.dart';
import 'package:womensbballmgr/features/player/domain/achievement.dart';
import 'package:womensbballmgr/features/portrait/domain/portrait_appearance.dart';
import 'package:womensbballmgr/features/portrait/generation/portrait_generator.dart';

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
      id: 'p1',
      name: 'Riley Okafor',
      age: 24,
      yearsOfService: 2,
      hometown: 'Fictional City',
      primaryPosition: Position.pointGuard,
      handedness: Handedness.right,
      biography: 'A steady floor general.',
      ratings: _ratings,
      heightInches: 73,
      archetype: Archetype.floorGeneral,
    );

    expect(player.name, 'Riley Okafor');
    expect(player.primaryPosition, Position.pointGuard);
    expect(player.secondaryPositions, isEmpty);
    expect(player.archetype, Archetype.floorGeneral);
    expect(player.traits, isEmpty);
  });

  test('allows secondary positions distinct from the primary', () {
    final player = Player(
      id: 'p1',
      name: 'Riley Okafor',
      age: 24,
      yearsOfService: 2,
      hometown: 'Fictional City',
      primaryPosition: Position.pointGuard,
      secondaryPositions: const {Position.shootingGuard},
      handedness: Handedness.right,
      biography: 'A steady floor general.',
      ratings: _ratings,
      heightInches: 73,
      archetype: Archetype.floorGeneral,
    );

    expect(player.secondaryPositions, {Position.shootingGuard});
  });

  test('rejects a secondary position that repeats the primary', () {
    expect(
      () => Player(
        id: 'p1',
        name: 'Riley Okafor',
        age: 24,
        yearsOfService: 2,
        hometown: 'Fictional City',
        primaryPosition: Position.pointGuard,
        secondaryPositions: const {Position.pointGuard},
        handedness: Handedness.right,
        biography: 'A steady floor general.',
        ratings: _ratings,
        heightInches: 73,
        archetype: Archetype.floorGeneral,
      ),
      throwsA(isA<AssertionError>()),
    );
  });

  test('rejects a height outside kMinHeightInches..kMaxHeightInches', () {
    expect(
      () => Player(
        id: 'p1',
        name: 'Riley Okafor',
        age: 24,
        yearsOfService: 2,
        hometown: 'Fictional City',
        primaryPosition: Position.pointGuard,
        handedness: Handedness.right,
        biography: 'A steady floor general.',
        ratings: _ratings,
        heightInches: kMinHeightInches - 1,
        archetype: Archetype.floorGeneral,
      ),
      throwsA(isA<AssertionError>()),
    );
    expect(
      () => Player(
        id: 'p1',
        name: 'Riley Okafor',
        age: 24,
        yearsOfService: 2,
        hometown: 'Fictional City',
        primaryPosition: Position.pointGuard,
        handedness: Handedness.right,
        biography: 'A steady floor general.',
        ratings: _ratings,
        heightInches: kMaxHeightInches + 1,
        archetype: Archetype.floorGeneral,
      ),
      throwsA(isA<AssertionError>()),
    );
  });

  test('rejects a non-positive age', () {
    expect(
      () => Player(
        id: 'p1',
        name: 'Riley Okafor',
        age: 0,
        yearsOfService: 2,
        hometown: 'Fictional City',
        primaryPosition: Position.pointGuard,
        handedness: Handedness.right,
        biography: 'A steady floor general.',
        ratings: _ratings,
        heightInches: 73,
        archetype: Archetype.floorGeneral,
      ),
      throwsA(isA<AssertionError>()),
    );
  });

  test('rejects a negative yearsOfService', () {
    expect(
      () => Player(
        id: 'p1',
        name: 'Riley Okafor',
        age: 24,
        yearsOfService: -1,
        hometown: 'Fictional City',
        primaryPosition: Position.pointGuard,
        handedness: Handedness.right,
        biography: 'A steady floor general.',
        ratings: _ratings,
        heightInches: 73,
        archetype: Archetype.floorGeneral,
      ),
      throwsA(isA<AssertionError>()),
    );
  });

  test('rejects an archetype not valid for the primary position', () {
    expect(
      () => Player(
        id: 'p1',
        name: 'Riley Okafor',
        age: 24,
        yearsOfService: 2,
        hometown: 'Fictional City',
        primaryPosition: Position.pointGuard,
        handedness: Handedness.right,
        biography: 'A steady floor general.',
        ratings: _ratings,
        heightInches: 73,
        archetype: Archetype.rimRunner,
      ),
      throwsA(isA<AssertionError>()),
    );
  });

  test('rejects traits containing both sides of an opposite pair', () {
    expect(
      () => Player(
        id: 'p1',
        name: 'Riley Okafor',
        age: 24,
        yearsOfService: 2,
        hometown: 'Fictional City',
        primaryPosition: Position.pointGuard,
        handedness: Handedness.right,
        biography: 'A steady floor general.',
        ratings: _ratings,
        heightInches: 73,
        archetype: Archetype.floorGeneral,
        traits: const {Trait.leader, Trait.malcontent},
      ),
      throwsA(isA<AssertionError>()),
    );
  });

  test('copyWithAppearance replaces only the appearance', () {
    final player = Player(
      id: 'p1',
      name: 'Riley Okafor',
      age: 24,
      yearsOfService: 2,
      hometown: 'Fictional City',
      primaryPosition: Position.pointGuard,
      handedness: Handedness.right,
      biography: 'A steady floor general.',
      ratings: _ratings,
      heightInches: 73,
      archetype: Archetype.floorGeneral,
      traits: const {Trait.leader},
    );
    const newAppearance = PortraitAppearance(
      baseSprite: kDefaultBaseSprite,
      skinTone: 'deep',
      hairColor: 'black',
      eyes: 'eyes_1center',
      nose: 'nose_1',
      mouth: 'mouth_1',
      isCoach: false,
    );

    final updated = player.copyWithAppearance(newAppearance);

    expect(updated.id, player.id);
    expect(updated.name, player.name);
    expect(updated.archetype, player.archetype);
    expect(updated.traits, player.traits);
    expect(updated.appearance, newAppearance);
  });

  test('defaults achievements to empty and nickname to null', () {
    final player = Player(
      id: 'p1',
      name: 'Riley Okafor',
      age: 24,
      yearsOfService: 2,
      hometown: 'Fictional City',
      primaryPosition: Position.pointGuard,
      handedness: Handedness.right,
      biography: 'A steady floor general.',
      ratings: _ratings,
      heightInches: 73,
      archetype: Archetype.floorGeneral,
    );

    expect(player.achievements, isEmpty);
    expect(player.nickname, isNull);
  });

  test('copyWithNickname replaces only the nickname', () {
    final player = Player(
      id: 'p1',
      name: 'Riley Okafor',
      age: 24,
      yearsOfService: 2,
      hometown: 'Fictional City',
      primaryPosition: Position.pointGuard,
      handedness: Handedness.right,
      biography: 'A steady floor general.',
      ratings: _ratings,
      heightInches: 73,
      archetype: Archetype.floorGeneral,
    );

    final updated = player.copyWithNickname('The Wall');

    expect(updated.nickname, 'The Wall');
    expect(updated.name, player.name);
    expect(updated.achievements, player.achievements);
  });

  test('copyWithAchievement appends without dropping existing ones', () {
    final player = Player(
      id: 'p1',
      name: 'Riley Okafor',
      age: 24,
      yearsOfService: 2,
      hometown: 'Fictional City',
      primaryPosition: Position.pointGuard,
      handedness: Handedness.right,
      biography: 'A steady floor general.',
      ratings: _ratings,
      heightInches: 73,
      archetype: Archetype.floorGeneral,
      achievements: const [
        PlayerAchievementRecord(achievement: Achievement.leagueMvp, season: 0),
      ],
    );

    final updated = player.copyWithAchievement(
      const PlayerAchievementRecord(
        achievement: Achievement.scoringLeader,
        season: 1,
      ),
    );

    expect(updated.achievements, hasLength(2));
    expect(updated.achievements.first.achievement, Achievement.leagueMvp);
    expect(updated.achievements.last.achievement, Achievement.scoringLeader);
    expect(player.achievements, hasLength(1), reason: 'original is untouched');
  });

  test('formatHeightInches formats feet and inches', () {
    expect(formatHeightInches(74), "6'2\"");
    expect(formatHeightInches(72), "6'0\"");
    expect(formatHeightInches(kMinHeightInches), "5'2\"");
    expect(formatHeightInches(kMaxHeightInches), "7'0\"");
  });
}
