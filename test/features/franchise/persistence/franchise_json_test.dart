import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/coach/domain/coach.dart';
import 'package:womensbballmgr/features/coach/domain/coach_archetype.dart';
import 'package:womensbballmgr/features/coach/domain/coach_stats.dart';
import 'package:womensbballmgr/features/draft/domain/draft_in_progress.dart';
import 'package:womensbballmgr/features/draft/domain/draft_pick.dart';
import 'package:womensbballmgr/features/draft/domain/draft_prospect.dart';
import 'package:womensbballmgr/features/franchise/domain/franchise.dart';
import 'package:womensbballmgr/features/franchise/domain/pending_retirement.dart';
import 'package:womensbballmgr/features/franchise/persistence/franchise_json.dart';
import 'package:womensbballmgr/features/league/domain/initial_league.dart';
import 'package:womensbballmgr/features/player/domain/achievement.dart';
import 'package:womensbballmgr/features/player/domain/archetype.dart';
import 'package:womensbballmgr/features/player/domain/player.dart';
import 'package:womensbballmgr/features/player/domain/retirement_reason.dart';
import 'package:womensbballmgr/features/player/domain/trait.dart';
import 'package:womensbballmgr/features/roster/domain/roster_membership.dart';
import 'package:womensbballmgr/features/roster/domain/roster_status.dart';
import 'package:womensbballmgr/features/training/domain/player_rating_field.dart';
import 'package:womensbballmgr/features/training/domain/training_plan.dart';
import 'package:womensbballmgr/features/training/domain/training_report.dart';

import '../../../support/league_test_helpers.dart';
import '../../../support/season_test_helpers.dart';
import '../../../support/training_test_helpers.dart';
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
    team: kLeagueTeamPool.first,
    coach: const Coach(
      name: 'Jordan Ellis',
      stats: CoachStats(
        offense: 60,
        defense: 55,
        development: 70,
        motivation: 65,
        management: 50,
      ),
      archetype: CoachArchetype.offensiveInnovator,
    ),
    roster: roster,
    simulationSeed: 42,
    // Non-zero and distinct from simulationSeed, so the round-trip test
    // below can't pass by accident (e.g. season silently defaulting back
    // to 0 would still coincidentally "match" if this were left at 0).
    season: 5,
    // Not kLeagueTeamPool.first (BOS) -- BOS isn't actually drawn for this
    // seed, and generateLeague/testLeague asserts the replaced team is one
    // of the 20 that are (see the note on createExpansionFranchise).
    replacedTeamAbbreviation: 'ATL',
    league: testLeague(simulationSeed: 42, replacedTeamAbbreviation: 'ATL'),
    seasonProgress: testSeasonProgress(
      simulationSeed: 42,
      replacedTeamAbbreviation: 'ATL',
      ownTeam: kLeagueTeamPool.first,
    ),
    trainingCoaches: testTrainingCoaches(),
    trainingPlan: TrainingPlan.initial(),
    nextTrainingWeek: 1,
  );
}

void main() {
  test('franchiseToJson/franchiseFromJson round-trips every field', () {
    final original = _sampleFranchise();

    final restored = franchiseFromJson(franchiseToJson(original));

    expect(restored.id, original.id);
    expect(restored.gmName, original.gmName);
    expect(restored.simulationSeed, original.simulationSeed);
    expect(restored.season, original.season);
    expect(
      restored.replacedTeamAbbreviation,
      original.replacedTeamAbbreviation,
    );

    expect(restored.team.abbreviation, original.team.abbreviation);
    expect(restored.team.name, original.team.name);
    expect(restored.team.conference, original.team.conference);
    expect(restored.team.colors.primaryHex, original.team.colors.primaryHex);
    expect(restored.team.emoji, original.team.emoji);

    expect(restored.coach.name, original.coach.name);
    expect(restored.coach.stats.overall, original.coach.stats.overall);
    expect(restored.coach.archetype, original.coach.archetype);

    expect(
      restored.seasonProgress.schedule.games.length,
      original.seasonProgress.schedule.games.length,
    );
    expect(
      restored.seasonProgress.nextGameDayIndex,
      original.seasonProgress.nextGameDayIndex,
    );
    expect(
      restored.seasonProgress.playedGames.length,
      original.seasonProgress.playedGames.length,
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
      expect(
        restoredMember.player.heightInches,
        originalMember.player.heightInches,
      );
      expect(restoredMember.player.archetype, originalMember.player.archetype);
      expect(restoredMember.player.traits, originalMember.player.traits);
    }

    expect(restored.league.aiTeams, hasLength(original.league.aiTeams.length));
    for (var i = 0; i < original.league.aiTeams.length; i++) {
      final originalAiTeam = original.league.aiTeams[i];
      final restoredAiTeam = restored.league.aiTeams[i];

      expect(
        restoredAiTeam.team.abbreviation,
        originalAiTeam.team.abbreviation,
      );
      expect(restoredAiTeam.roster, hasLength(originalAiTeam.roster.length));
      expect(
        restoredAiTeam.roster.first.player.name,
        originalAiTeam.roster.first.player.name,
      );
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
      heightInches: 74,
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
      team: kLeagueTeamPool.first,
      coach: const Coach(
        name: 'Coach',
        stats: CoachStats.neutral,
        archetype: CoachArchetype.steadyHand,
      ),
      roster: [
        RosterMembership(player: withSecondary, status: RosterStatus.active),
      ],
      simulationSeed: 1,
      replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
      league: testLeague(
        simulationSeed: 1,
        replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
      ),
      seasonProgress: testSeasonProgress(
        simulationSeed: 1,
        replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
        ownTeam: kLeagueTeamPool.first,
      ),
      trainingCoaches: testTrainingCoaches(),
      trainingPlan: TrainingPlan.initial(),
      nextTrainingWeek: 1,
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
  });

  test('round-trips a player with no nickname and no achievements', () {
    final franchise = _sampleFranchise();

    final restored = franchiseFromJson(franchiseToJson(franchise));

    expect(restored.roster.first.player.nickname, isNull);
    expect(restored.roster.first.player.achievements, isEmpty);
  });

  test('round-trips readMailIds', () {
    final franchise = _sampleFranchise().copyWithReadMailIds({
      'assistant_gm_roster_gap',
      'training_report_3',
    });

    final restored = franchiseFromJson(franchiseToJson(franchise));

    expect(restored.readMailIds, {
      'assistant_gm_roster_gap',
      'training_report_3',
    });
  });

  test('readMailIds defaults to empty when absent', () {
    final franchise = _sampleFranchise();

    final restored = franchiseFromJson(franchiseToJson(franchise));

    expect(restored.readMailIds, isEmpty);
  });

  test('round-trips seasonEndAgingResults', () {
    final franchise = _sampleFranchise().copyWithSeasonEndAging(
      newRoster: _sampleFranchise().roster,
      newResults: const [
        PlayerGrowthResult(
          playerId: 'p-starter',
          fieldDeltas: {
            PlayerRatingField.speed: -2,
            PlayerRatingField.agility: -1,
          },
          overallBefore: 72,
          overallAfter: 70,
        ),
      ],
    );

    final restored = franchiseFromJson(franchiseToJson(franchise));

    expect(restored.seasonEndAgingResults, hasLength(1));
    final result = restored.seasonEndAgingResults.single;
    expect(result.playerId, 'p-starter');
    expect(result.fieldDeltas[PlayerRatingField.speed], -2);
    expect(result.fieldDeltas[PlayerRatingField.agility], -1);
    expect(result.overallBefore, 72);
    expect(result.overallAfter, 70);
  });

  test('seasonEndAgingResults defaults to empty when absent', () {
    final franchise = _sampleFranchise();

    final restored = franchiseFromJson(franchiseToJson(franchise));

    expect(restored.seasonEndAgingResults, isEmpty);
  });

  test('round-trips pendingRetirements (2026-08-11, 0D_Season_2_Roadmap.md: '
      'Aging & roster churn)', () {
    final franchise = _sampleFranchise().copyWithPendingRetirements(const [
      PendingRetirement(
        playerId: 'p-starter',
        reason: RetirementReason.declinedFromPeak,
      ),
    ]);

    final restored = franchiseFromJson(franchiseToJson(franchise));

    expect(restored.pendingRetirements, hasLength(1));
    expect(restored.pendingRetirements.single.playerId, 'p-starter');
    expect(
      restored.pendingRetirements.single.reason,
      RetirementReason.declinedFromPeak,
    );
  });

  test('pendingRetirements round-trips empty', () {
    final franchise = _sampleFranchise();

    final restored = franchiseFromJson(franchiseToJson(franchise));

    expect(restored.pendingRetirements, isEmpty);
  });

  test('round-trips draftClass (2026-08-11, 0D_Season_2_Roadmap.md: Player '
      'pool refresh)', () {
    final prospect = DraftProspect(
      player: playerWithOverall(65, id: 'p-prospect', name: 'Sam Rookie'),
      college: kColleges.first,
    );
    final franchise = _sampleFranchise().copyWithDraftClass([prospect]);

    final restored = franchiseFromJson(franchiseToJson(franchise));

    expect(restored.draftClass, hasLength(1));
    expect(restored.draftClass.single.player.id, 'p-prospect');
    expect(restored.draftClass.single.player.name, 'Sam Rookie');
    expect(
      restored.draftClass.single.college.abbreviation,
      kColleges.first.abbreviation,
    );
  });

  test('draftClass round-trips empty', () {
    final franchise = _sampleFranchise();

    final restored = franchiseFromJson(franchiseToJson(franchise));

    expect(restored.draftClass, isEmpty);
  });

  test('draftInProgress is null by default and round-trips as null '
      '(2026-08-11, 0D_Season_2_Roadmap.md: The draft, for real)', () {
    final franchise = _sampleFranchise();

    final restored = franchiseFromJson(franchiseToJson(franchise));

    expect(restored.draftInProgress, isNull);
  });

  test('round-trips a mid-resolution draftInProgress, picks included', () {
    final prospect = DraftProspect(
      player: playerWithOverall(65, id: 'p-prospect', name: 'Sam Rookie'),
      college: kColleges.first,
    );
    final draft = DraftInProgress(
      order: const ['AAA', 'BBB', 'CCC'],
      rounds: 3,
      picks: [
        DraftPick(
          round: 1,
          pickNumber: 1,
          teamAbbreviation: 'AAA',
          prospect: prospect,
        ),
      ],
    );
    final franchise = _sampleFranchise().copyWithDraftInProgress(draft);

    final restored = franchiseFromJson(franchiseToJson(franchise));

    expect(restored.draftInProgress, isNotNull);
    expect(restored.draftInProgress!.order, ['AAA', 'BBB', 'CCC']);
    expect(restored.draftInProgress!.rounds, 3);
    expect(restored.draftInProgress!.picks, hasLength(1));
    expect(
      restored.draftInProgress!.picks.single.prospect.player.id,
      'p-prospect',
    );
  });
}
