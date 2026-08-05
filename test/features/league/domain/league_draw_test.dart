import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/league/domain/initial_league.dart';
import 'package:womensbballmgr/features/league/domain/league_draw.dart';
import 'package:womensbballmgr/features/league/domain/team.dart';

void main() {
  test('draws exactly 10 teams per conference, all from the pool', () {
    final drawn = drawLeagueTeams(Random(42));

    expect(drawn, hasLength(20));
    expect(drawn.toSet(), hasLength(20));
    for (final team in drawn) {
      expect(kLeagueTeamPool, contains(team));
    }

    final byConference = <Conference, int>{};
    for (final team in drawn) {
      byConference[team.conference] = (byConference[team.conference] ?? 0) + 1;
    }
    expect(byConference[Conference.atlantic], 10);
    expect(byConference[Conference.pacific], 10);
  });

  test('is deterministic for the same random stream', () {
    final first = drawLeagueTeams(Random(7));
    final second = drawLeagueTeams(Random(7));
    expect(first, second);
  });

  test('different seeds can draw different leagues', () {
    final drawsBySeed = [
      for (var seed = 0; seed < 10; seed++) drawLeagueTeams(Random(seed)),
    ];
    final distinctDraws = drawsBySeed.map((teams) => teams.toSet()).toSet();
    expect(distinctDraws.length, greaterThan(1));
  });
}
