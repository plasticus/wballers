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
import 'package:womensbballmgr/features/portrait/domain/portrait_weights.dart';
import 'package:womensbballmgr/features/season/domain/game_day.dart';
import 'package:womensbballmgr/features/season/domain/played_game.dart';
import 'package:womensbballmgr/features/season/domain/scheduled_game.dart';
import 'package:womensbballmgr/features/season/domain/season_progress.dart';
import 'package:womensbballmgr/features/season/domain/season_schedule.dart';
import 'package:womensbballmgr/features/season/presentation/match_preview_screen.dart';

import '../../../support/franchise_test_helpers.dart';
import '../../../support/in_memory_save_repository.dart';

/// Minimal but real -- enough for `generatePortraitAppearance` to produce
/// a non-null appearance for every generated player/coach, which several
/// tests below need: the narrative veteran's own portrait only survives
/// her leaving the roster if she was generated with one in the first
/// place (`Franchise.narrativeVeteranAppearance`'s own doc comment).
final _portraitWeights = PortraitWeights(
  skinTone: const {'medium': 1},
  hairColorByTone: const {
    'medium': {'black': 1},
  },
  hair: const {'hair_afro': 1},
  neonHair: const {'natural': 1},
  eyes: const {'eyes_1center': 1},
  nose: const {'nose_1': 1},
  mouth: const {'mouth_1': 1},
  eyebrows: const {'eyebrow_1': 1},
  facial: const {'none': 1},
  accessories: const {'none': 1},
);

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
    portraitWeights: _portraitWeights,
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
  testWidgets('shows both teams\' name, record, form, and a Play Game button', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

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

    expect(find.text('Matchup Analysis'), findsOneWidget);
    expect(find.textContaining('Regular Season'), findsOneWidget);
    expect(find.text(franchise.team.name), findsOneWidget);
    expect(find.text(opponent.name), findsOneWidget);
    // No games played yet -- both teams show 0-0, no form dots.
    expect(find.text('0-0'), findsNWidgets(2));
    expect(find.text('Play Game'), findsOneWidget);
  });

  testWidgets(
    'a preseason game notes that it doesn\'t count toward the record',
    (tester) async {
      tester.view.physicalSize = const Size(900, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

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

      expect(find.textContaining('Preseason'), findsOneWidget);
    },
  );

  testWidgets(
    'shows Team Strength, Top 3 Head to Head, and all 5 named analysts '
    'with a final tally',
    (tester) async {
      tester.view.physicalSize = const Size(900, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

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
      await tester.pump(); // portraits resolve async, one more frame

      expect(find.text('Team Strength'), findsOneWidget);
      expect(find.text('Offense'), findsOneWidget);
      expect(find.text('Defense'), findsOneWidget);
      expect(find.text('Physical'), findsOneWidget);

      expect(find.text('Top Contributors'), findsOneWidget);
      expect(find.textContaining('OVR'), findsWidgets);
      expect(find.textContaining('points'), findsWidgets);

      expect(find.text('The Analysts'), findsOneWidget);
      // The 4 fixed panelists always show, by name, regardless of
      // franchise -- seat 1 ("Preston") is covered by its own dedicated
      // tests below since it depends on the narrative veteran's status.
      expect(find.text('Reyes'), findsOneWidget);
      expect(find.text('Shoemaker'), findsOneWidget);
      expect(find.text('Adebayo'), findsOneWidget);
      expect(find.text('Vale-Jones'), findsOneWidget);
      // A tally reading "<emoji> <n> — <n> <emoji>" for exactly 5 picks.
      expect(find.textContaining(franchise.team.emoji), findsWidgets);
    },
  );

  testWidgets(
    'seat 1 shows the generic "Preston" look while the narrative veteran '
    'is still on the roster',
    (tester) async {
      tester.view.physicalSize = const Size(900, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final base = _newFranchise();
      final opponent = base.league.aiTeams.first.team;
      final franchise = _withOwnGameToday(base, opponent);
      final game = franchise.seasonProgress.schedule.games.single;
      final repository = await _seededRepository(franchise);

      // Sanity check the fixture actually has what this test means to
      // exercise: the veteran is still on the roster.
      expect(
        franchise.roster.any(
          (m) => m.player.id == franchise.narrativeVeteranPlayerId,
        ),
        isTrue,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [saveRepositoryProvider.overrideWithValue(repository)],
          child: MaterialApp(
            home: MatchPreviewScreen(franchise: franchise, game: game),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      // Not asserting her real name is absent from the screen entirely --
      // at 87 OVR she's a genuinely great player and can legitimately
      // show up in Top 3, Head to Head; this only checks the Analyst
      // seat itself still shows the generic look.
      expect(find.text('Preston'), findsOneWidget);
    },
  );

  testWidgets(
    'seat 1 shows the narrative veteran\'s own name once she has retired '
    '(no longer found on the roster)',
    (tester) async {
      tester.view.physicalSize = const Size(900, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final base = _newFranchise();
      final opponent = base.league.aiTeams.first.team;
      final withGame = _withOwnGameToday(base, opponent);
      // "Retire" the narrative veteran -- drop her from the roster the
      // same way `resolvePendingRetirement`'s `_retirePlayer` does, while
      // her id/name/appearance stay snapshotted on the franchise itself.
      final franchise = withGame.copyWithRoster([
        for (final membership in withGame.roster)
          if (membership.player.id != withGame.narrativeVeteranPlayerId)
            membership,
      ]);
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
      await tester.pump();

      expect(find.text(franchise.narrativeVeteranName), findsOneWidget);
      expect(find.text('Preston'), findsNothing);
    },
  );

  testWidgets(
    'form-streak dots reflect real recent results, not just a 0-0 record',
    (tester) async {
      tester.view.physicalSize = const Size(900, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final base = _newFranchise();
      final opponent = base.league.aiTeams.first.team;
      final withGame = _withOwnGameToday(base, opponent, week: 3);
      final ownAbbreviation = withGame.team.abbreviation;

      // One already-played win for the GM's own team, in an earlier week
      // than the previewed game.
      final priorGame = ScheduledGame(
        week: 1,
        day: GameDay.sunday,
        homeTeamAbbreviation: ownAbbreviation,
        awayTeamAbbreviation: opponent.abbreviation,
        type: GameType.regularSeason,
      );
      final franchise = withGame.copyWithSeasonProgress(
        SeasonProgress(
          schedule: SeasonSchedule(
            games: [priorGame, ...withGame.seasonProgress.schedule.games],
          ),
          playedGames: [
            PlayedGame(game: priorGame, homeScore: 80, awayScore: 60),
          ],
          nextGameDayIndex: 1,
        ),
      );
      final game = franchise.seasonProgress.schedule.games.last;
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

      // The GM's own team is now 1-0; the opponent lost that same game
      // (as the away side), so they're 0-1, not an untouched 0-0.
      expect(find.text('1-0'), findsOneWidget);
      expect(find.text('0-1'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping Play Game simulates the game and hands off to the result',
    (tester) async {
      tester.view.physicalSize = const Size(900, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

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
