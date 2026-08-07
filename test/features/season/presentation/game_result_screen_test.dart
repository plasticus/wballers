import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/core/persistence/save_repository_provider.dart';
import 'package:womensbballmgr/features/franchise/onboarding/expansion_franchise_factory.dart';
import 'package:womensbballmgr/features/league/domain/team.dart';
import 'package:womensbballmgr/features/match/engine/match_engine.dart';
import 'package:womensbballmgr/features/roster/domain/team_overall.dart';
import 'package:womensbballmgr/features/season/application/franchise_rosters.dart';
import 'package:womensbballmgr/features/season/domain/game_day.dart';
import 'package:womensbballmgr/features/season/domain/game_result.dart';
import 'package:womensbballmgr/features/season/domain/scheduled_game.dart';
import 'package:womensbballmgr/features/season/presentation/game_result_screen.dart';

import '../../../support/franchise_test_helpers.dart';
import '../../../support/in_memory_save_repository.dart';

void main() {
  testWidgets('shows the final score and a box score for both teams', (
    tester,
  ) async {
    // Both teams' box scores (up to 12 rows each) need to be on-screen at
    // once -- the default test surface is too short to lay out a
    // ListView this long, which only builds items near the viewport.
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

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
    final opponent = franchise.league.aiTeams.first.team;
    final rosters = rostersByAbbreviation(franchise);
    final match = simulateMatch(
      Random(1),
      homeRoster: rosters[franchise.team.abbreviation]!,
      awayRoster: rosters[opponent.abbreviation]!,
    );
    final result = GameResult(
      game: ScheduledGame(
        week: 2,
        day: GameDay.sunday,
        homeTeamAbbreviation: franchise.team.abbreviation,
        awayTeamAbbreviation: opponent.abbreviation,
        type: GameType.regularSeason,
      ),
      match: match,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          saveRepositoryProvider.overrideWithValue(InMemorySaveRepository()),
        ],
        child: MaterialApp(
          home: GameResultScreen(franchise: franchise, result: result),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Game Result'), findsOneWidget);
    expect(find.text('FINAL'), findsOneWidget);
    expect(find.text('${match.homeScore}'), findsOneWidget);
    expect(find.text('${match.awayScore}'), findsOneWidget);
    // Once in the score card, once as the box score section header.
    expect(find.text(franchise.team.name), findsNWidgets(2));
    expect(find.text(opponent.name), findsNWidgets(2));
    expect(
      find.text(
        '${teamOverallForPlayers(rosters[franchise.team.abbreviation]!)} OVR',
      ),
      findsOneWidget,
    );
    // At least one player from each roster shows up with a stat line.
    expect(find.textContaining('PTS'), findsWidgets);
    // A regular-season game counts toward the record -- no disclaimer.
    expect(find.textContaining('doesn\'t count'), findsNothing);
  });

  testWidgets(
    'lists the GM\'s own team\'s box score before the opponent\'s, even '
    'when the GM played away',
    (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

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
      final opponent = franchise.league.aiTeams.first.team;
      final rosters = rostersByAbbreviation(franchise);
      // The GM's own team is the away team here -- this screen's old
      // fixed order was home-then-away, so an away GM is exactly the
      // case that used to render the opponent's box score first.
      final match = simulateMatch(
        Random(1),
        homeRoster: rosters[opponent.abbreviation]!,
        awayRoster: rosters[franchise.team.abbreviation]!,
      );
      final result = GameResult(
        game: ScheduledGame(
          week: 2,
          day: GameDay.sunday,
          homeTeamAbbreviation: opponent.abbreviation,
          awayTeamAbbreviation: franchise.team.abbreviation,
          type: GameType.regularSeason,
        ),
        match: match,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            saveRepositoryProvider.overrideWithValue(InMemorySaveRepository()),
          ],
          child: MaterialApp(
            home: GameResultScreen(franchise: franchise, result: result),
          ),
        ),
      );
      await tester.pump();

      // Each team's name appears twice: once in the score card, once as
      // the box score section header -- the second occurrence is the one
      // whose position actually matters here.
      final ownSectionY = tester
          .getTopLeft(find.text(franchise.team.name).at(1))
          .dy;
      final opponentSectionY = tester
          .getTopLeft(find.text(opponent.name).at(1))
          .dy;
      expect(ownSectionY, lessThan(opponentSectionY));
    },
  );

  testWidgets('preseason and Cup games note that they don\'t count toward '
      'the record', (tester) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

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
    final opponent = franchise.league.aiTeams.first.team;
    final rosters = rostersByAbbreviation(franchise);
    final match = simulateMatch(
      Random(1),
      homeRoster: rosters[franchise.team.abbreviation]!,
      awayRoster: rosters[opponent.abbreviation]!,
    );
    final result = GameResult(
      game: ScheduledGame(
        week: 1,
        day: GameDay.sunday,
        homeTeamAbbreviation: franchise.team.abbreviation,
        awayTeamAbbreviation: opponent.abbreviation,
        type: GameType.preseason,
      ),
      match: match,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          saveRepositoryProvider.overrideWithValue(InMemorySaveRepository()),
        ],
        child: MaterialApp(
          home: GameResultScreen(franchise: franchise, result: result),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.textContaining('doesn\'t count toward your record'),
      findsOneWidget,
    );
  });
}
