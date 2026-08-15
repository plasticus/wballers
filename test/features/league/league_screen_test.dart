import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/core/persistence/save_envelope.dart';
import 'package:womensbballmgr/core/persistence/save_repository_provider.dart';
import 'package:womensbballmgr/core/widgets/wbl_logo.dart';
import 'package:womensbballmgr/features/coach/domain/coach.dart';
import 'package:womensbballmgr/features/coach/domain/coach_archetype.dart';
import 'package:womensbballmgr/features/coach/domain/coach_stats.dart';
import 'package:womensbballmgr/features/franchise/application/current_franchise_provider.dart';
import 'package:womensbballmgr/features/franchise/domain/franchise.dart';
import 'package:womensbballmgr/features/franchise/onboarding/expansion_franchise_factory.dart';
import 'package:womensbballmgr/features/franchise/persistence/franchise_json.dart';
import 'package:womensbballmgr/features/league/domain/initial_league.dart';
import 'package:womensbballmgr/features/league/domain/league_draw.dart';
import 'package:womensbballmgr/features/league/domain/team.dart';
import 'package:womensbballmgr/features/league/league_screen.dart';
import 'package:womensbballmgr/features/roster/domain/roster_status.dart';
import 'package:womensbballmgr/features/season/domain/game_day.dart';
import 'package:womensbballmgr/features/roster/domain/team_overall.dart';
import 'package:womensbballmgr/features/season/application/franchise_rosters.dart';
import 'package:womensbballmgr/features/season/generation/season_advancer.dart';
import 'package:womensbballmgr/features/season/generation/season_schedule_generator.dart'
    show weekLabel;
import 'package:womensbballmgr/features/training/domain/training_plan.dart';
import 'package:womensbballmgr/features/roster/generation/starting_roster_generator.dart';

import '../../support/franchise_test_helpers.dart';
import '../../support/in_memory_save_repository.dart';
import '../../support/league_test_helpers.dart';
import '../../support/season_test_helpers.dart';
import '../../support/training_test_helpers.dart';

Future<void> _pumpWithRepository(
  WidgetTester tester,
  InMemorySaveRepository repository,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [saveRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(home: LeagueScreen()),
    ),
  );
  await tester.pump();
}

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

/// Advances until Continental Cup Round 2 has been generated -- proof the
/// Cup tab's "upcoming round matches" ask actually shows a real Round 2
/// matchup once one exists, not just Round 1's.
Franchise _franchiseThroughContinentalCupRound1() {
  var franchise = withFullActiveRoster(_newFranchise());
  var progress = franchise.seasonProgress;
  for (var i = 0; i < 15; i++) {
    if (progress.schedule.games.any((g) => g.continentalCupRound == 2)) {
      break;
    }
    final advance = advanceToNextGameDay(
      Random(franchise.simulationSeed + kSeasonAdvanceSeedOffset + i),
      progress,
      rostersByAbbreviation: rostersByAbbreviation(franchise),
    );
    progress = advance.progress;
  }
  return franchise.copyWithSeasonProgress(progress);
}

Future<InMemorySaveRepository> _seededRepository(Franchise franchise) async {
  final repository = InMemorySaveRepository();
  await repository.writeSave(
    kCurrentFranchiseSaveId,
    SaveEnvelope(
      schemaVersion: 1,
      payload: franchiseToJson(franchise),
    ).toJson(),
  );
  return repository;
}

void main() {
  testWidgets('with no franchise, prompts to create one', (tester) async {
    await _pumpWithRepository(tester, InMemorySaveRepository());

    expect(
      find.text('Create an expansion franchise to see your league.'),
      findsOneWidget,
    );
    expect(find.text('Create Expansion Franchise'), findsOneWidget);
  });

  testWidgets(
    'with a franchise, lists this playthrough\'s drawn 20-team league, '
    'with the replaced team swapped for the GM club',
    (tester) async {
      const simulationSeed = 1;
      final drawnTeams = drawLeagueTeams(
        Random(simulationSeed + kLeagueDrawSeedOffset),
      );
      final replaced = drawnTeams.firstWhere(
        (team) => team.conference == Conference.atlantic,
      );
      const clubTeam = Team(
        abbreviation: 'BRS',
        location: 'New Orleans, LA',
        name: 'New Orleans Brass',
        conference: Conference.atlantic,
        colors: TeamColors(
          primaryHex: '#14213D',
          secondaryHex: '#FCA311',
          accentHex: '#E5E5E5',
        ),
        identityNote: 'A new franchise chasing its first banner.',
        emoji: '🏀',
      );
      final roster = generateStartingRoster(1);
      final franchise = Franchise(
        id: 'franchise-1',
        gmName: 'Taylor Reed',
        team: clubTeam,
        coach: const Coach(
          name: 'Jordan Ellis',
          stats: CoachStats.neutral,
          archetype: CoachArchetype.steadyHand,
        ),
        roster: roster,
        simulationSeed: simulationSeed,
        replacedTeamAbbreviation: replaced.abbreviation,
        league: testLeague(
          simulationSeed: simulationSeed,
          replacedTeamAbbreviation: replaced.abbreviation,
        ),
        seasonProgress: testSeasonProgress(
          simulationSeed: simulationSeed,
          replacedTeamAbbreviation: replaced.abbreviation,
          ownTeam: clubTeam,
        ),
        trainingCoaches: testTrainingCoaches(),
        trainingPlan: TrainingPlan.initial(),
        nextTrainingWeek: 1,
      );

      final repository = InMemorySaveRepository();
      await repository.writeSave(
        kCurrentFranchiseSaveId,
        SaveEnvelope(
          schemaVersion: 1,
          payload: franchiseToJson(franchise),
        ).toJson(),
      );

      await _pumpWithRepository(tester, repository);

      expect(find.text(clubTeam.name), findsOneWidget);
      // Row highlight instead of a "Your Team" text badge (2026-08-09) --
      // `team_row_test.dart` covers the highlight/announcement itself in
      // isolation; here it's enough to confirm the badge text is gone.
      expect(find.text('Your Team'), findsNothing);
      expect(find.text(replaced.name), findsNothing);
      final activePlayers = [
        for (final m in roster)
          if (m.status == RosterStatus.active) m.player,
      ];
      // The club's own row text, not just a bare "NN OVR" substring --
      // a generated AI team can coincidentally land on the same overall,
      // and a page-wide OVR-only search would then flag a false failure
      // even though the club's own row rendered exactly right.
      expect(
        find.text(
          '${clubTeam.abbreviation} · ${clubTeam.location} · '
          '${teamOverallForPlayers(activePlayers)} OVR',
        ),
        findsOneWidget,
      );

      // Every other drawn Atlantic team is still listed untouched.
      final otherAtlanticTeams = drawnTeams.where(
        (team) =>
            team.conference == Conference.atlantic &&
            team.abbreviation != replaced.abbreviation,
      );
      for (final team in otherAtlanticTeams) {
        expect(find.text(team.name), findsOneWidget);
      }

      // The drawn Pacific half is below the fold in the test viewport.
      // `find.byType(Scrollable)` now matches 2 -- the tab view's own
      // horizontal `PageView` alongside the Regular Season tab's vertical
      // `ListView` -- `.last` is the nested, vertical one that actually
      // needs scrolling.
      await tester.scrollUntilVisible(
        find.text('Pacific Conference'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      final pacificTeams = drawnTeams.where(
        (team) => team.conference == Conference.pacific,
      );
      for (final team in pacificTeams) {
        expect(find.text(team.name), findsOneWidget);
      }

      // No games played yet -- every team shows a 0-0 record.
      expect(find.text('0-0'), findsNWidgets(20));
    },
  );

  testWidgets('"Schedule" and "Results" open their respective screens', (
    tester,
  ) async {
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
    final repository = InMemorySaveRepository();
    await repository.writeSave(
      kCurrentFranchiseSaveId,
      SaveEnvelope(
        schemaVersion: 1,
        payload: franchiseToJson(franchise),
      ).toJson(),
    );

    await _pumpWithRepository(tester, repository);

    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();
    expect(find.text('No games scheduled yet.'), findsNothing);
    expect(find.widgetWithText(AppBar, 'Schedule'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Results'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Results'), findsOneWidget);
    expect(find.text('No games played yet.'), findsOneWidget);
  });

  testWidgets(
    'the Cup tab lists Round 1 as upcoming and later rounds as not yet '
    'determined',
    (tester) async {
      // Round 1's 10 games plus the 4 "not yet determined" placeholders
      // for every later round all need to be on-screen at once -- a plain
      // `ListView` (like every other list in this codebase) only mounts
      // elements near the viewport, and the default test surface isn't
      // tall enough to hold all of that.
      tester.view.physicalSize = const Size(800, 4500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final franchise = _newFranchise();
      final repository = await _seededRepository(franchise);
      await _pumpWithRepository(tester, repository);

      // The header starts on the plain WBL crest -- the Cup tab isn't
      // selected yet.
      expect(find.byType(WblLogo), findsOneWidget);
      expect(find.byType(ContinentalCupLogo), findsNothing);

      await tester.tap(find.text('Cup'));
      await tester.pumpAndSettle();

      // Selecting the Cup tab swaps the header crest for the Cup's own --
      // a direct GM ask, not just a decorative nicety.
      expect(find.byType(WblLogo), findsNothing);
      expect(find.byType(ContinentalCupLogo), findsOneWidget);

      // Each round header names its game week too (2026-08-15, a direct
      // GM ask -- "Round 1 (Week 4)" or similar).
      expect(
        find.text('Round 1 (${weekLabel(continentalCupRoundWeek(1))})'),
        findsOneWidget,
      );
      // Round 1 is always generated up front (`generateSeasonSchedule`) --
      // 10 games, none played yet, each showing its real scheduled date
      // (2026-08-10, a direct GM ask -- "instead of 'Upcoming', put the
      // actual date of the game") rather than a generic "Upcoming" label.
      expect(find.text('Upcoming'), findsNothing);
      final round1Games = franchise.seasonProgress.schedule.games.where(
        (g) => g.continentalCupRound == 1,
      );
      expect(round1Games, hasLength(10));
      for (final game in round1Games) {
        expect(
          find.text(formatFictionalDate(game.week, game.day)),
          findsWidgets,
        );
      }
      // Every later round is a real header (with its own week number,
      // even before its games exist) and a "not decided yet" placeholder
      // underneath it, not a gap in the list.
      expect(
        find.text('Round 2 (${weekLabel(continentalCupRoundWeek(2))})'),
        findsOneWidget,
      );
      expect(find.text('Set once Round 1 finishes.'), findsOneWidget);
      expect(
        find.text('Quarterfinals (${weekLabel(continentalCupRoundWeek(3))})'),
        findsOneWidget,
      );
      expect(find.text('Set once Round 2 finishes.'), findsOneWidget);
      expect(
        find.text('Semifinals (${weekLabel(continentalCupRoundWeek(4))})'),
        findsOneWidget,
      );
      expect(find.text('Set once Quarterfinals finishes.'), findsOneWidget);
      expect(
        find.text('Final (${weekLabel(continentalCupRoundWeek(5))})'),
        findsOneWidget,
      );
      expect(find.text('Set once Semifinals finishes.'), findsOneWidget);
    },
  );

  testWidgets(
    'the Cup tab shows real Round 2 matchups once Round 1 is played',
    (tester) async {
      tester.view.physicalSize = const Size(800, 4500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final franchise = _franchiseThroughContinentalCupRound1();
      final repository = await _seededRepository(franchise);
      await _pumpWithRepository(tester, repository);

      await tester.tap(find.text('Cup'));
      await tester.pumpAndSettle();

      // Round 1 is fully played now (that's what generates Round 2), so
      // every one of its games shows a real score, not a date -- and
      // Round 2's placeholder is gone, replaced by its 2 real (still
      // unplayed, so date-labeled) games.
      expect(find.text('Set once Round 1 finishes.'), findsNothing);
      expect(find.text('Upcoming'), findsNothing);
      final round2Games = franchise.seasonProgress.schedule.games.where(
        (g) => g.continentalCupRound == 2,
      );
      expect(round2Games, hasLength(2));
      for (final game in round2Games) {
        expect(
          find.text(formatFictionalDate(game.week, game.day)),
          findsWidgets,
        );
      }
      // Round 3 depends on Round 2's results, which haven't happened yet
      // -- still the "not yet determined" placeholder.
      expect(find.text('Set once Round 2 finishes.'), findsOneWidget);
    },
  );

  testWidgets(
    'the Playoffs tab shows a placeholder before the regular season wraps '
    'up',
    (tester) async {
      final franchise = _newFranchise();
      final repository = await _seededRepository(franchise);
      await _pumpWithRepository(tester, repository);

      await tester.tap(find.text('Playoffs'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Playoffs begin once the regular season'),
        findsOneWidget,
      );
    },
  );
}
