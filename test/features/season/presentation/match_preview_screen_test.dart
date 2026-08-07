import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/core/persistence/save_envelope.dart';
import 'package:womensbballmgr/core/persistence/save_repository_provider.dart';
import 'package:womensbballmgr/features/franchise/application/current_franchise_provider.dart';
import 'package:womensbballmgr/features/franchise/domain/franchise.dart';
import 'package:womensbballmgr/features/franchise/onboarding/expansion_franchise_factory.dart';
import 'package:womensbballmgr/features/franchise/persistence/franchise_json.dart';
import 'package:womensbballmgr/features/league/domain/team.dart';
import 'package:womensbballmgr/features/roster/domain/team_overall.dart';
import 'package:womensbballmgr/features/season/application/franchise_rosters.dart';
import 'package:womensbballmgr/features/season/domain/game_day.dart';
import 'package:womensbballmgr/features/season/domain/scheduled_game.dart';
import 'package:womensbballmgr/features/season/domain/season_progress.dart';
import 'package:womensbballmgr/features/season/domain/season_schedule.dart';
import 'package:womensbballmgr/features/season/presentation/match_preview_screen.dart';

import '../../../support/franchise_test_helpers.dart';
import '../../../support/in_memory_save_repository.dart';

Franchise _newFranchise() => withFullActiveRoster(
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

/// [franchise] with its next (and only) game day being a single [type]
/// game between the GM's own team and [opponent] -- exactly the shape
/// `MatchPreviewScreen` expects to be handed.
Franchise _withOwnGameToday(
  Franchise franchise,
  Team opponent, {
  GameType type = GameType.regularSeason,
  int week = 2,
}) {
  return franchise.copyWithSeasonProgress(
    SeasonProgress(
      schedule: SeasonSchedule(
        games: [
          ScheduledGame(
            week: week,
            day: GameDay.sunday,
            homeTeamAbbreviation: franchise.team.abbreviation,
            awayTeamAbbreviation: opponent.abbreviation,
            type: type,
          ),
        ],
      ),
      playedGames: const [],
      nextGameDayIndex: 0,
    ),
  );
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
  testWidgets(
    'shows both teams\' name, record, and team overall, with a Play Game '
    'button',
    (tester) async {
      final base = _newFranchise();
      final opponent = base.league.aiTeams.first.team;
      final franchise = _withOwnGameToday(base, opponent);
      final game = franchise.seasonProgress.schedule.games.single;
      final rosters = rostersByAbbreviation(franchise);
      final repository = await _seededRepository(franchise);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [saveRepositoryProvider.overrideWithValue(repository)],
          child: MaterialApp(
            home: MatchPreviewScreen(franchise: franchise, game: game),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Next Game'), findsOneWidget);
      expect(find.text('Regular Season'), findsOneWidget);
      expect(find.text(franchise.team.name), findsOneWidget);
      expect(find.text(opponent.name), findsOneWidget);
      expect(
        find.textContaining(
          '${teamOverallForPlayers(rosters[franchise.team.abbreviation]!)} OVR',
        ),
        findsOneWidget,
      );
      // No games played yet -- both teams show 0-0.
      expect(find.text('0-0'), findsNWidgets(2));
      expect(find.text('Play Game'), findsOneWidget);
    },
  );

  testWidgets(
    'a preseason game notes that it doesn\'t count toward the record',
    (tester) async {
      final base = _newFranchise();
      final opponent = base.league.aiTeams.first.team;
      final franchise = _withOwnGameToday(
        base,
        opponent,
        type: GameType.preseason,
        week: 1,
      );
      final game = franchise.seasonProgress.schedule.games.single;
      final repository = await _seededRepository(franchise);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [saveRepositoryProvider.overrideWithValue(repository)],
          child: MaterialApp(
            home: MatchPreviewScreen(franchise: franchise, game: game),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Preseason'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping Play Game simulates the game and hands off to the result',
    (tester) async {
      final base = _newFranchise();
      final opponent = base.league.aiTeams.first.team;
      final franchise = _withOwnGameToday(base, opponent);
      final game = franchise.seasonProgress.schedule.games.single;
      final repository = await _seededRepository(franchise);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [saveRepositoryProvider.overrideWithValue(repository)],
          child: MaterialApp(
            home: MatchPreviewScreen(franchise: franchise, game: game),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Play Game'));
      await tester.pumpAndSettle();

      expect(find.text('Game Result'), findsOneWidget);
      expect(find.text('FINAL'), findsOneWidget);

      final saved = await repository.readSave(kCurrentFranchiseSaveId);
      final savedFranchise = franchiseFromJson(
        SaveEnvelope.fromJson(saved!).payload,
      );
      expect(savedFranchise.seasonProgress.nextGameDayIndex, 1);
      expect(savedFranchise.seasonProgress.playedGames, hasLength(1));
    },
  );
}
