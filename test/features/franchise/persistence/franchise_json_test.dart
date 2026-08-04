import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/coach/domain/coach.dart';
import 'package:womensbballmgr/features/coach/domain/coach_stats.dart';
import 'package:womensbballmgr/features/franchise/domain/franchise.dart';
import 'package:womensbballmgr/features/franchise/persistence/franchise_json.dart';
import 'package:womensbballmgr/features/league/domain/initial_league.dart';
import 'package:womensbballmgr/features/player/domain/achievement.dart';
import 'package:womensbballmgr/features/player/domain/archetype.dart';
import 'package:womensbballmgr/features/player/domain/player.dart';
import 'package:womensbballmgr/features/player/domain/trait.dart';
import 'package:womensbballmgr/features/roster/domain/roster_membership.dart';
import 'package:womensbballmgr/features/roster/domain/roster_status.dart';
import 'package:womensbballmgr/features/roster/domain/starting_lineup.dart';

import '../../roster/domain/roster_test_helpers.dart';

Franchise _sampleFranchise() {
  final starter = playerWithOverall(72, id: 'p-starter', name: 'Riley Okafor');
  final roster = [
    RosterMembership(player: starter, status: RosterStatus.active),
    RosterMembership(
      player: playerWithOverall(
        50,
        id: 'p-bench',
        name: 'Bench Player',
        yearsOfService: 1,
      ),
      status: RosterStatus.developmental,
    ),
  ];

  return Franchise(
    id: 'franchise-1',
    gmName: 'Taylor Reed',
    team: kInitialLeagueTeams.first,
    coach: const Coach(
      name: 'Jordan Ellis',
      stats: CoachStats(
        offense: 60,
        defense: 55,
        development: 70,
        motivation: 65,
        management: 50,
      ),
    ),
    roster: roster,
    startingLineup: const StartingLineup(
      startersByPosition: {Position.pointGuard: 'p-starter'},
    ),
    simulationSeed: 42,
  );
}

void main() {
  test('franchiseToJson/franchiseFromJson round-trips every field', () {
    final original = _sampleFranchise();

    final restored = franchiseFromJson(franchiseToJson(original));

    expect(restored.id, original.id);
    expect(restored.gmName, original.gmName);
    expect(restored.simulationSeed, original.simulationSeed);

    expect(restored.team.abbreviation, original.team.abbreviation);
    expect(restored.team.name, original.team.name);
    expect(restored.team.conference, original.team.conference);
    expect(restored.team.colors.primaryHex, original.team.colors.primaryHex);

    expect(restored.coach.name, original.coach.name);
    expect(restored.coach.stats.overall, original.coach.stats.overall);

    expect(
      restored.startingLineup.startersByPosition,
      original.startingLineup.startersByPosition,
    );

    expect(restored.roster, hasLength(original.roster.length));
    for (var i = 0; i < original.roster.length; i++) {
      final originalMember = original.roster[i];
      final restoredMember = restored.roster[i];

      expect(restoredMember.status, originalMember.status);
      expect(restoredMember.player.id, originalMember.player.id);
      expect(restoredMember.player.name, originalMember.player.name);
      expect(
        restoredMember.player.yearsOfService,
        originalMember.player.yearsOfService,
      );
      expect(
        restoredMember.player.primaryPosition,
        originalMember.player.primaryPosition,
      );
      expect(
        restoredMember.player.ratings.overall,
        originalMember.player.ratings.overall,
      );
      expect(restoredMember.player.archetype, originalMember.player.archetype);
      expect(restoredMember.player.traits, originalMember.player.traits);
    }
  });

  test('round-trips a player with secondary positions', () {
    final withSecondary = Player(
      id: 'p-multi',
      name: 'Multi Position',
      age: 25,
      yearsOfService: 2,
      hometown: 'Fictional City',
      primaryPosition: Position.smallForward,
      secondaryPositions: const {Position.shootingGuard, Position.powerForward},
      handedness: Handedness.left,
      biography: '',
      ratings: playerWithOverall(60).ratings,
      archetype: Archetype.versatileForward,
      traits: const {Trait.leader, Trait.gymRat},
      nickname: 'The Wall',
      achievements: const [
        PlayerAchievementRecord(achievement: Achievement.leagueMvp, season: 0),
        PlayerAchievementRecord(
          achievement: Achievement.defensiveMvp,
          season: 1,
        ),
      ],
    );
    final franchise = Franchise(
      id: 'franchise-2',
      gmName: 'Taylor Reed',
      team: kInitialLeagueTeams.first,
      coach: const Coach(name: 'Coach', stats: CoachStats.neutral),
      roster: [
        RosterMembership(player: withSecondary, status: RosterStatus.active),
      ],
      startingLineup: const StartingLineup(
        startersByPosition: {Position.smallForward: 'p-multi'},
      ),
      simulationSeed: 1,
    );

    final restored = franchiseFromJson(franchiseToJson(franchise));

    expect(
      restored.roster.single.player.secondaryPositions,
      withSecondary.secondaryPositions,
    );
    expect(restored.roster.single.player.handedness, Handedness.left);
    expect(restored.roster.single.player.archetype, withSecondary.archetype);
    expect(restored.roster.single.player.traits, withSecondary.traits);
    expect(restored.roster.single.player.nickname, 'The Wall');
    expect(restored.roster.single.player.achievements, hasLength(2));
    expect(
      restored.roster.single.player.achievements[0].achievement,
      Achievement.leagueMvp,
    );
    expect(restored.roster.single.player.achievements[0].season, 0);
    expect(
      restored.roster.single.player.achievements[1].achievement,
      Achievement.defensiveMvp,
    );
    expect(restored.roster.single.player.achievements[1].season, 1);
    expect(
      restored.startingLineup.startersByPosition[Position.smallForward],
      'p-multi',
    );
  });

  test('round-trips a player with no nickname and no achievements', () {
    final franchise = _sampleFranchise();

    final restored = franchiseFromJson(franchiseToJson(franchise));

    expect(restored.roster.first.player.nickname, isNull);
    expect(restored.roster.first.player.achievements, isEmpty);
  });
}
