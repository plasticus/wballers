import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/league/domain/league_draw.dart';
import 'package:womensbballmgr/features/league/domain/team_identity.dart';
import 'package:womensbballmgr/features/league/generation/league_generator.dart';
import 'package:womensbballmgr/features/roster/domain/star_tier.dart';

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

  test('every AI team\'s coach and star player match its own permanent '
      'TeamIdentity (2026-08-20, a direct GM ask for lightweight team '
      'identities)', () {
    const seed = 1;
    final drawn = drawLeagueTeams(Random(seed + kLeagueDrawSeedOffset));

    final league = generateLeague(
      simulationSeed: seed,
      replacedTeamAbbreviation: drawn.first.abbreviation,
    );

    for (final aiTeam in league.aiTeams) {
      final identity = identityFor(aiTeam.team.abbreviation);
      expect(
        aiTeam.coach.archetype,
        identity.archetype,
        reason: aiTeam.team.abbreviation,
      );
      final star = aiTeam.roster.singleWhere(
        (m) => StarTier.of(m.player) == StarTier.fourStar,
      );
      expect(
        star.player.primaryPosition,
        identity.positionLean,
        reason: aiTeam.team.abbreviation,
      );
    }
  });
}
