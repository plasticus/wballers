import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/trade/domain/trade_asset.dart';

void main() {
  group('PickTradeAsset', () {
    test('tradeValue comes from the flat round ladder, regardless of '
        'draftSeason or originalTeamAbbreviation', () {
      const pick = PickTradeAsset(
        draftSeason: 1,
        round: 1,
        originalTeamAbbreviation: 'AAA',
      );
      expect(pick.tradeValue, 290);
      const sameRoundLaterSeason = PickTradeAsset(
        draftSeason: 2,
        round: 1,
        originalTeamAbbreviation: 'AAA',
      );
      expect(sameRoundLaterSeason.tradeValue, pick.tradeValue);
    });

    test('label names whose natal pick it is', () {
      expect(
        const PickTradeAsset(
          draftSeason: 1,
          round: 2,
          originalTeamAbbreviation: 'PHX',
        ).label,
        contains('PHX'),
      );
      expect(
        const PickTradeAsset(
          draftSeason: 1,
          round: 3,
          originalTeamAbbreviation: 'PHX',
        ).label,
        contains('3rd'),
      );
    });

    test('equality is by draftSeason, round, and originalTeamAbbreviation '
        'together', () {
      expect(
        const PickTradeAsset(
          draftSeason: 1,
          round: 1,
          originalTeamAbbreviation: 'AAA',
        ),
        const PickTradeAsset(
          draftSeason: 1,
          round: 1,
          originalTeamAbbreviation: 'AAA',
        ),
      );
      expect(
        const PickTradeAsset(
              draftSeason: 1,
              round: 1,
              originalTeamAbbreviation: 'AAA',
            ) ==
            const PickTradeAsset(
              draftSeason: 2,
              round: 1,
              originalTeamAbbreviation: 'AAA',
            ),
        isFalse,
      );
      expect(
        const PickTradeAsset(
              draftSeason: 1,
              round: 1,
              originalTeamAbbreviation: 'AAA',
            ) ==
            const PickTradeAsset(
              draftSeason: 1,
              round: 2,
              originalTeamAbbreviation: 'AAA',
            ),
        isFalse,
      );
      expect(
        const PickTradeAsset(
              draftSeason: 1,
              round: 1,
              originalTeamAbbreviation: 'AAA',
            ) ==
            const PickTradeAsset(
              draftSeason: 1,
              round: 1,
              originalTeamAbbreviation: 'BBB',
            ),
        isFalse,
      );
    });
  });
}
