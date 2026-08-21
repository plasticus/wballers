import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/trade/domain/pick_ownership.dart';
import 'package:womensbballmgr/features/trade/domain/trade_asset.dart';

void main() {
  group('tradeableDraftSeasons', () {
    test('is the next draft plus one more out, matching '
        'kTradeablePickHorizonSeasons', () {
      expect(tradeableDraftSeasons(0), [1, 2]);
      expect(tradeableDraftSeasons(4), [5, 6]);
    });
  });

  group('currentPickOwner (one draft)', () {
    test('an untraded pick belongs to its own natal team', () {
      expect(currentPickOwner(const {}, 2, 'AAA'), 'AAA');
    });

    test('a traded pick resolves to its current owner', () {
      final overrides = {
        2: {'AAA': 'BBB'},
      };
      expect(currentPickOwner(overrides, 2, 'AAA'), 'BBB');
    });

    test('an override on one round never leaks into another', () {
      final overrides = {
        2: {'AAA': 'BBB'},
      };
      expect(currentPickOwner(overrides, 1, 'AAA'), 'AAA');
    });
  });

  group('transferPickOwnership (one draft)', () {
    test('records a new owner for a previously-untraded pick', () {
      final updated = transferPickOwnership(
        const {},
        round: 1,
        originalTeamAbbreviation: 'AAA',
        newOwnerAbbreviation: 'BBB',
      );
      expect(currentPickOwner(updated, 1, 'AAA'), 'BBB');
    });

    test('a pick can be traded again after already being traded once', () {
      final onceTraded = transferPickOwnership(
        const {},
        round: 1,
        originalTeamAbbreviation: 'AAA',
        newOwnerAbbreviation: 'BBB',
      );
      final twiceTraded = transferPickOwnership(
        onceTraded,
        round: 1,
        originalTeamAbbreviation: 'AAA',
        newOwnerAbbreviation: 'CCC',
      );
      expect(currentPickOwner(twiceTraded, 1, 'AAA'), 'CCC');
    });

    test('trading a pick back to its own natal owner removes the override '
        'entirely, rather than recording a redundant same-team entry', () {
      final traded = transferPickOwnership(
        const {},
        round: 1,
        originalTeamAbbreviation: 'AAA',
        newOwnerAbbreviation: 'BBB',
      );
      final tradedBack = transferPickOwnership(
        traded,
        round: 1,
        originalTeamAbbreviation: 'AAA',
        newOwnerAbbreviation: 'AAA',
      );
      expect(tradedBack, const <int, Map<String, String>>{});
    });

    test('leaves every other round\'s overrides untouched', () {
      final overrides = {
        1: {'AAA': 'BBB'},
        2: {'CCC': 'DDD'},
      };
      final updated = transferPickOwnership(
        overrides,
        round: 1,
        originalTeamAbbreviation: 'AAA',
        newOwnerAbbreviation: 'EEE',
      );
      expect(currentPickOwner(updated, 2, 'CCC'), 'DDD');
    });
  });

  group(
    'currentFuturePickOwner / transferFuturePickOwnership (multi-season)',
    () {
      test('an untraded pick belongs to its own natal team, any season', () {
        expect(
          currentFuturePickOwner(
            const {},
            draftSeason: 3,
            round: 1,
            originalTeamAbbreviation: 'AAA',
          ),
          'AAA',
        );
      });

      test('a transfer only applies to its own draft season', () {
        final updated = transferFuturePickOwnership(
          const {},
          draftSeason: 2,
          round: 1,
          originalTeamAbbreviation: 'AAA',
          newOwnerAbbreviation: 'BBB',
        );
        expect(
          currentFuturePickOwner(
            updated,
            draftSeason: 2,
            round: 1,
            originalTeamAbbreviation: 'AAA',
          ),
          'BBB',
        );
        // Season 3's copy of the same round/team pick is untouched.
        expect(
          currentFuturePickOwner(
            updated,
            draftSeason: 3,
            round: 1,
            originalTeamAbbreviation: 'AAA',
          ),
          'AAA',
        );
      });

      test('a pick can trade hands more than once, across different calls', () {
        final onceTraded = transferFuturePickOwnership(
          const {},
          draftSeason: 2,
          round: 1,
          originalTeamAbbreviation: 'AAA',
          newOwnerAbbreviation: 'BBB',
        );
        final twiceTraded = transferFuturePickOwnership(
          onceTraded,
          draftSeason: 2,
          round: 1,
          originalTeamAbbreviation: 'AAA',
          newOwnerAbbreviation: 'CCC',
        );
        expect(
          currentFuturePickOwner(
            twiceTraded,
            draftSeason: 2,
            round: 1,
            originalTeamAbbreviation: 'AAA',
          ),
          'CCC',
        );
      });

      test('trading a pick back to its natal owner removes that season\'s '
          'entry entirely once nothing else in it is traded', () {
        final traded = transferFuturePickOwnership(
          const {},
          draftSeason: 2,
          round: 1,
          originalTeamAbbreviation: 'AAA',
          newOwnerAbbreviation: 'BBB',
        );
        final tradedBack = transferFuturePickOwnership(
          traded,
          draftSeason: 2,
          round: 1,
          originalTeamAbbreviation: 'AAA',
          newOwnerAbbreviation: 'AAA',
        );
        expect(tradedBack, isEmpty);
      });
    },
  );

  group('picksOwnedBy', () {
    const allTeams = ['AAA', 'BBB', 'CCC'];

    test('with no trades, a team owns exactly its own natal picks, across '
        'every tradeable draft season', () {
      final owned = picksOwnedBy(
        'AAA',
        const {},
        allTeams,
        draftSeasons: [1, 2],
        rounds: 3,
      );
      expect(owned, hasLength(6)); // 2 seasons x 3 rounds
      expect(
        owned,
        containsAll([
          const PickTradeAsset(
            draftSeason: 1,
            round: 1,
            originalTeamAbbreviation: 'AAA',
          ),
          const PickTradeAsset(
            draftSeason: 2,
            round: 1,
            originalTeamAbbreviation: 'AAA',
          ),
        ]),
      );
    });

    test('a team that traded away one season\'s pick still owns the other '
        'season\'s copy of the same round', () {
      final overrides = {
        2: {
          1: {'AAA': 'BBB'},
        },
      };
      final owned = picksOwnedBy(
        'AAA',
        overrides,
        allTeams,
        draftSeasons: [1, 2],
        rounds: 3,
      );
      expect(
        owned,
        contains(
          const PickTradeAsset(
            draftSeason: 1,
            round: 1,
            originalTeamAbbreviation: 'AAA',
          ),
        ),
      );
      expect(
        owned,
        isNot(
          contains(
            const PickTradeAsset(
              draftSeason: 2,
              round: 1,
              originalTeamAbbreviation: 'AAA',
            ),
          ),
        ),
      );
    });

    test('a team that acquired a pick can hold two picks in the same round '
        'and season', () {
      final overrides = {
        2: {
          2: {'CCC': 'AAA'},
        },
      };
      final owned = picksOwnedBy(
        'AAA',
        overrides,
        allTeams,
        draftSeasons: [2],
        rounds: 3,
      );
      expect(
        owned,
        containsAll([
          const PickTradeAsset(
            draftSeason: 2,
            round: 2,
            originalTeamAbbreviation: 'AAA',
          ),
          const PickTradeAsset(
            draftSeason: 2,
            round: 2,
            originalTeamAbbreviation: 'CCC',
          ),
        ]),
      );
    });
  });

  group('pickHorizonLabel', () {
    test('names the real season outright, not "next draft"/relative '
        'wording (2026-08-21, a direct GM ask)', () {
      expect(pickHorizonLabel(3, 2), 'Season 4');
      expect(pickHorizonLabel(4, 2), 'Season 5');
    });
  });
}
