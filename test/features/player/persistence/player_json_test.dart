import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/player/domain/archetype.dart';
import 'package:womensbballmgr/features/player/domain/draft_record.dart';
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
    'heightInches': 73,
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

  test('a legacy save falls back to no appearance, achievements, nickname, '
      'jersey number, or college', () {
    final player = playerFromJson(_legacyPlayerJson());

    expect(player.appearance, isNull);
    expect(player.achievements, isEmpty);
    expect(player.nickname, isNull);
    expect(player.jerseyNumber, isNull);
    expect(player.college, isNull);
  });

  test('a legacy save (predating draftRecord) falls back to null -- never '
      'drafted', () {
    final player = playerFromJson(_legacyPlayerJson());

    expect(player.draftRecord, isNull);
  });

  test('playerToJson/playerFromJson round-trips draftRecord (2026-08-19, a '
      'direct GM ask: "we should see what season, round, and pick they '
      'were drafted")', () {
    final player = playerFromJson(_legacyPlayerJson()).copyWithDraftRecord(
      const PlayerDraftRecord(season: 2, round: 3, pickNumber: 47),
    );

    final roundTripped = playerFromJson(playerToJson(player));

    expect(roundTripped.draftRecord?.season, 2);
    expect(roundTripped.draftRecord?.round, 3);
    expect(roundTripped.draftRecord?.pickNumber, 47);
  });

  test('a legacy save (predating peakOverall) falls back to null, reading as '
      'the current overall via effectivePeakOverall', () {
    final player = playerFromJson(_legacyPlayerJson());

    expect(player.peakOverall, isNull);
    expect(player.effectivePeakOverall, player.ratings.overall);
  });

  test('playerToJson/playerFromJson round-trips peakOverall', () {
    final player = playerFromJson(_legacyPlayerJson()).copyWithSeasonAdvanced();

    final roundTripped = playerFromJson(playerToJson(player));

    expect(roundTripped.peakOverall, player.peakOverall);
  });

  test('playerToJson/playerFromJson round-trips a college by abbreviation', () {
    final player = playerFromJson(_legacyPlayerJson());
    final withCollege = Player(
      id: player.id,
      name: player.name,
      age: player.age,
      yearsOfService: player.yearsOfService,
      hometown: player.hometown,
      primaryPosition: player.primaryPosition,
      handedness: player.handedness,
      biography: player.biography,
      ratings: player.ratings,
      heightInches: player.heightInches,
      archetype: player.archetype,
      college: kColleges.first,
    );

    final roundTripped = playerFromJson(playerToJson(withCollege));

    expect(roundTripped.college?.abbreviation, kColleges.first.abbreviation);
  });

  test('playerToJson/playerFromJson round-trips a jersey number', () {
    final player = playerFromJson(_legacyPlayerJson()).copyWithJerseyNumber(23);

    final roundTripped = playerFromJson(playerToJson(player));

    expect(roundTripped.jerseyNumber, 23);
  });

  test(
    'a save with an explicit archetype/traits still uses them, not the fallback',
    () {
      final json = _legacyPlayerJson()
        ..['archetype'] = 'comboGuard'
        ..['traits'] = ['leader'];

      final player = playerFromJson(json);

      expect(player.archetype, Archetype.comboGuard);
      expect(player.traits, isNotEmpty);
    },
  );
}
