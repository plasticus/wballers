import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/trade/domain/pick_ownership.dart';
import 'package:womensbballmgr/features/trade/domain/trade_asset.dart';

void main() {
  group('currentPickOwner', () {
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

  group('transferPickOwnership', () {
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

  group('picksOwnedBy', () {
    const allTeams = ['AAA', 'BBB', 'CCC'];

    test('with no trades, a team owns exactly its own natal picks', () {
      final owned = picksOwnedBy('AAA', const {}, allTeams, rounds: 3);
      expect(owned, hasLength(3));
      expect(
        owned,
        containsAll([
          const PickTradeAsset(round: 1, originalTeamAbbreviation: 'AAA'),
          const PickTradeAsset(round: 2, originalTeamAbbreviation: 'AAA'),
          const PickTradeAsset(round: 3, originalTeamAbbreviation: 'AAA'),
        ]),
      );
    });

    test('a team that traded away its own pick no longer owns it', () {
      final overrides = {
        2: {'AAA': 'BBB'},
      };
      final owned = picksOwnedBy('AAA', overrides, allTeams, rounds: 3);
      expect(
        owned,
        isNot(
          contains(
            const PickTradeAsset(round: 2, originalTeamAbbreviation: 'AAA'),
          ),
        ),
      );
      expect(owned, hasLength(2));
    });

    test(
      'a team that acquired a pick can hold two picks in the same round',
      () {
        final overrides = {
          2: {'CCC': 'AAA'},
        };
        final owned = picksOwnedBy('AAA', overrides, allTeams, rounds: 3);
        expect(
          owned.where((p) => p.round == 2),
          containsAll([
            const PickTradeAsset(round: 2, originalTeamAbbreviation: 'AAA'),
            const PickTradeAsset(round: 2, originalTeamAbbreviation: 'CCC'),
          ]),
        );
        expect(owned, hasLength(4));
      },
    );
  });
}
