import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/core/persistence/save_envelope.dart';
import 'package:womensbballmgr/core/persistence/save_repository_provider.dart';
import 'package:womensbballmgr/features/coach/domain/coach.dart';
import 'package:womensbballmgr/features/coach/domain/coach_archetype.dart';
import 'package:womensbballmgr/features/coach/domain/coach_stats.dart';
import 'package:womensbballmgr/features/draft/generation/draft_generator.dart';
import 'package:womensbballmgr/features/franchise/application/current_franchise_provider.dart';
import 'package:womensbballmgr/features/franchise/domain/former_player_record.dart';
import 'package:womensbballmgr/features/franchise/domain/franchise.dart';
import 'package:womensbballmgr/features/franchise/domain/league_retirement.dart';
import 'package:womensbballmgr/features/franchise/onboarding/expansion_franchise_factory.dart';
import 'package:womensbballmgr/features/franchise/persistence/franchise_json.dart';
import 'package:womensbballmgr/features/league/domain/initial_league.dart';
import 'package:womensbballmgr/features/league/domain/team.dart';
import 'package:womensbballmgr/features/player/domain/achievement.dart';
import 'package:womensbballmgr/features/player/domain/position.dart';
import 'package:womensbballmgr/features/player/domain/retirement_reason.dart';
import 'package:womensbballmgr/features/roster/domain/roster_membership.dart';
import 'package:womensbballmgr/features/roster/domain/roster_status.dart';
import 'package:womensbballmgr/features/roster/generation/starting_roster_generator.dart';
import 'package:womensbballmgr/features/season/application/franchise_rosters.dart';
import 'package:womensbballmgr/features/season/domain/game_day.dart';
import 'package:womensbballmgr/features/season/domain/played_game.dart';
import 'package:womensbballmgr/features/season/domain/scheduled_game.dart';
import 'package:womensbballmgr/features/season/domain/season_progress.dart';
import 'package:womensbballmgr/features/season/generation/continental_cup_generator.dart';
import 'package:womensbballmgr/features/season/generation/postseason_generator.dart';
import 'package:womensbballmgr/features/season/generation/season_advancer.dart';
import 'package:womensbballmgr/features/season/presentation/season_recap_screen.dart';
import 'package:womensbballmgr/features/training/domain/player_rating_field.dart';
import 'package:womensbballmgr/features/training/domain/training_plan.dart';
import 'package:womensbballmgr/features/training/domain/training_report.dart';

import '../../../support/franchise_test_helpers.dart';
import '../../../support/in_memory_save_repository.dart';
import '../../../support/league_test_helpers.dart';
import '../../../support/season_test_helpers.dart';
import '../../../support/training_test_helpers.dart';
import '../../roster/domain/roster_test_helpers.dart';

/// Plays a real franchise all the way through the regular season,
/// Continental Cup, and postseason -- same "play it for real, don't fake
/// the data" approach `current_franchise_provider_test.dart`'s own
/// postseason test uses. The postseason plays out through this exact same
/// `advanceToNextGameDay` loop now (2026-08-20, a direct GM report: "it
/// needs to play all the games through the normal system") -- no separate
/// bulk-simulate call needed, just a generous enough guard to cover the
/// whole season through to a decided champion.
Franchise _playFullSeason(int simulationSeed) {
  var franchise = withFullActiveRoster(
    createExpansionFranchise(
      gmName: 'Jordan Ellis',
      clubName: 'Comets',
      homeCity: 'Springfield, IL',
      conference: Conference.atlantic,
      replacedTeamAbbreviation: 'BOS',
      colors: kStarterPalettes.first,
      emoji: '🏀',
      simulationSeed: simulationSeed,
    ),
  );
  final rosters = rostersByAbbreviation(franchise);
  final leagueTeams = allLeagueTeams(franchise);

  var progress = franchise.seasonProgress;
  var guard = 0;
  while (!progress.isComplete && guard < 150) {
    final advance = advanceToNextGameDay(
      Random(franchise.simulationSeed + kSeasonAdvanceSeedOffset + guard),
      progress,
      rostersByAbbreviation: rosters,
      leagueTeams: leagueTeams,
    );
    progress = advance.progress;
    guard++;
  }
  return franchise.copyWithSeasonProgress(progress);
}

void main() {
  testWidgets('shows the champion and the GM\'s own final record', (
    tester,
  ) async {
    final franchise = _playFullSeason(1);
    final champion = seasonChampion(franchise.seasonProgress.playedGames);
    expect(champion, isNotNull);

    await tester.pumpWidget(
      MaterialApp(home: SeasonRecapScreen(franchise: franchise)),
    );
    await tester.pump();

    expect(find.text('Season Recap'), findsOneWidget);
    expect(find.textContaining('Final record:'), findsOneWidget);
    expect(find.text('What\'s Next', skipOffstage: false), findsOneWidget);

    if (champion == franchise.team.abbreviation) {
      expect(find.text('🏆 You are the champions!'), findsOneWidget);
    } else {
      expect(find.textContaining('are the champions.'), findsOneWidget);
    }
  });

  testWidgets(
    'shows a League Retirements section listing this season\'s AI-team '
    'retirements (2026-08-20, a direct GM ask: "I\'d prefer to see that '
    '[retirement] in an off season report")',
    (tester) async {
      final franchise = _playFullSeason(1).copyWithLeagueRetirements(const [
        LeagueRetirement(
          playerId: 'ai-1',
          name: 'Alex Rivera',
          primaryPosition: Position.center,
          teamAbbreviation: 'CHI',
          reason: RetirementReason.hitMandatoryAge,
          season: 0,
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(home: SeasonRecapScreen(franchise: franchise)),
      );
      await tester.pump();

      expect(
        find.text('League Retirements', skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.textContaining('Alex Rivera', skipOffstage: false),
        findsOneWidget,
      );
    },
  );

  testWidgets('omits the League Retirements section when nothing retired '
      'this season', (tester) async {
    final franchise = _playFullSeason(1);

    await tester.pumpWidget(
      MaterialApp(home: SeasonRecapScreen(franchise: franchise)),
    );
    await tester.pump();

    expect(find.text('League Retirements', skipOffstage: false), findsNothing);
  });

  testWidgets(
    'shows a projected draft position matching a real lottery run, and a '
    'Continental Cup elimination line exactly when the GM\'s own team was '
    'actually eliminated (2026-08-10, TODO.md items 12/13)',
    (tester) async {
      final franchise = _playFullSeason(1);
      final playedGames = franchise.seasonProgress.playedGames;

      final leagueTeams = [
        franchise.team,
        for (final aiTeam in franchise.league.aiTeams) aiTeam.team,
      ];
      final standings = currentStandings(franchise.seasonProgress, leagueTeams);
      final expectedDraftOrder = generateDraftOrder(
        Random(franchise.simulationSeed + kDraftOrderSeedOffset),
        standings,
      );
      final expectedPick =
          expectedDraftOrder.indexOf(franchise.team.abbreviation) + 1;
      final expectedEliminationRound = continentalCupEliminationRound(
        playedGames,
        franchise.team.abbreviation,
      );

      await tester.pumpWidget(
        MaterialApp(home: SeasonRecapScreen(franchise: franchise)),
      );
      await tester.pump();

      expect(
        find.textContaining('Rough estimate: #$expectedPick overall'),
        findsOneWidget,
      );
      if (expectedEliminationRound != null) {
        expect(
          find.textContaining(
            'Eliminated from the Continental Cup in the '
            '${continentalCupRoundName(expectedEliminationRound)}',
          ),
          findsOneWidget,
        );
      } else {
        expect(
          find.textContaining('Eliminated from the Continental Cup'),
          findsNothing,
        );
      }
    },
  );

  testWidgets('shows a missed-the-playoffs message when the GM\'s own team '
      'never appears in a postseason game', (tester) async {
    final roster = generateStartingRoster(1);
    final baseProgress = testSeasonProgress(
      simulationSeed: 1,
      replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
      ownTeam: kLeagueTeamPool.first,
    );
    final league = testLeague(
      simulationSeed: 1,
      replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
    );
    // Two real AI teams from this franchise's own league play the
    // Finals -- teamByAbbreviation would throw on a made-up abbreviation
    // that isn't actually part of the league.
    final finalist1 = league.aiTeams[0].team.abbreviation;
    final finalist2 = league.aiTeams[1].team.abbreviation;
    final finals = ScheduledGame(
      week: 24,
      day: GameDay.thursday,
      homeTeamAbbreviation: finalist1,
      awayTeamAbbreviation: finalist2,
      type: GameType.postseason,
      postseasonRound: 3,
    );
    final franchise = Franchise(
      id: 'franchise-1',
      gmName: 'Taylor Reed',
      team: kLeagueTeamPool.first,
      coach: const Coach(
        name: 'Jordan Ellis',
        stats: CoachStats.neutral,
        archetype: CoachArchetype.steadyHand,
      ),
      roster: roster,
      simulationSeed: 1,
      replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
      league: league,
      seasonProgress: SeasonProgress(
        schedule: baseProgress.schedule,
        playedGames: [PlayedGame(game: finals, homeScore: 90, awayScore: 80)],
        nextGameDayIndex: 999,
      ),
      trainingCoaches: testTrainingCoaches(),
      trainingPlan: TrainingPlan.initial(),
      nextTrainingWeek: 1,
    );

    await tester.pumpWidget(
      MaterialApp(home: SeasonRecapScreen(franchise: franchise)),
    );
    await tester.pump();

    expect(find.text('🏆 You are the champions!'), findsNothing);
    expect(find.textContaining('You missed the playoffs'), findsOneWidget);
  });

  testWidgets(
    'shows a Player Development section aggregating weekly training and '
    'the season-end aging lump',
    (tester) async {
      final player = playerWithOverall(
        70,
        id: 'p1',
        name: 'Riley Okafor',
        primaryPosition: Position.pointGuard,
      );
      final franchise = Franchise(
        id: 'franchise-1',
        gmName: 'Taylor Reed',
        team: kLeagueTeamPool.first,
        coach: const Coach(
          name: 'Jordan Ellis',
          stats: CoachStats.neutral,
          archetype: CoachArchetype.steadyHand,
        ),
        roster: [RosterMembership(player: player, status: RosterStatus.active)],
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
        nextTrainingWeek: 3,
        trainingReports: const [
          TrainingReport(
            week: 2,
            results: [
              PlayerGrowthResult(
                playerId: 'p1',
                fieldDeltas: {PlayerRatingField.speed: 2},
                overallBefore: 68,
                overallAfter: 69,
              ),
            ],
          ),
        ],
        seasonEndAgingResults: const [
          PlayerGrowthResult(
            playerId: 'p1',
            fieldDeltas: {
              PlayerRatingField.speed: -1,
              PlayerRatingField.agility: -1,
            },
            overallBefore: 69,
            overallAfter: 68,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(home: SeasonRecapScreen(franchise: franchise)),
      );
      await tester.pump();

      expect(find.text('Player Development'), findsOneWidget);
      expect(find.textContaining('PG'), findsWidgets);
      expect(find.textContaining('Riley Okafor'), findsOneWidget);
      // Net across both sources: +2 (week) + (-1 -1) (lump) = 0.
      expect(find.text('+0'), findsOneWidget);
      // The per-player OVR change line (2026-08-10, TODO.md item 12) --
      // overallBefore from the first entry (68), overallAfter from the
      // last (68), net delta 0.
      expect(find.text('OVR: 68 -> 68 (+0)'), findsOneWidget);
    },
  );

  testWidgets('shows a retired player\'s real name in Player Development, not '
      '"Former Player" -- a direct GM report (2026-08-19): a retired '
      'all-star showed up on this exact section labeled "Former Player"', (
    tester,
  ) async {
    final player = playerWithOverall(
      70,
      id: 'p1',
      name: 'Riley Okafor',
      primaryPosition: Position.pointGuard,
    ).copyWithJerseyNumber(23);
    // Retired: no longer on `roster` at all, but her name/position/
    // jersey survives in `formerPlayers` -- exactly what
    // `current_franchise_provider.dart`'s `_retirePlayer` does for
    // real.
    final franchise = Franchise(
      id: 'franchise-1',
      gmName: 'Taylor Reed',
      team: kLeagueTeamPool.first,
      coach: const Coach(
        name: 'Jordan Ellis',
        stats: CoachStats.neutral,
        archetype: CoachArchetype.steadyHand,
      ),
      roster: const [],
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
      nextTrainingWeek: 3,
      trainingReports: const [
        TrainingReport(
          week: 2,
          results: [
            PlayerGrowthResult(
              playerId: 'p1',
              fieldDeltas: {PlayerRatingField.speed: 2},
              overallBefore: 68,
              overallAfter: 69,
            ),
          ],
        ),
      ],
      formerPlayers: [
        FormerPlayerRecord(
          playerId: 'p1',
          name: player.name,
          primaryPosition: player.primaryPosition,
          jerseyNumber: player.jerseyNumber,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(home: SeasonRecapScreen(franchise: franchise)),
    );
    await tester.pump();

    expect(find.textContaining('Riley Okafor'), findsOneWidget);
    expect(find.textContaining('Former Player'), findsNothing);
  });

  testWidgets(
    'shows an empty-state message when no development results exist yet',
    (tester) async {
      final roster = generateStartingRoster(1);
      final franchise = Franchise(
        id: 'franchise-1',
        gmName: 'Taylor Reed',
        team: kLeagueTeamPool.first,
        coach: const Coach(
          name: 'Jordan Ellis',
          stats: CoachStats.neutral,
          archetype: CoachArchetype.steadyHand,
        ),
        roster: roster,
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

      await tester.pumpWidget(
        MaterialApp(home: SeasonRecapScreen(franchise: franchise)),
      );
      await tester.pump();

      expect(
        find.text('No development results recorded this season.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('shows an empty-state message in the Season Awards section when '
      'nobody has won anything this season (2026-08-11, '
      '0D_Season_2_Roadmap.md: Presentation)', (tester) async {
    final roster = generateStartingRoster(1);
    final franchise = Franchise(
      id: 'franchise-1',
      gmName: 'Taylor Reed',
      team: kLeagueTeamPool.first,
      coach: const Coach(
        name: 'Jordan Ellis',
        stats: CoachStats.neutral,
        archetype: CoachArchetype.steadyHand,
      ),
      roster: roster,
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

    await tester.pumpWidget(
      MaterialApp(home: SeasonRecapScreen(franchise: franchise)),
    );
    await tester.pump();

    expect(find.text('Season Awards'), findsOneWidget);
    expect(
      find.text('No major individual awards were determined this season.'),
      findsOneWidget,
    );
  });

  testWidgets('shows each award winner, their team, nickname, and a neon-hair-'
      'unlocked note on their real 2nd career achievement (2026-08-11, '
      '0D_Season_2_Roadmap.md: Presentation)', (tester) async {
    final roster = generateStartingRoster(1);
    final winner = roster.first.player
        .copyWithAchievement(
          const PlayerAchievementRecord(
            achievement: Achievement.leagueMvp,
            season: 3,
          ),
        )
        .copyWithNickname('The Franchise');
    final secondWinner = roster[1].player
        .copyWithAchievement(
          const PlayerAchievementRecord(
            achievement: Achievement.scoringLeader,
            season: 0, // an earlier season's award -- their 1st ever
          ),
        )
        .copyWithAchievement(
          const PlayerAchievementRecord(
            achievement: Achievement.defensiveMvp,
            season: 3, // this season's -- their real 2nd ever
          ),
        )
        .copyWithNickname('Lockdown');
    final updatedRoster = [
      RosterMembership(player: winner, status: RosterStatus.active),
      RosterMembership(player: secondWinner, status: RosterStatus.active),
      ...roster.skip(2),
    ];
    final franchise = Franchise(
      id: 'franchise-1',
      gmName: 'Taylor Reed',
      team: kLeagueTeamPool.first,
      coach: const Coach(
        name: 'Jordan Ellis',
        stats: CoachStats.neutral,
        archetype: CoachArchetype.steadyHand,
      ),
      roster: updatedRoster,
      simulationSeed: 1,
      season: 3,
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

    await tester.pumpWidget(
      MaterialApp(home: SeasonRecapScreen(franchise: franchise)),
    );
    await tester.pump();

    expect(find.text('2 awards handed out across the league.'), findsOneWidget);
    expect(find.text('League MVP'), findsOneWidget);
    expect(
      find.textContaining('${winner.name} (${franchise.team.abbreviation})'),
      findsOneWidget,
    );
    expect(find.text('"The Franchise"'), findsOneWidget);
    expect(find.text('Defensive MVP'), findsOneWidget);
    expect(find.text('"Lockdown"'), findsOneWidget);
    // Only the 2nd winner just crossed the 2-achievement threshold --
    // the 1st winner's own award is their only one this test gives
    // them, findsOneWidget (not findsWidgets) confirms no false
    // positive for them.
    expect(find.text('✨ Neon hair color unlocked'), findsOneWidget);
  });

  testWidgets(
    'tapping Begin Next Season transitions the franchise and returns to '
    'the Dashboard, not Draft Day (2026-08-19, a direct GM ask: "It '
    'immediately dumps me to the draft. I don\'t like that ... feels '
    'stressful") -- the draft is still waiting, just one tap away from '
    'the Dashboard\'s own "Draft In Progress" card, not forced',
    (tester) async {
      final franchise = _playFullSeason(1);
      final repository = InMemorySaveRepository();
      await repository.writeSave(
        kCurrentFranchiseSaveId,
        SaveEnvelope(
          schemaVersion: 1,
          payload: franchiseToJson(franchise),
        ).toJson(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [saveRepositoryProvider.overrideWithValue(repository)],
          child: MaterialApp(
            home: Navigator(
              onGenerateRoute: (settings) => MaterialPageRoute(
                builder: (_) => const Scaffold(body: Text('Dashboard')),
              ),
              onGenerateInitialRoutes: (navigator, initialRoute) => [
                MaterialPageRoute(
                  builder: (_) => const Scaffold(body: Text('Dashboard')),
                ),
                MaterialPageRoute(
                  builder: (_) => SeasonRecapScreen(franchise: franchise),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.scrollUntilVisible(find.text('Begin Next Season'), 200);
      await tester.pump();
      await tester.tap(find.text('Begin Next Season'));
      await tester.pumpAndSettle();

      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Draft Day'), findsNothing);
      final context = tester.element(find.text('Dashboard'));
      final container = ProviderScope.containerOf(context);
      final updated = container.read(currentFranchiseProvider).value!;
      expect(updated.season, 1);
      expect(updated.draftInProgress, isNotNull);
    },
  );
}
