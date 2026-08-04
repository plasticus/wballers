import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/player/domain/archetype.dart';
import 'package:womensbballmgr/features/player/domain/player.dart';
import 'package:womensbballmgr/features/player/persistence/player_json.dart';

/// A save written before question.md decision 27 (archetype/traits) and
/// decisions 28/30 (appearance/achievements/nickname) -- none of those
/// keys exist. This is the actual shape that broke loading in practice:
/// `playerFromJson` used non-nullable casts on `archetype`/`traits`, so an
/// old save couldn't be loaded at all rather than upgrading gracefully.
Map<String, dynamic> _legacyPlayerJson() {
  return {
    'id': 'p1',
    'name': 'Riley Okafor',
    'age': 24,
    'yearsOfService': 2,
    'hometown': 'Fictional City',
    'primaryPosition': 'pointGuard',
    'secondaryPositions': <String>[],
    'handedness': 'right',
    'biography': 'A steady floor general.',
    'ratings': {
      'speed': 50,
      'agility': 50,
      'strength': 50,
      'stamina': 50,
      'ballControl': 50,
      'passing': 50,
      'interiorOffense': 50,
      'perimeterOffense': 50,
      'perimeterDefense': 50,
      'interiorDefense': 50,
      'disruption': 50,
      'blocking': 50,
      'potential': 50,
    },
  };
}

void main() {
  test('playerFromJson loads a pre-archetype/traits save without throwing', () {
    final player = playerFromJson(_legacyPlayerJson());

    expect(player.id, 'p1');
    expect(player.name, 'Riley Okafor');
  });

  test('a legacy save falls back to a position-legal default archetype', () {
    final player = playerFromJson(_legacyPlayerJson());

    expect(
      kArchetypesByPosition[Position.pointGuard],
      contains(player.archetype),
    );
  });

  test('a legacy save falls back to no traits', () {
    final player = playerFromJson(_legacyPlayerJson());

    expect(player.traits, isEmpty);
  });

  test(
    'a legacy save falls back to no appearance, achievements, or nickname',
    () {
      final player = playerFromJson(_legacyPlayerJson());

      expect(player.appearance, isNull);
      expect(player.achievements, isEmpty);
      expect(player.nickname, isNull);
    },
  );

  test(
    'a save with an explicit archetype/traits still uses them, not the fallback',
    () {
      final json = _legacyPlayerJson()
        ..['archetype'] = 'pointGod'
        ..['traits'] = ['leader'];

      final player = playerFromJson(json);

      expect(player.archetype, Archetype.pointGod);
      expect(player.traits, isNotEmpty);
    },
  );
}
