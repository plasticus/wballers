import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/coach/domain/coach.dart';
import 'package:womensbballmgr/features/coach/domain/coach_archetype.dart';
import 'package:womensbballmgr/features/coach/domain/coach_stats.dart';
import 'package:womensbballmgr/features/franchise/domain/franchise.dart';
import 'package:womensbballmgr/features/league/domain/initial_league.dart';
import 'package:womensbballmgr/features/league/domain/league.dart';
import 'package:womensbballmgr/features/player/domain/achievement.dart';
import 'package:womensbballmgr/features/portrait/domain/portrait_appearance.dart';
import 'package:womensbballmgr/features/portrait/generation/portrait_generator.dart';
import 'package:womensbballmgr/features/roster/domain/roster_membership.dart';
import 'package:womensbballmgr/features/roster/domain/roster_status.dart';
import 'package:womensbballmgr/features/season/domain/season_progress.dart';
import 'package:womensbballmgr/features/season/domain/season_schedule.dart';
import 'package:womensbballmgr/features/season/generation/achievement_grant.dart';
import 'package:womensbballmgr/features/training/domain/training_coach.dart';
import 'package:womensbballmgr/features/training/domain/training_plan.dart';

import '../../../support/league_test_helpers.dart';
import '../../roster/domain/roster_test_helpers.dart';

const _appearance = PortraitAppearance(
  baseSprite: kDefaultBaseSprite,
  skinTone: 'medium',
  hairColor: 'black',
  eyes: 'eyes_1center',
  nose: 'nose_1',
  mouth: 'mouth_1',
  isCoach: false,
);

Franchise _franchise({required String ownTeamAbbreviation}) {
  final league = testLeague(
    simulationSeed: 1,
    replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
  );
  final ownTeam = kLeagueTeamPool.firstWhere(
    (t) => t.abbreviation == ownTeamAbbreviation,
  );
  return Franchise(
    id: 'franchise-1',
    gmName: 'Taylor Reed',
    team: ownTeam,
    coach: const Coach(
      name: 'Jordan Ellis',
      stats: CoachStats.neutral,
      archetype: CoachArchetype.steadyHand,
    ),
    roster: const [],
    simulationSeed: 1,
    replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
    league: league,
    seasonProgress: SeasonProgress(
      schedule: const SeasonSchedule(games: []),
      playedGames: const [],
      nextGameDayIndex: 0,
    ),
    trainingCoaches: const [
      TrainingCoach(name: 'Coach A'),
      TrainingCoach(name: 'Coach B'),
      TrainingCoach(name: 'Coach C'),
    ],
    trainingPlan: TrainingPlan.initial(),
    nextTrainingWeek: 1,
  );
}

void main() {
  group('applyAchievementGrant', () {
    test('grants the achievement and applies a suggested nickname to the '
        'GM\'s own roster player', () {
      final player = playerWithOverall(80, id: 'p1', name: 'Jane Doe');
      final franchise =
          _franchise(
            ownTeamAbbreviation: kLeagueTeamPool[1].abbreviation,
          ).copyWithRoster([
            RosterMembership(player: player, status: RosterStatus.active),
          ]);

      final updated = applyAchievementGrant(
        Random(1),
        franchise,
        playerId: 'p1',
        achievement: Achievement.leagueMvp,
        season: 2,
      );

      final updatedPlayer = updated.roster.single.player;
      expect(updatedPlayer.achievements, hasLength(1));
      expect(
        updatedPlayer.achievements.single.achievement,
        Achievement.leagueMvp,
      );
      expect(updatedPlayer.achievements.single.season, 2);
      expect(updatedPlayer.nickname, isNotNull);
    });

    test('finds and updates a player on an AI team\'s roster instead', () {
      final ownAbbreviation = kLeagueTeamPool[1].abbreviation;
      final franchise = _franchise(ownTeamAbbreviation: ownAbbreviation);
      final targetAbbreviation =
          franchise.league.aiTeams.first.team.abbreviation;
      final player = playerWithOverall(80, id: 'p-ai', name: 'AI Player');
      final updatedFirstTeam = franchise.league.aiTeams.first.copyWithRoster([
        RosterMembership(player: player, status: RosterStatus.active),
      ]);
      final withAiPlayer = franchise.copyWithLeague(
        League(
          aiTeams: [updatedFirstTeam, ...franchise.league.aiTeams.skip(1)],
        ),
      );

      final updated = applyAchievementGrant(
        Random(1),
        withAiPlayer,
        playerId: 'p-ai',
        achievement: Achievement.scoringLeader,
        season: 0,
      );

      final updatedAiTeam = updated.league.aiTeams.firstWhere(
        (t) => t.team.abbreviation == targetAbbreviation,
      );
      expect(
        updatedAiTeam.roster.single.player.achievements.single.achievement,
        Achievement.scoringLeader,
      );
      // The GM's own (empty) roster is untouched.
      expect(updated.roster, isEmpty);
    });

    test('is a no-op when the player id is not found anywhere', () {
      final franchise = _franchise(
        ownTeamAbbreviation: kLeagueTeamPool[1].abbreviation,
      );

      final updated = applyAchievementGrant(
        Random(1),
        franchise,
        playerId: 'nobody',
        achievement: Achievement.leagueMvp,
        season: 0,
      );

      expect(updated.roster, franchise.roster);
      expect(updated.league.aiTeams, franchise.league.aiTeams);
    });

    test('auto-assigns a random neon hair color once a player earns a '
        'second achievement, but not on the first', () {
      final player = playerWithOverall(
        80,
        id: 'p1',
        name: 'Jane Doe',
      ).copyWithAppearance(_appearance);
      final franchise =
          _franchise(
            ownTeamAbbreviation: kLeagueTeamPool[1].abbreviation,
          ).copyWithRoster([
            RosterMembership(player: player, status: RosterStatus.active),
          ]);

      final afterFirst = applyAchievementGrant(
        Random(1),
        franchise,
        playerId: 'p1',
        achievement: Achievement.leagueMvp,
        season: 0,
      );
      expect(afterFirst.roster.single.player.achievements, hasLength(1));
      expect(afterFirst.roster.single.player.appearance!.topHairColor, isNull);

      final afterSecond = applyAchievementGrant(
        Random(1),
        afterFirst,
        playerId: 'p1',
        achievement: Achievement.scoringLeader,
        season: 0,
      );
      expect(afterSecond.roster.single.player.achievements, hasLength(2));
      expect(
        afterSecond.roster.single.player.appearance!.topHairColor,
        isNotNull,
      );
    });
  });
}
