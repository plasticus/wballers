import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/matchup/domain/analyst.dart';
import 'package:womensbballmgr/features/matchup/domain/matchup_analysis.dart';
import 'package:womensbballmgr/features/player/domain/archetype.dart';
import 'package:womensbballmgr/features/player/domain/player.dart';
import 'package:womensbballmgr/features/player/domain/player_ratings.dart';
import 'package:womensbballmgr/features/season/domain/league_leaders.dart';

Player _player(String id, int overall, {int? offense, int? defense}) {
  return Player(
    id: id,
    name: 'Player $id',
    age: 25,
    yearsOfService: 3,
    hometown: 'Testville',
    primaryPosition: Position.pointGuard,
    handedness: Handedness.right,
    biography: '',
    heightInches: 70,
    archetype: kArchetypesByPosition[Position.pointGuard]!.first,
    ratings: PlayerRatings(
      speed: overall,
      agility: overall,
      strength: overall,
      stamina: overall,
      ballControl: offense ?? overall,
      passing: offense ?? overall,
      interiorOffense: offense ?? overall,
      perimeterOffense: offense ?? overall,
      perimeterDefense: defense ?? overall,
      interiorDefense: defense ?? overall,
      disruption: defense ?? overall,
      blocking: defense ?? overall,
      potential: overall,
    ),
  );
}

void main() {
  group('teamCompositeRating', () {
    test('is 0 for an empty roster', () {
      expect(teamCompositeRating([], (r) => r.overall), 0);
    });

    test('a single player weighs at full rank-1 weight', () {
      final players = [_player('a', 80)];
      expect(teamCompositeRating(players, (r) => r.overall), 80);
    });

    test('rank order matters -- a deep bench player counts for less than '
        'a starter, even with a higher raw rating', () {
      // 12 players, ranks 1-12: rank 1 rides at full weight (1.0), rank 12
      // at 0.6 (`weightForRosterRank`). A rank-12 player with a much
      // higher rating still can't outweigh the starters.
      final startersAndBench = [
        for (var i = 0; i < 11; i++) _player('p$i', 70),
        _player('bench', 99),
      ];
      final rating = teamCompositeRating(startersAndBench, (r) => r.overall);
      // Weighted mean should sit close to 70, not dragged much by one
      // high-rated deep-bench player.
      expect(rating, closeTo(72, 1));
    });

    test('reads whichever selector is given -- offense vs. overall differ', () {
      final players = [_player('a', 60, offense: 90)];
      expect(teamCompositeRating(players, (r) => r.offenseOverall), 90);
      // overall averages all 12 fields (4 physical @60, 4 offense @90, 4
      // defense @60), not just the "base" value passed to the fixture.
      expect(teamCompositeRating(players, (r) => r.overall), 70);
    });
  });

  group('topPlayersFor', () {
    test('best-first, capped at count', () {
      final players = [
        _player('low', 60),
        _player('high', 90),
        _player('mid', 75),
      ];

      final top2 = topPlayersFor(players, count: 2);

      expect(top2.map((p) => p.id), ['high', 'mid']);
    });

    test('defaults to 3', () {
      final players = [for (var i = 0; i < 5; i++) _player('p$i', 60 + i)];
      expect(topPlayersFor(players), hasLength(3));
    });

    test('shorter than count for a small roster', () {
      final players = [_player('only', 70)];
      expect(topPlayersFor(players), hasLength(1));
    });
  });

  group('analystVerdicts', () {
    test('each of the 5 seats picks off exactly one real number, in seat '
        'order (offense, defense, physical, overall, top player)', () {
      final verdicts = analystVerdicts(
        panel: kAnalystPanel,
        homeAbbreviation: 'HOME',
        awayAbbreviation: 'AWAY',
        homeOffense: 80,
        awayOffense: 60, // home wins offense
        homeDefense: 50,
        awayDefense: 70, // away wins defense
        homePhysical: 65,
        awayPhysical: 65, // tie -> home (>=)
        homeOverall: 75,
        awayOverall: 72, // home wins overall
        homeTopPlayerOverall: 88,
        awayTopPlayerOverall: 91, // away wins top player
      );

      expect(verdicts, hasLength(5));
      expect(verdicts.map((v) => v.pickedTeamAbbreviation).toList(), [
        'HOME',
        'AWAY',
        'HOME',
        'HOME',
        'AWAY',
      ]);
      expect(
        verdicts.map((v) => v.analyst.name).toList(),
        kAnalystPanel.map((a) => a.name).toList(),
      );
    });

    test('asserts the panel always has exactly 5 seats', () {
      expect(
        () => analystVerdicts(
          panel: const [kAnalystReyes],
          homeAbbreviation: 'HOME',
          awayAbbreviation: 'AWAY',
          homeOffense: 1,
          awayOffense: 1,
          homeDefense: 1,
          awayDefense: 1,
          homePhysical: 1,
          awayPhysical: 1,
          homeOverall: 1,
          awayOverall: 1,
          homeTopPlayerOverall: 1,
          awayTopPlayerOverall: 1,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('topThreeStatLine', () {
    test('returns default zeroes for null or zero games played', () {
      expect(topThreeStatLine(null), '0.0 points, 0.0 rebounds, 0.0 assists');
      expect(
        topThreeStatLine(
          const PlayerSeasonTotals(
            playerId: 'p1',
            gamesPlayed: 0,
            minutes: 0,
            points: 0,
            rebounds: 0,
            assists: 0,
            steals: 0,
            blocks: 0,
            turnovers: 0,
            fieldGoalsMade: 0,
            fieldGoalAttempts: 0,
            threePointersMade: 0,
            threePointAttempts: 0,
            freeThrowsMade: 0,
            freeThrowAttempts: 0,
          ),
        ),
        '0.0 points, 0.0 rebounds, 0.0 assists',
      );
    });

    test('picks top 3 counting stats per game sorted descending by value', () {
      const totals = PlayerSeasonTotals(
        playerId: 'p1',
        gamesPlayed: 10,
        minutes: 320,
        points: 190, // 19.0 ppg
        rebounds: 20, // 2.0 rpg
        assists: 67, // 6.7 apg
        steals: 10, // 1.0 spg
        blocks: 32, // 3.2 bpg
        turnovers: 15,
        fieldGoalsMade: 70,
        fieldGoalAttempts: 150,
        threePointersMade: 20,
        threePointAttempts: 50,
        freeThrowsMade: 30,
        freeThrowAttempts: 35,
      );

      expect(topThreeStatLine(totals), '19.0 points, 6.7 assists, 3.2 blocks');
    });
  });
}
