import 'dart:math';

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
import 'package:womensbballmgr/features/season/application/franchise_rosters.dart';
import 'package:womensbballmgr/features/season/domain/scheduled_game.dart';
import 'package:womensbballmgr/features/season/generation/season_advancer.dart';
import 'package:womensbballmgr/features/stats/presentation/stats_screen.dart';

import '../../../support/in_memory_save_repository.dart';

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

/// Advances until at least one regular-season game day has been played --
/// the preseason's own 2 game days don't count toward any stat this
/// screen shows (`computeLeagueLeaders`/`computeStandings` both exclude
/// it), so a bare franchise with zero games advanced would show nothing
/// but empty states.
Franchise _franchiseWithRegularSeasonGames() {
  var franchise = _newFranchise();
  var progress = franchise.seasonProgress;
  for (var i = 0; i < 5; i++) {
    final advance = advanceToNextGameDay(
      Random(franchise.simulationSeed + kSeasonAdvanceSeedOffset + i),
      progress,
      rostersByAbbreviation: rostersByAbbreviation(franchise),
    );
    progress = advance.progress;
    if (progress.playedGames.any(
      (g) => g.game.type == GameType.regularSeason,
    )) {
      break;
    }
  }
  return franchise.copyWithSeasonProgress(progress);
}

Future<InMemorySaveRepository> _seededRepository(Franchise franchise) async {
  final repository = InMemorySaveRepository();
  final envelope = SaveEnvelope(
    schemaVersion: 1,
    payload: franchiseToJson(franchise),
  );
  await repository.writeSave(kCurrentFranchiseSaveId, envelope.toJson());
  return repository;
}

void main() {
  testWidgets('with no franchise, prompts to create one', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          saveRepositoryProvider.overrideWithValue(InMemorySaveRepository()),
        ],
        child: const MaterialApp(home: Scaffold(body: StatsScreen())),
      ),
    );
    await tester.pump();

    expect(
      find.text('Create an expansion franchise to see league stats.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'before any regular-season games, Leaders and Teams show an empty '
    'state',
    (tester) async {
      final franchise = _newFranchise();
      final repository = await _seededRepository(franchise);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [saveRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(home: Scaffold(body: StatsScreen())),
        ),
      );
      await tester.pump();

      expect(find.text('Leaders'), findsOneWidget);
      expect(find.text('Teams'), findsOneWidget);
      expect(find.text('Roster'), findsOneWidget);
      expect(
        find.textContaining('leaders show up once the season'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'once regular-season games are played, Leaders shows an MVP Race and '
    'per-category leaders',
    (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final franchise = _franchiseWithRegularSeasonGames();
      final repository = await _seededRepository(franchise);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [saveRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(home: Scaffold(body: StatsScreen())),
        ),
      );
      await tester.pump();

      expect(find.text('MVP Race'), findsOneWidget);
      expect(find.text('Points Per Game'), findsOneWidget);
      expect(find.text('Rebounds Per Game'), findsOneWidget);
      expect(find.text('Field Goal %'), findsOneWidget);
    },
  );

  testWidgets('Teams tab shows every league team\'s stat line', (tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final franchise = _franchiseWithRegularSeasonGames();
    final repository = await _seededRepository(franchise);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [saveRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: Scaffold(body: StatsScreen())),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Teams'));
    await tester.pumpAndSettle();

    expect(find.text('PPG'), findsOneWidget);
    expect(find.text(franchise.team.name), findsOneWidget);
  });

  testWidgets(
    'Roster tab defaults to the GM\'s own team and can switch to another',
    (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final franchise = _franchiseWithRegularSeasonGames();
      final repository = await _seededRepository(franchise);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [saveRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(home: Scaffold(body: StatsScreen())),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Roster'));
      await tester.pumpAndSettle();

      // Defaults to the GM's own team.
      expect(
        find.text('${franchise.team.emoji} ${franchise.team.name}'),
        findsWidgets,
      );

      // Switch to another team via the dropdown.
      final otherTeam = franchise.league.aiTeams.first.team;
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('${otherTeam.emoji} ${otherTeam.name}').last);
      await tester.pumpAndSettle();

      expect(find.text('${otherTeam.emoji} ${otherTeam.name}'), findsWidgets);
    },
  );
}
