import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/franchise/domain/franchise.dart';
import 'package:womensbballmgr/features/franchise/onboarding/expansion_franchise_factory.dart';
import 'package:womensbballmgr/features/league/domain/team.dart';
import 'package:womensbballmgr/features/market/generation/player_market_preview_generator.dart';
import 'package:womensbballmgr/features/roster/domain/roster_status.dart';

Franchise _newFranchise() => createExpansionFranchise(
  gmName: 'Jordan Ellis',
  clubName: 'Comets',
  homeCity: 'Springfield, IL',
  conference: Conference.atlantic,
  replacedTeamAbbreviation: 'BOS',
  colors: kStarterPalettes.first,
  emoji: '🏀',
  simulationSeed: 1,
);

void main() {
  group('generateFreeAgentPreview', () {
    test('generates the requested count, deterministically for a given '
        'seed', () {
      final a = generateFreeAgentPreview(Random(1), count: 8);
      final b = generateFreeAgentPreview(Random(1), count: 8);

      expect(a, hasLength(8));
      expect(a.map((p) => p.name), b.map((p) => p.name));
      expect(a.map((p) => p.ratings.overall), b.map((p) => p.ratings.overall));
    });

    test('below-roster quality -- noticeably under the AI role-player '
        'baseline (65) on average', () {
      final pool = generateFreeAgentPreview(Random(7), count: 60);
      final averageOverall =
          pool.map((p) => p.ratings.overall).reduce((a, b) => a + b) /
          pool.length;

      expect(averageOverall, lessThan(60));
    });
  });

  group('pickTradeBlockPreview', () {
    test('picks up to count players, each a real member of the team '
        'they\'re listed under', () {
      final franchise = _newFranchise();

      final picks = pickTradeBlockPreview(franchise, Random(3), count: 8);

      expect(picks.length, 8);
      // No two picks from the same team -- one per distinct AI team.
      final teams = picks.map((p) => p.team.abbreviation).toSet();
      expect(teams, hasLength(8));
      for (final pick in picks) {
        final aiTeam = franchise.league.aiTeams.firstWhere(
          (t) => t.team.abbreviation == pick.team.abbreviation,
        );
        final active = [
          for (final m in aiTeam.roster)
            if (m.status == RosterStatus.active) m.player,
        ];
        expect(active, contains(pick.player));
      }
    });

    test('deterministic for a given seed', () {
      final franchise = _newFranchise();

      final a = pickTradeBlockPreview(franchise, Random(3), count: 5);
      final b = pickTradeBlockPreview(franchise, Random(3), count: 5);

      expect(a.map((p) => p.player.id), b.map((p) => p.player.id));
    });
  });

  group('generateDraftPreview', () {
    test('generates the requested count with real colleges assigned', () {
      final prospects = generateDraftPreview(Random(5), count: 12);

      expect(prospects, hasLength(12));
      for (final prospect in prospects) {
        expect(prospect.player.yearsOfService, 0);
        expect(prospect.college.name, isNotEmpty);
      }
    });
  });
}
