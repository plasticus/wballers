import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/training/domain/player_rating_field.dart';
import 'package:womensbballmgr/features/training/domain/training_report.dart';

PlayerGrowthResult _result({
  required String playerId,
  required Map<PlayerRatingField, int> fieldDeltas,
  required int overallBefore,
  required int overallAfter,
}) {
  return PlayerGrowthResult(
    playerId: playerId,
    fieldDeltas: fieldDeltas,
    overallBefore: overallBefore,
    overallAfter: overallAfter,
  );
}

void main() {
  group('aggregateSeasonGrowth', () {
    test('sums field deltas for the same player across multiple weekly '
        'reports', () {
      final reports = [
        TrainingReport(
          week: 2,
          results: [
            _result(
              playerId: 'p1',
              fieldDeltas: {PlayerRatingField.speed: 1},
              overallBefore: 50,
              overallAfter: 51,
            ),
          ],
        ),
        TrainingReport(
          week: 3,
          results: [
            _result(
              playerId: 'p1',
              fieldDeltas: {PlayerRatingField.speed: 2},
              overallBefore: 51,
              overallAfter: 53,
            ),
          ],
        ),
      ];

      final aggregated = aggregateSeasonGrowth(
        weeklyReports: reports,
        seasonEndAging: const [],
      );

      expect(aggregated, hasLength(1));
      expect(aggregated.single.playerId, 'p1');
      expect(aggregated.single.fieldDeltas[PlayerRatingField.speed], 3);
    });

    test('overallBefore comes from the first appearance, overallAfter from '
        'the last -- including the season-end lump if it touched them', () {
      final reports = [
        TrainingReport(
          week: 2,
          results: [
            _result(
              playerId: 'p1',
              fieldDeltas: {PlayerRatingField.speed: 1},
              overallBefore: 50,
              overallAfter: 51,
            ),
          ],
        ),
        TrainingReport(
          week: 5,
          results: [
            _result(
              playerId: 'p1',
              fieldDeltas: {PlayerRatingField.speed: 1},
              overallBefore: 51,
              overallAfter: 52,
            ),
          ],
        ),
      ];
      final seasonEndAging = [
        _result(
          playerId: 'p1',
          fieldDeltas: {PlayerRatingField.speed: -3},
          overallBefore: 52,
          overallAfter: 49,
        ),
      ];

      final aggregated = aggregateSeasonGrowth(
        weeklyReports: reports,
        seasonEndAging: seasonEndAging,
      );

      expect(aggregated.single.overallBefore, 50);
      expect(aggregated.single.overallAfter, 49);
      expect(aggregated.single.fieldDeltas[PlayerRatingField.speed], -1);
    });

    test('different fields for the same player all carry through '
        'independently', () {
      final reports = [
        TrainingReport(
          week: 2,
          results: [
            _result(
              playerId: 'p1',
              fieldDeltas: {
                PlayerRatingField.speed: 1,
                PlayerRatingField.passing: -1,
              },
              overallBefore: 50,
              overallAfter: 50,
            ),
          ],
        ),
      ];

      final aggregated = aggregateSeasonGrowth(
        weeklyReports: reports,
        seasonEndAging: const [],
      );

      expect(aggregated.single.fieldDeltas[PlayerRatingField.speed], 1);
      expect(aggregated.single.fieldDeltas[PlayerRatingField.passing], -1);
    });

    test('multiple players each get their own entry', () {
      final reports = [
        TrainingReport(
          week: 2,
          results: [
            _result(
              playerId: 'p1',
              fieldDeltas: {PlayerRatingField.speed: 1},
              overallBefore: 50,
              overallAfter: 51,
            ),
            _result(
              playerId: 'p2',
              fieldDeltas: {PlayerRatingField.strength: -1},
              overallBefore: 60,
              overallAfter: 59,
            ),
          ],
        ),
      ];

      final aggregated = aggregateSeasonGrowth(
        weeklyReports: reports,
        seasonEndAging: const [],
      );

      expect(aggregated.map((r) => r.playerId), containsAll(['p1', 'p2']));
    });

    test('a player only touched by the season-end lump still gets an '
        'entry', () {
      final seasonEndAging = [
        _result(
          playerId: 'p1',
          fieldDeltas: {PlayerRatingField.speed: -2},
          overallBefore: 70,
          overallAfter: 68,
        ),
      ];

      final aggregated = aggregateSeasonGrowth(
        weeklyReports: const [],
        seasonEndAging: seasonEndAging,
      );

      expect(aggregated, hasLength(1));
      expect(aggregated.single.overallBefore, 70);
      expect(aggregated.single.overallAfter, 68);
    });

    test('empty input produces an empty result', () {
      expect(
        aggregateSeasonGrowth(
          weeklyReports: const [],
          seasonEndAging: const [],
        ),
        isEmpty,
      );
    });
  });
}
