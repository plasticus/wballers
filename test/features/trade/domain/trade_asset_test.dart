import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/trade/domain/trade_asset.dart';

void main() {
  group('PickTradeAsset', () {
    test('tradeValue comes from the flat round ladder, regardless of '
        'originalTeamAbbreviation', () {
      const pick = PickTradeAsset(round: 1, originalTeamAbbreviation: 'AAA');
      expect(pick.tradeValue, 290);
    });

    test('label names whose natal pick it is', () {
      expect(
        const PickTradeAsset(round: 2, originalTeamAbbreviation: 'PHX').label,
        contains('PHX'),
      );
      expect(
        const PickTradeAsset(round: 3, originalTeamAbbreviation: 'PHX').label,
        contains('3rd'),
      );
    });

    test('equality is by round and originalTeamAbbreviation together', () {
      expect(
        const PickTradeAsset(round: 1, originalTeamAbbreviation: 'AAA'),
        const PickTradeAsset(round: 1, originalTeamAbbreviation: 'AAA'),
      );
      expect(
        const PickTradeAsset(round: 1, originalTeamAbbreviation: 'AAA') ==
            const PickTradeAsset(round: 2, originalTeamAbbreviation: 'AAA'),
        isFalse,
      );
      expect(
        const PickTradeAsset(round: 1, originalTeamAbbreviation: 'AAA') ==
            const PickTradeAsset(round: 1, originalTeamAbbreviation: 'BBB'),
        isFalse,
      );
    });
  });
}
