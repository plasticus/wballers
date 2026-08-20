import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/coach/domain/coach.dart';
import 'package:womensbballmgr/features/coach/domain/coach_archetype.dart';
import 'package:womensbballmgr/features/coach/domain/coach_stats.dart';
import 'package:womensbballmgr/features/franchise/domain/franchise.dart';
import 'package:womensbballmgr/features/league/domain/initial_league.dart';
import 'package:womensbballmgr/features/league/domain/league.dart';
import 'package:womensbballmgr/features/league/domain/team.dart';
import 'package:womensbballmgr/features/player/domain/player.dart';
import 'package:womensbballmgr/features/roster/domain/roster_membership.dart';
import 'package:womensbballmgr/features/roster/domain/roster_status.dart';
import 'package:womensbballmgr/features/roster/generation/starting_roster_generator.dart';
import 'package:womensbballmgr/features/season/domain/skills_competition.dart';
import 'package:womensbballmgr/features/season/presentation/skills_competition_result_screen.dart';
import 'package:womensbballmgr/features/training/domain/training_plan.dart';

import '../../roster/domain/roster_test_helpers.dart';
import '../../../support/league_test_helpers.dart';
import '../../../support/season_test_helpers.dart';
import '../../../support/training_test_helpers.dart';

/// Pads [ids] out to exactly 10 with placeholder ids -- `SkillsCompetitionResult`
/// asserts exactly 10 honorees per conference, but these tests only care
/// about the handful of ids that actually appear in an event's standings.
List<String> _squadOf(String label, List<String> ids) => [
  ...ids,
  for (var i = ids.length; i < 10; i++) '$label-filler-$i',
];

/// Adds [player] to the first AI team's roster -- needed for `find.text`
/// to resolve a real name for a "rival" fixture, since the screen only
/// looks players up via `rostersByAbbreviation` (every active roster in
/// the league). Deliberately *not* the GM's own roster -- these tests
/// need a player who resolves to a real name but does *not* count as
/// "own" for the win-banner check.
League _leagueWithRival(League league, Player player) {
  final first = league.aiTeams.first;
  return League(
    aiTeams: [
      first.copyWithRoster([
        ...first.roster,
        RosterMembership(player: player, status: RosterStatus.active),
      ]),
      ...league.aiTeams.skip(1),
    ],
  );
}

void main() {
  testWidgets(
    'shows all 3 events, standings sorted best-first, and calls out an '
    'own-roster win (2026-08-10, TODO.md item 6)',
    (tester) async {
      // All 3 event cards, standings and all, no longer fit the default
      // test surface now that Full Press Frenzy's tagline makes its card
      // taller -- same fix the "tapping a standing row" test below already
      // uses for the same reason.
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final rival = playerWithOverall(80, id: 'rival-1', name: 'Rival One');
      final roster = generateStartingRoster(1);
      final ownPlayer = roster.first.player;

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
        league: _leagueWithRival(
          testLeague(
            simulationSeed: 1,
            replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
          ),
          rival,
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

      final result = SkillsCompetitionResult(
        week: 19,
        squads: {
          Conference.atlantic: _squadOf('atl', [ownPlayer.id, rival.id]),
          Conference.pacific: _squadOf('pac', const []),
        },
        events: [
          SkillsEventResult(
            event: SkillsEvent.fullPressFrenzy,
            standings: [
              SkillsEventStanding(playerId: ownPlayer.id, score: 90),
              SkillsEventStanding(playerId: rival.id, score: 70),
            ],
          ),
          SkillsEventResult(
            event: SkillsEvent.horse,
            standings: [
              SkillsEventStanding(playerId: rival.id, score: 85),
              SkillsEventStanding(playerId: ownPlayer.id, score: 60),
            ],
          ),
          SkillsEventResult(
            event: SkillsEvent.defensiveSkillsChallenge,
            standings: [
              SkillsEventStanding(playerId: rival.id, score: 95),
              SkillsEventStanding(playerId: ownPlayer.id, score: 50),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SkillsCompetitionResultScreen(
            franchise: franchise,
            result: result,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Skills Competition'), findsOneWidget);
      expect(find.text('Full Press Frenzy'), findsOneWidget);
      expect(find.text('H-O-R-S-E'), findsOneWidget);
      expect(find.text('Defensive Skills Challenge'), findsOneWidget);
      // The GM's own player won the shootout -- called out at the top.
      expect(
        find.text('Your player won the Full Press Frenzy!'),
        findsOneWidget,
      );
      // Each name is followed by the player's own team abbreviation
      // (2026-08-11, a direct GM ask) -- so these look for the whole
      // "Name (ABB)" label, not a bare name.
      final ownLabel =
          '${ownPlayer.name} (${kLeagueTeamPool.first.abbreviation})';
      final rivalLabel =
          'Rival One (${franchise.league.aiTeams.first.team.abbreviation})';
      expect(find.text(ownLabel), findsWidgets);
      expect(find.text(rivalLabel), findsWidgets);
      // Highest score sorts first within an event.
      final shootoutWinnerY = tester.getTopLeft(find.text(ownLabel).first).dy;
      final shootoutRunnerUpY = tester
          .getTopLeft(find.text(rivalLabel).first)
          .dy;
      expect(shootoutWinnerY, lessThan(shootoutRunnerUpY));
    },
  );

  testWidgets('no own-win banner when the GM has no honorees in the field', (
    tester,
  ) async {
    final roster = generateStartingRoster(1);
    final a = playerWithOverall(80, id: 'a', name: 'Player A');
    final b = playerWithOverall(75, id: 'b', name: 'Player B');

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

    final result = SkillsCompetitionResult(
      week: 19,
      squads: {
        Conference.atlantic: _squadOf('atl', [a.id, b.id]),
        Conference.pacific: _squadOf('pac', const []),
      },
      events: [
        SkillsEventResult(
          event: SkillsEvent.fullPressFrenzy,
          standings: [
            SkillsEventStanding(playerId: a.id, score: 90),
            SkillsEventStanding(playerId: b.id, score: 70),
          ],
        ),
        SkillsEventResult(
          event: SkillsEvent.horse,
          standings: [
            SkillsEventStanding(playerId: a.id, score: 90),
            SkillsEventStanding(playerId: b.id, score: 70),
          ],
        ),
        SkillsEventResult(
          event: SkillsEvent.defensiveSkillsChallenge,
          standings: [
            SkillsEventStanding(playerId: a.id, score: 90),
            SkillsEventStanding(playerId: b.id, score: 70),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SkillsCompetitionResultScreen(
          franchise: franchise,
          result: result,
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Your player'), findsNothing);
    expect(find.textContaining('Your players'), findsNothing);
  });

  testWidgets('tapping a standing row opens that player\'s detail screen '
      '(2026-08-11, a direct GM ask -- "I want to be able to click players '
      'and see detail screen")', (tester) async {
    // The rival's row is below the fold at the default test surface size.
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final rival = playerWithOverall(80, id: 'rival-1', name: 'Rival One');
    final roster = generateStartingRoster(1);
    final ownPlayer = roster.first.player;

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
      league: _leagueWithRival(
        testLeague(
          simulationSeed: 1,
          replacedTeamAbbreviation: kLeagueTeamPool.first.abbreviation,
        ),
        rival,
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

    final result = SkillsCompetitionResult(
      week: 19,
      squads: {
        Conference.atlantic: _squadOf('atl', [ownPlayer.id, rival.id]),
        Conference.pacific: _squadOf('pac', const []),
      },
      events: [
        SkillsEventResult(
          event: SkillsEvent.fullPressFrenzy,
          standings: [
            SkillsEventStanding(playerId: ownPlayer.id, score: 90),
            SkillsEventStanding(playerId: rival.id, score: 70),
          ],
        ),
        SkillsEventResult(
          event: SkillsEvent.horse,
          standings: [
            SkillsEventStanding(playerId: ownPlayer.id, score: 90),
            SkillsEventStanding(playerId: rival.id, score: 70),
          ],
        ),
        SkillsEventResult(
          event: SkillsEvent.defensiveSkillsChallenge,
          standings: [
            SkillsEventStanding(playerId: ownPlayer.id, score: 90),
            SkillsEventStanding(playerId: rival.id, score: 70),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: SkillsCompetitionResultScreen(
            franchise: franchise,
            result: result,
          ),
        ),
      ),
    );
    await tester.pump();

    final rivalAbbreviation = franchise.league.aiTeams.first.team.abbreviation;
    await tester.tap(find.text('Rival One ($rivalAbbreviation)').first);
    await tester.pumpAndSettle();

    // "Ratings" is unique to `PlayerDetailScreen` -- neither result
    // screen has a section by that name.
    expect(find.text('Ratings'), findsOneWidget);
    expect(find.text('Player Not Found'), findsNothing);
  });
}
