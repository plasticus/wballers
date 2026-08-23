import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/player/domain/archetype.dart';
import 'package:womensbballmgr/features/player/domain/player.dart';
import 'package:womensbballmgr/features/player/domain/player_ratings.dart';
import 'package:womensbballmgr/features/trade/domain/trade_asset.dart';
import 'package:womensbballmgr/features/trade/domain/trade_value.dart';

Player _player({
  required int overall,
  required int potential,
  required int age,
}) {
  return Player(
    id: 'p-$overall-$potential-$age',
    name: 'Test Player',
    age: age,
    yearsOfService: 3,
    hometown: 'Testville',
    primaryPosition: Position.smallForward,
    handedness: Handedness.right,
    biography: '',
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
    heightInches: 70,
    archetype: kArchetypesByPosition[Position.smallForward]!.first,
  );
}

void main() {
  group('PlayerTradeAsset', () {
    test('tradeValue routes through playerTradeValue -- not raw '
        'skillPoints -- so potential/age genuinely move it', () {
      // Same current overall/skillPoints, but the young high-potential
      // one should be worth more once potential is credited.
      final grizzledVet = PlayerTradeAsset(
        _player(overall: 75, potential: 76, age: 33),
      );
      final risingProspect = PlayerTradeAsset(
        _player(overall: 75, potential: 95, age: 21),
      );
      expect(risingProspect.tradeValue, greaterThan(grizzledVet.tradeValue));

      // And it should match the standalone function exactly, not just
      // trend the same direction.
      expect(
        grizzledVet.tradeValue,
        playerTradeValue(
          overall: 75,
          potential: 76,
          skillPoints: 75 * 12,
          age: 33,
        ),
      );
    });
  });

  group('PickTradeAsset', () {
    test('tradeValue comes from the flat round ladder, regardless of '
        'draftSeason or originalTeamAbbreviation', () {
      const pick = PickTradeAsset(
        draftSeason: 1,
        round: 1,
        originalTeamAbbreviation: 'AAA',
      );
      expect(pick.tradeValue, 400);
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
