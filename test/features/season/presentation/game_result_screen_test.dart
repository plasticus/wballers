import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/core/persistence/save_repository_provider.dart';
import 'package:womensbballmgr/features/franchise/domain/injury_report_entry.dart';
import 'package:womensbballmgr/features/franchise/onboarding/expansion_franchise_factory.dart';
import 'package:womensbballmgr/features/league/domain/team.dart';
import 'package:womensbballmgr/features/match/engine/match_engine.dart';
import 'package:womensbballmgr/features/matchup/domain/defensive_tactic.dart';
import 'package:womensbballmgr/features/player/domain/player_injury.dart';
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
          home: GameResultScreen(
            franchise: franchise,
            result: result,
            ownDefenseTactic: DefensiveTactic.balanced,
          ),
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

  testWidgets('shows both teams\' Offensive Shape and the GM\'s own Defensive '
      'Tactic (2026-08-20, TODO.md item 7: "the GM picks a tactic pre-game '
      'and it\'s applied for real, but nothing on GameResultScreen '
      'afterward says which one was used")', (tester) async {
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
          home: GameResultScreen(
            franchise: franchise,
            result: result,
            ownDefenseTactic: DefensiveTactic.packThePaint,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Offensive Shape'), findsOneWidget);
    expect(find.textContaining(franchise.team.abbreviation), findsWidgets);
    expect(find.textContaining(opponent.abbreviation), findsWidgets);
    expect(
      find.text('Your Defensive Tactic: ${DefensiveTactic.packThePaint.label}'),
      findsOneWidget,
    );
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
            home: GameResultScreen(
              franchise: franchise,
              result: result,
              ownDefenseTactic: DefensiveTactic.balanced,
            ),
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

  testWidgets(
    'a preseason game is flagged plainly, no explanation (2026-08-07 GM '
    'ask -- "people know what that means")',
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
            home: GameResultScreen(
              franchise: franchise,
              result: result,
              ownDefenseTactic: DefensiveTactic.balanced,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Preseason'), findsOneWidget);
      expect(
        find.textContaining('doesn\'t count toward your record'),
        findsNothing,
      );
    },
  );

  testWidgets('a Continental Cup game is flagged plainly too, no explanation '
      '(2026-08-10, a direct GM ask: "if it\'s declared a Cup game, '
      'they\'ll figure it out")', (tester) async {
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
        week: 4,
        day: GameDay.sunday,
        homeTeamAbbreviation: franchise.team.abbreviation,
        awayTeamAbbreviation: opponent.abbreviation,
        type: GameType.continentalCup,
        continentalCupRound: 1,
      ),
      match: match,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          saveRepositoryProvider.overrideWithValue(InMemorySaveRepository()),
        ],
        child: MaterialApp(
          home: GameResultScreen(
            franchise: franchise,
            result: result,
            ownDefenseTactic: DefensiveTactic.balanced,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Continental Cup Round 1'), findsOneWidget);
    expect(
      find.textContaining('doesn\'t count toward your record'),
      findsNothing,
    );
  });

  testWidgets('the Advance button returns to whatever pushed this screen '
      '(2026-08-10, a direct GM ask)', (tester) async {
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
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => GameResultScreen(
                        franchise: franchise,
                        result: result,
                        ownDefenseTactic: DefensiveTactic.balanced,
                      ),
                    ),
                  ),
                  child: const Text('Open result'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open result'));
    await tester.pumpAndSettle();

    expect(find.text('Game Result'), findsOneWidget);
    final advanceButton = find.widgetWithText(FilledButton, 'Advance');
    expect(advanceButton, findsOneWidget);

    await tester.tap(advanceButton);
    await tester.pumpAndSettle();

    expect(find.text('Game Result'), findsNothing);
    expect(find.text('Open result'), findsOneWidget);
  });

  testWidgets(
    'a new injury from this exact game shows a loud alert above the box '
    'score (2026-08-20, a direct GM ask: "it absolutely needs to be on '
    'the game result screen... big and bold")',
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
      final withInjury = franchise.copyWithInjuryReports([
        InjuryReportEntry(
          playerId: 'hurt-1',
          name: 'Alex Rivera',
          teamAbbreviation: franchise.team.abbreviation,
          severity: InjurySeverity.moderate,
          week: 2,
          day: GameDay.sunday,
          season: 0,
        ),
      ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            saveRepositoryProvider.overrideWithValue(InMemorySaveRepository()),
          ],
          child: MaterialApp(
            home: GameResultScreen(
              franchise: withInjury,
              result: result,
              ownDefenseTactic: DefensiveTactic.balanced,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Injury Report'), findsOneWidget);
      expect(
        find.textContaining('Alex Rivera (${franchise.team.abbreviation})'),
        findsOneWidget,
      );
      expect(find.textContaining('Moderate injury'), findsOneWidget);
    },
  );

  testWidgets(
    'no alert when injuryReports has entries, but none from this exact '
    'game day',
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
      // A real injury, just from an earlier game day -- shouldn't bleed
      // into this later one's result screen.
      final withInjury = franchise.copyWithInjuryReports([
        InjuryReportEntry(
          playerId: 'hurt-1',
          name: 'Alex Rivera',
          teamAbbreviation: franchise.team.abbreviation,
          severity: InjurySeverity.moderate,
          week: 1,
          day: GameDay.sunday,
          season: 0,
        ),
      ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            saveRepositoryProvider.overrideWithValue(InMemorySaveRepository()),
          ],
          child: MaterialApp(
            home: GameResultScreen(
              franchise: withInjury,
              result: result,
              ownDefenseTactic: DefensiveTactic.balanced,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Injury Report'), findsNothing);
    },
  );
}
