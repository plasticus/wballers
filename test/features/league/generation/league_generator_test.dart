import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/league/domain/league_draw.dart';
import 'package:womensbballmgr/features/league/generation/league_generator.dart';

void main() {
  test('generates 19 AI teams, none of them the replaced team', () {
    const seed = 1;
    final drawn = drawLeagueTeams(Random(seed + kLeagueDrawSeedOffset));
    final replaced = drawn.first;

    final league = generateLeague(
      simulationSeed: seed,
      replacedTeamAbbreviation: replaced.abbreviation,
    );

    expect(league.aiTeams, hasLength(19));
    expect(
      league.aiTeams.map((aiTeam) => aiTeam.team.abbreviation),
      isNot(contains(replaced.abbreviation)),
    );
  });

  test('every AI team gets a 12-player roster', () {
    const seed = 1;
    final drawn = drawLeagueTeams(Random(seed + kLeagueDrawSeedOffset));

    final league = generateLeague(
      simulationSeed: seed,
      replacedTeamAbbreviation: drawn.first.abbreviation,
    );

    for (final aiTeam in league.aiTeams) {
      expect(aiTeam.roster, hasLength(12));
    }
  });

  test('is deterministic for the same seed and replaced team', () {
    const seed = 42;
    final drawn = drawLeagueTeams(Random(seed + kLeagueDrawSeedOffset));
    final replaced = drawn.first.abbreviation;

    final a = generateLeague(
      simulationSeed: seed,
      replacedTeamAbbreviation: replaced,
    );
    final b = generateLeague(
      simulationSeed: seed,
      replacedTeamAbbreviation: replaced,
    );

    for (var i = 0; i < a.aiTeams.length; i++) {
      expect(a.aiTeams[i].team.abbreviation, b.aiTeams[i].team.abbreviation);
      expect(
        a.aiTeams[i].roster.first.player.name,
        b.aiTeams[i].roster.first.player.name,
      );
    }
  });
}
