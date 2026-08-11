import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/core/persistence/save_envelope.dart';
import 'package:womensbballmgr/core/persistence/save_repository_provider.dart';
import 'package:womensbballmgr/core/widgets/app_card.dart';
import 'package:womensbballmgr/features/franchise/application/current_franchise_provider.dart';
import 'package:womensbballmgr/features/franchise/domain/franchise.dart';
import 'package:womensbballmgr/features/franchise/onboarding/expansion_franchise_factory.dart';
import 'package:womensbballmgr/features/franchise/persistence/franchise_json.dart';
import 'package:womensbballmgr/features/league/domain/team.dart';
import 'package:womensbballmgr/features/season/application/franchise_rosters.dart';
import 'package:womensbballmgr/features/season/domain/scheduled_game.dart';
import 'package:womensbballmgr/features/season/generation/season_advancer.dart';
import 'package:womensbballmgr/features/stats/presentation/stats_screen.dart';

import '../../../support/franchise_test_helpers.dart';
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
  var franchise = withFullActiveRoster(_newFranchise());
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

  testWidgets(
    'tapping an MVP Race row opens that player\'s detail page, own roster '
    'or not (2026-08-11, TODO.md: "click on any player, from any team")',
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

      // `AppCard` is only ever used by a `_LeaderSection` on this screen --
      // the first one is the MVP Race section, regardless of which of it
      // and the other 2 tabs' content `TabBarView` has already built.
      final mvpCard = find.byType(AppCard).first;
      final firstRow = find
          .descendant(of: mvpCard, matching: find.byType(InkWell))
          .first;
      await tester.tap(firstRow);
      await tester.pumpAndSettle();

      // Landed on PlayerDetailScreen -- same "check the destination's own
      // content" pattern `team_roster_screen_test.dart`'s equivalent test
      // uses, rather than asserting the Stats screen's own text is gone.
      expect(find.text('This Season'), findsOneWidget);
      expect(find.text('Ratings'), findsOneWidget);
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
    'Teams tab never overflows, even at a realistic phone width and the '
    'app\'s max text-scale setting (2026-08-10, a direct GM bug report '
    'with a screenshot: stat columns running together, DIFF wrapping '
    'onto its own line, team names hard-truncated)',
    (tester) async {
      // A real phone's logical width, not the wide viewports used
      // elsewhere in this file to defeat ListView clipping -- this is
      // specifically about column collision/overflow at realistic width.
      tester.view.physicalSize = const Size(412, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final franchise = _franchiseWithRegularSeasonGames();
      final repository = await _seededRepository(franchise);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [saveRepositoryProvider.overrideWithValue(repository)],
          child: MaterialApp(
            // kMaxTextScale (app_preferences.dart) -- the top of the
            // combined system x coach-preference range this screen has
            // to hold up under.
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2.2)),
              child: child!,
            ),
            home: const Scaffold(body: StatsScreen()),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Teams'));
      await tester.pumpAndSettle();

      // No RenderFlex/RenderBox overflow assertion fired during layout.
      expect(tester.takeException(), isNull);
      // Every column is still there -- reachable (via the horizontal
      // scroll fallback if the coach's setting genuinely needs more
      // width than the screen has), not silently dropped or clipped
      // out of the tree.
      expect(find.text('W-L'), findsOneWidget);
      expect(find.text('PPG'), findsOneWidget);
      expect(find.text('OPP'), findsOneWidget);
      expect(find.text('DIFF'), findsOneWidget);
    },
  );

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

  testWidgets('tapping a Roster tab row opens that player\'s detail page '
      '(2026-08-11, TODO.md: "click on any player, from any team")', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final franchise = _franchiseWithRegularSeasonGames();
    final repository = await _seededRepository(franchise);
    final targetName = franchise.roster.first.player.name;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [saveRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: Scaffold(body: StatsScreen())),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Roster'));
    await tester.pumpAndSettle();

    final row = find.ancestor(
      of: find.textContaining(targetName),
      matching: find.byType(InkWell),
    );
    await tester.tap(row.first);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, targetName), findsOneWidget);
    expect(find.text('This Season'), findsOneWidget);
  });
}
