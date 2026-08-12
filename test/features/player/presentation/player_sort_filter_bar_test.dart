import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/player/domain/archetype.dart';
import 'package:womensbballmgr/features/player/domain/player.dart';
import 'package:womensbballmgr/features/player/domain/player_ratings.dart';
import 'package:womensbballmgr/features/player/presentation/player_sort_filter_bar.dart';

/// Unlike `roster_test_helpers.dart`'s `playerWithOverall`, [overall] and
/// [potential] are independently controllable -- these tests need to tell
/// the two sort keys apart, which a player with `potential == overall`
/// can't do.
Player _player({
  required String id,
  required String name,
  required int overall,
  required int potential,
  int age = 24,
  Position position = Position.pointGuard,
}) {
  return Player(
    id: id,
    name: name,
    age: age,
    yearsOfService: 3,
    hometown: 'Fictional City',
    primaryPosition: position,
    secondaryPositions: const {},
    handedness: Handedness.right,
    biography: '',
    heightInches: 73,
    archetype: kArchetypesByPosition[position]!.first,
    traits: const {},
    achievements: const [],
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
      potential: potential,
    ),
  );
}

void main() {
  group('sortAndFilterPlayers (2026-08-11, a direct GM ask: "I need to be '
      'able to sort by all the stuff, or filter. Like filter for '
      'position, then sort by potential, that kind of thing")', () {
    final guard = _player(
      id: 'g',
      name: 'Guard',
      overall: 60,
      potential: 90,
      age: 22,
      position: Position.pointGuard,
    );
    final center = _player(
      id: 'c',
      name: 'Center',
      overall: 80,
      potential: 70,
      age: 30,
      position: Position.center,
    );
    final forward = _player(
      id: 'f',
      name: 'Forward',
      overall: 70,
      potential: 80,
      age: 26,
      position: Position.smallForward,
    );
    final players = [guard, center, forward];

    test('null position keeps every player, sorted by the given key', () {
      final byOverallDesc = sortAndFilterPlayers(
        players,
        (p) => p,
        position: null,
        sortKey: PlayerSortKey.overall,
        descending: true,
      );
      expect(byOverallDesc.map((p) => p.id), ['c', 'f', 'g']);

      final byPotentialDesc = sortAndFilterPlayers(
        players,
        (p) => p,
        position: null,
        sortKey: PlayerSortKey.potential,
        descending: true,
      );
      expect(byPotentialDesc.map((p) => p.id), ['g', 'f', 'c']);
    });

    test('a real position narrows to just that position', () {
      final onlyCenters = sortAndFilterPlayers(
        players,
        (p) => p,
        position: Position.center,
        sortKey: PlayerSortKey.overall,
        descending: true,
      );
      expect(onlyCenters.map((p) => p.id), ['c']);
    });

    test('a position with no matches returns an empty list', () {
      final noShootingGuards = sortAndFilterPlayers(
        players,
        (p) => p,
        position: Position.shootingGuard,
        sortKey: PlayerSortKey.overall,
        descending: true,
      );
      expect(noShootingGuards, isEmpty);
    });

    test('age and name sort ascending when descending is false', () {
      final byAgeAsc = sortAndFilterPlayers(
        players,
        (p) => p,
        position: null,
        sortKey: PlayerSortKey.age,
        descending: false,
      );
      expect(byAgeAsc.map((p) => p.id), ['g', 'f', 'c']);

      final byNameAsc = sortAndFilterPlayers(
        players,
        (p) => p,
        position: null,
        sortKey: PlayerSortKey.name,
        descending: false,
      );
      expect(byNameAsc.map((p) => p.id), ['c', 'f', 'g']);
    });

    test('works through an indirection, not just a bare Player list -- the '
        'same shape `DraftDayScreen` calls it with for `DraftProspect`', () {
      final wrapped = players.map((p) => (player: p, extra: p.id)).toList();
      final sorted = sortAndFilterPlayers(
        wrapped,
        (item) => item.player,
        position: null,
        sortKey: PlayerSortKey.overall,
        descending: true,
      );
      expect(sorted.map((item) => item.extra), ['c', 'f', 'g']);
    });
  });

  group('PlayerSortKeyDefaultDirection', () {
    test('numeric keys default to descending (best-first), Age and Name '
        'default to ascending', () {
      expect(PlayerSortKey.overall.defaultDescending, isTrue);
      expect(PlayerSortKey.potential.defaultDescending, isTrue);
      expect(PlayerSortKey.age.defaultDescending, isFalse);
      expect(PlayerSortKey.name.defaultDescending, isFalse);
    });
  });
}
