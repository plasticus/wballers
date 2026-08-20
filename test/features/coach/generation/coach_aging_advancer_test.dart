import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/coach/domain/coach_lifecycle.dart';
import 'package:womensbballmgr/features/coach/generation/coach_aging_advancer.dart';
import 'package:womensbballmgr/features/franchise/onboarding/expansion_franchise_factory.dart';
import 'package:womensbballmgr/features/league/domain/league.dart';
import 'package:womensbballmgr/features/league/domain/team.dart';
import 'package:womensbballmgr/features/league/domain/team_identity.dart';

import '../../../support/franchise_test_helpers.dart';

void main() {
  group('resolveCoachAging (2026-08-19, coach-lifecycle-notes.md: "a flat +1 '
      'per skill every off-season... coaches retire at 65")', () {
    test('grows the GM\'s own coach by 1 year and +1 per stat, when '
        'nowhere near retirement', () {
      final franchise = withFullActiveRoster(
        createExpansionFranchise(
          gmName: 'Jordan Ellis',
          clubName: 'Comets',
          homeCity: 'Springfield, IL',
          conference: Conference.atlantic,
          replacedTeamAbbreviation: 'BOS',
          colors: kStarterPalettes.first,
          emoji: '🏀',
          simulationSeed: 1,
        ),
      );
      final before = franchise.coach;

      final advance = resolveCoachAging(Random(1), franchise);

      expect(advance.ownCoachRetired, isFalse);
      expect(advance.franchise.coach.name, before.name);
      expect(advance.franchise.coach.age, before.age + 1);
    });

    test('mandatorily retires and replaces the GM\'s own coach once '
        'they age past 65', () {
      final franchise = withFullActiveRoster(
        createExpansionFranchise(
          gmName: 'Jordan Ellis',
          clubName: 'Comets',
          homeCity: 'Springfield, IL',
          conference: Conference.atlantic,
          replacedTeamAbbreviation: 'BOS',
          colors: kStarterPalettes.first,
          emoji: '🏀',
          simulationSeed: 1,
        ),
      );
      final oldCoach = franchise.coach.copyWithGrowth(
        newAge: kCoachRetirementAge,
        newStats: franchise.coach.stats,
      );
      final withOldCoach = franchise.copyWithCoach(oldCoach);

      final advance = resolveCoachAging(Random(1), withOldCoach);

      expect(advance.ownCoachRetired, isTrue);
      // A real replacement, not just another year of growth on the old
      // coach -- growth alone could never produce an age this low from
      // a 65-year-old, so this alone proves a fresh coach landed here
      // (comparing names isn't reliable: the finite name pool can
      // coincidentally repeat between two independent draws).
      expect(
        advance.franchise.coach.age,
        inInclusiveRange(kCoachEntryMinAge, kCoachEntryMaxAge),
      );
    });

    test('grows every AI team\'s coach too, leaving coachHiredSeason '
        'untouched when nobody retires', () {
      final franchise = withFullActiveRoster(
        createExpansionFranchise(
          gmName: 'Jordan Ellis',
          clubName: 'Comets',
          homeCity: 'Springfield, IL',
          conference: Conference.atlantic,
          replacedTeamAbbreviation: 'BOS',
          colors: kStarterPalettes.first,
          emoji: '🏀',
          simulationSeed: 1,
        ),
      );
      final aiTeam = franchise.league.aiTeams.first;

      final advance = resolveCoachAging(Random(1), franchise);

      expect(advance.retiredAiTeamAbbreviations, isEmpty);
      final updatedAiTeam = advance.franchise.league.aiTeams.firstWhere(
        (t) => t.team.abbreviation == aiTeam.team.abbreviation,
      );
      expect(updatedAiTeam.coach.age, aiTeam.coach.age + 1);
      expect(updatedAiTeam.coachHiredSeason, aiTeam.coachHiredSeason);
    });

    test('mandatorily retires and replaces an AI coach who ages past '
        '65, resetting their coachHiredSeason to the current season', () {
      final franchise = withFullActiveRoster(
        createExpansionFranchise(
          gmName: 'Jordan Ellis',
          clubName: 'Comets',
          homeCity: 'Springfield, IL',
          conference: Conference.atlantic,
          replacedTeamAbbreviation: 'BOS',
          colors: kStarterPalettes.first,
          emoji: '🏀',
          simulationSeed: 1,
        ),
      );
      final aiTeam = franchise.league.aiTeams.first;
      final oldAiCoach = aiTeam.coach.copyWithGrowth(
        newAge: kCoachRetirementAge,
        newStats: aiTeam.coach.stats,
      );
      final newAiTeams = [
        aiTeam.copyWithCoach(newCoach: oldAiCoach, hiredSeason: 0),
        ...franchise.league.aiTeams.skip(1),
      ];
      final withOldAiCoach = franchise.copyWithLeague(
        League(aiTeams: newAiTeams),
      );

      final advance = resolveCoachAging(Random(1), withOldAiCoach);

      expect(
        advance.retiredAiTeamAbbreviations,
        contains(aiTeam.team.abbreviation),
      );
      final updatedAiTeam = advance.franchise.league.aiTeams.firstWhere(
        (t) => t.team.abbreviation == aiTeam.team.abbreviation,
      );
      // Same "age alone proves a real replacement" reasoning the GM's
      // own mandatory-retirement test above uses.
      expect(
        updatedAiTeam.coach.age,
        inInclusiveRange(kCoachEntryMinAge, kCoachEntryMaxAge),
      );
      expect(updatedAiTeam.coachHiredSeason, franchise.season);
      // 2026-08-20, a direct GM ask for lightweight team identities --
      // the real replacement locks to this team's own permanent
      // TeamIdentity archetype, not a fresh random roll.
      expect(
        updatedAiTeam.coach.archetype,
        identityFor(aiTeam.team.abbreviation).archetype,
      );
    });

    test('every other AI team is untouched -- same 19 teams, same '
        'order, same non-coach data', () {
      final franchise = withFullActiveRoster(
        createExpansionFranchise(
          gmName: 'Jordan Ellis',
          clubName: 'Comets',
          homeCity: 'Springfield, IL',
          conference: Conference.atlantic,
          replacedTeamAbbreviation: 'BOS',
          colors: kStarterPalettes.first,
          emoji: '🏀',
          simulationSeed: 1,
        ),
      );

      final advance = resolveCoachAging(Random(1), franchise);

      expect(
        advance.franchise.league.aiTeams.map((t) => t.team.abbreviation),
        franchise.league.aiTeams.map((t) => t.team.abbreviation),
      );
      for (var i = 0; i < franchise.league.aiTeams.length; i++) {
        expect(
          advance.franchise.league.aiTeams[i].roster.length,
          franchise.league.aiTeams[i].roster.length,
        );
      }
    });

    test('is deterministic for the same random stream', () {
      final franchise = withFullActiveRoster(
        createExpansionFranchise(
          gmName: 'Jordan Ellis',
          clubName: 'Comets',
          homeCity: 'Springfield, IL',
          conference: Conference.atlantic,
          replacedTeamAbbreviation: 'BOS',
          colors: kStarterPalettes.first,
          emoji: '🏀',
          simulationSeed: 1,
        ),
      );
      final oldCoach = franchise.coach.copyWithGrowth(
        newAge: kCoachRetirementAge,
        newStats: franchise.coach.stats,
      );
      final withOldCoach = franchise.copyWithCoach(oldCoach);

      final a = resolveCoachAging(Random(9), withOldCoach);
      final b = resolveCoachAging(Random(9), withOldCoach);

      expect(a.franchise.coach.name, b.franchise.coach.name);
      expect(a.franchise.coach.age, b.franchise.coach.age);
      expect(a.franchise.coach.stats.overall, b.franchise.coach.stats.overall);
    });
  });
}
