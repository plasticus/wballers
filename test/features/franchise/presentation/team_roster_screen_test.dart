import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/core/persistence/save_envelope.dart';
import 'package:womensbballmgr/core/persistence/save_repository_provider.dart';
import 'package:womensbballmgr/features/coach/domain/coach.dart';
import 'package:womensbballmgr/features/coach/domain/coach_archetype.dart';
import 'package:womensbballmgr/features/coach/domain/coach_stats.dart';
import 'package:womensbballmgr/features/franchise/application/current_franchise_provider.dart';
import 'package:womensbballmgr/features/franchise/domain/franchise.dart';
import 'package:womensbballmgr/features/franchise/persistence/franchise_json.dart';
import 'package:womensbballmgr/features/franchise/presentation/team_roster_screen.dart';
import 'package:womensbballmgr/features/league/domain/initial_league.dart';
import 'package:womensbballmgr/features/player/domain/player.dart';
import 'package:womensbballmgr/features/player/domain/player_injury.dart';
import 'package:womensbballmgr/features/player/domain/trait.dart';
import 'package:womensbballmgr/features/roster/domain/roster_membership.dart';
import 'package:womensbballmgr/features/roster/domain/roster_status.dart';
import 'package:womensbballmgr/features/training/domain/training_plan.dart';
import 'package:womensbballmgr/features/roster/generation/starting_roster_generator.dart';

import '../../../support/in_memory_save_repository.dart';
import '../../../support/league_test_helpers.dart';
import '../../../support/season_test_helpers.dart';
import '../../../support/training_test_helpers.dart';
import '../../roster/domain/roster_test_helpers.dart';

Franchise _franchiseWith({
  List<RosterMembership>? extraMembers,
  List<Player> freeAgents = const [],
  List<RosterMembership>? overrideRoster,
}) {
  final roster =
      overrideRoster ?? [...generateStartingRoster(1), ...?extraMembers];
  return Franchise(
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
    freeAgents: freeAgents,
  );
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
        child: const MaterialApp(home: Scaffold(body: TeamRosterScreen())),
      ),
    );
    await tester.pump();

    expect(
      find.text('Create an expansion franchise to see your roster.'),
      findsOneWidget,
    );
    expect(find.text('Create Expansion Franchise'), findsOneWidget);
  });

  testWidgets('with a franchise, shows the team and the active roster', (
    tester,
  ) async {
    final franchise = _franchiseWith();
    final repository = await _seededRepository(franchise);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [saveRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: Scaffold(body: TeamRosterScreen())),
      ),
    );
    await tester.pump();

    expect(find.text(franchise.team.name), findsOneWidget);
    // 11, not 12 -- generateStartingRoster deliberately starts one
    // player short (see its own doc comment).
    expect(find.text('Active Roster (11)'), findsOneWidget);
    expect(
      find.textContaining(franchise.roster.first.player.name),
      findsOneWidget,
    );
  });

  testWidgets(
    'shows a Roster Legality Issue warning when the active roster is over '
    'the cap (2026-08-20, a direct GM ask: "I think we need to build in '
    'more notifications of roster legality")',
    (tester) async {
      final franchise = _franchiseWith(
        extraMembers: [
          RosterMembership(
            player: playerWithOverall(50),
            status: RosterStatus.active,
          ),
          RosterMembership(
            player: playerWithOverall(50),
            status: RosterStatus.active,
          ),
        ],
      );
      final repository = await _seededRepository(franchise);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [saveRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(home: Scaffold(body: TeamRosterScreen())),
        ),
      );
      await tester.pump();

      expect(find.text('Roster Legality Issue'), findsOneWidget);
      expect(find.textContaining('active roster has'), findsOneWidget);
    },
  );

  testWidgets(
    'omits the Roster Legality Issue warning when the roster is legal',
    (tester) async {
      final franchise = _franchiseWith();
      final repository = await _seededRepository(franchise);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [saveRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(home: Scaffold(body: TeamRosterScreen())),
        ),
      );
      await tester.pump();

      expect(find.text('Roster Legality Issue'), findsNothing);
    },
  );

  testWidgets(
    'the Calendar button opens TeamCalendarScreen (2026-08-15, a direct '
    'GM ask)',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final franchise = _franchiseWith();
      final repository = await _seededRepository(franchise);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [saveRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(home: Scaffold(body: TeamRosterScreen())),
        ),
      );
      await tester.pump();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Calendar'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Calendar'), findsOneWidget);
    },
  );

  testWidgets(
    'the sort dropdown reorders the Active Roster display -- picking OVR '
    'puts the roster\'s single highest-OVR player first',
    (tester) async {
      tester.view.physicalSize = const Size(800, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final franchise = _franchiseWith();
      final repository = await _seededRepository(franchise);
      final active = franchise.roster
          .where((m) => m.status == RosterStatus.active)
          .toList();
      final topByOverall =
          ([...active]..sort(
                (a, b) => b.player.ratings.overall.compareTo(
                  a.player.ratings.overall,
                ),
              ))
              .first
              .player;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [saveRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(home: Scaffold(body: TeamRosterScreen())),
        ),
      );
      await tester.pump();

      expect(find.text('Sort: Position'), findsOneWidget);
      await tester.tap(find.text('Sort: Position'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sort: OVR').last);
      await tester.pumpAndSettle();

      final topY = tester
          .getTopLeft(find.textContaining(topByOverall.name).first)
          .dy;
      for (final membership in active) {
        if (membership.player.id == topByOverall.id) continue;
        final y = tester
            .getTopLeft(find.textContaining(membership.player.name).first)
            .dy;
        expect(
          topY,
          lessThan(y),
          reason:
              '${topByOverall.name} (${topByOverall.ratings.overall} OVR) '
              'should be listed above ${membership.player.name} '
              '(${membership.player.ratings.overall} OVR) once sorted by '
              'OVR',
        );
      }
    },
  );

  testWidgets('marks exactly the top 5 in bench order (roster list order) as '
      'starters -- there\'s no separate starting-lineup concept anymore', (
    tester,
  ) async {
    // All 12 active roster rows (with portraits, trait chips, etc.) need
    // to be on-screen at once to count every starter badge -- the
    // default test surface is too short, and even 2400 wasn't enough.
    tester.view.physicalSize = const Size(800, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final franchise = _franchiseWith();
    final repository = await _seededRepository(franchise);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [saveRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: Scaffold(body: TeamRosterScreen())),
      ),
    );
    await tester.pump();

    // A "STARTER" text badge, not a star icon (2026-08-09) -- a lone star
    // read as a quality rating at a glance, since this app has a real
    // star-quality concept elsewhere.
    bool isStarterIcon(Widget widget) =>
        widget is Text && widget.data == 'STARTER';

    expect(find.byWidgetPredicate(isStarterIcon), findsNWidgets(5));
    // Specifically the first 5 in roster order, not e.g. the 5
    // highest-overall regardless of position -- proves this reads list
    // position, not some other ranking. Each player's row is wrapped in
    // an InkWell (the tap target to PlayerDetailScreen), the natural
    // "one row" boundary to search within.
    for (final membership in franchise.roster.take(5)) {
      final row = find.ancestor(
        of: find.textContaining(membership.player.name),
        matching: find.byType(InkWell),
      );
      expect(
        find.descendant(
          of: row.first,
          matching: find.byWidgetPredicate(isStarterIcon),
        ),
        findsOneWidget,
        reason: '${membership.player.name} should be marked a starter',
      );
    }
  });

  testWidgets('a developmental player shows up in the Development Slots '
      'section', (tester) async {
    final developmentalPlayer = generateStartingRoster(99).first.player;
    final franchise = _franchiseWith(
      extraMembers: [
        RosterMembership(
          player: developmentalPlayer,
          status: RosterStatus.developmental,
        ),
      ],
    );
    final repository = await _seededRepository(franchise);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [saveRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: Scaffold(body: TeamRosterScreen())),
      ),
    );
    await tester.pump();

    // The Development Slots section is below the fold behind 12
    // active-roster rows; the ListView only builds slivers near the
    // viewport.
    await tester.scrollUntilVisible(
      find.text('Development Slots (1/2)'),
      300,
      scrollable: find.byType(Scrollable),
    );

    expect(find.text('Development Slots (1/2)'), findsOneWidget);
  });

  testWidgets(
    'shows a player\'s experience and offense/defense/physical overalls '
    'as stat chips (Card Lab #11, the design the GM picked to ship)',
    (tester) async {
      final player = playerWithOverall(70, heightInches: 74);
      final franchise = _franchiseWith(
        extraMembers: [
          RosterMembership(player: player, status: RosterStatus.developmental),
        ],
      );
      final repository = await _seededRepository(franchise);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [saveRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(home: Scaffold(body: TeamRosterScreen())),
        ),
      );
      await tester.pump();

      await tester.scrollUntilVisible(
        find.text('Development Slots (1/2)'),
        300,
        scrollable: find.byType(Scrollable),
      );

      // "EXP: 5" -- `playerWithOverall`'s default `yearsOfService` -- not
      // height; Card Lab #11 dropped height from the subtitle line in
      // favor of experience, and the GM approved that shape as-is.
      expect(find.textContaining('EXP: 5'), findsWidgets);
      // 3 separate chips now, not one combined text line.
      expect(find.text('OFF 70'), findsWidgets);
      expect(find.text('DEF 70'), findsWidgets);
      expect(find.text('PHY 70'), findsWidgets);
    },
  );

  testWidgets('a player\'s traits show as chips naming each one', (
    tester,
  ) async {
    final traitedPlayer = playerWithOverall(
      70,
      traits: {Trait.leader, Trait.sharpshooter},
    );
    final franchise = _franchiseWith(
      extraMembers: [
        RosterMembership(
          player: traitedPlayer,
          status: RosterStatus.developmental,
        ),
      ],
    );
    final repository = await _seededRepository(franchise);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [saveRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: Scaffold(body: TeamRosterScreen())),
      ),
    );
    await tester.pump();

    await tester.scrollUntilVisible(
      find.text('Development Slots (1/2)'),
      300,
      scrollable: find.byType(Scrollable),
    );

    // findsWidgets, not findsOneWidget: the randomly generated active
    // roster could coincidentally include another player with the same
    // trait -- this test only cares that the deliberately-traited player's
    // chips render, not roster-wide uniqueness.
    expect(find.text('Leader'), findsWidgets);
    expect(find.text('Sharpshooter'), findsWidgets);
  });

  testWidgets(
    'with no developmental or reserve players, the Development/Inactive '
    'slot sections still show, both empty (2026-08-10: slots are a real, '
    'always-visible fact about the roster, not hidden when unused)',
    (tester) async {
      tester.view.physicalSize = const Size(800, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final franchise = _franchiseWith();
      final repository = await _seededRepository(franchise);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [saveRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(home: Scaffold(body: TeamRosterScreen())),
        ),
      );
      await tester.pump();

      expect(find.text('Development Slots (0/2)'), findsOneWidget);
      expect(find.text('Injured/Inactive Slots (0/2)'), findsOneWidget);
      expect(find.text('Empty slot'), findsNWidgets(4));
      expect(find.text('Assign'), findsNWidgets(4));
    },
  );

  testWidgets(
    'an injured player shows an obvious ambulance-emoji line below their '
    'traits (severity + games until recovery), plus a matching corner '
    'badge on their portrait (2026-08-21, a direct GM ask: "It should be '
    'super obvious that they are injured")',
    (tester) async {
      tester.view.physicalSize = const Size(800, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final baseRoster = generateStartingRoster(1);
      final injured = baseRoster.first;
      final overrideRoster = [
        injured.copyWith(
          injury: const PlayerInjury(
            severity: InjurySeverity.moderate,
            gamesRemainingAtSeverity: 3,
          ),
        ),
        ...baseRoster.skip(1),
      ];
      final franchise = _franchiseWith(overrideRoster: overrideRoster);
      final repository = await _seededRepository(franchise);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [saveRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(home: Scaffold(body: TeamRosterScreen())),
        ),
      );
      await tester.pump();

      expect(find.text('🚑'), findsWidgets);
      expect(
        find.text('Moderate injury -- 3 games until recovery'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'the Assign sheet sorts injured roster candidates to the top, each '
    'flagged with the ambulance emoji (2026-08-21, a direct GM ask)',
    (tester) async {
      tester.view.physicalSize = const Size(800, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final baseRoster = generateStartingRoster(1);
      // The lowest-overall player, injured -- would sort last by overall
      // alone, but should still jump to the very top of the Assign sheet.
      final weakest = baseRoster.reduce(
        (a, b) => a.player.ratings.overall <= b.player.ratings.overall ? a : b,
      );
      final overrideRoster = [
        for (final m in baseRoster)
          if (m.player.id == weakest.player.id)
            m.copyWith(
              injury: const PlayerInjury(
                severity: InjurySeverity.minor,
                gamesRemainingAtSeverity: 1,
              ),
            )
          else
            m,
      ];
      final franchise = _franchiseWith(overrideRoster: overrideRoster);
      final repository = await _seededRepository(franchise);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [saveRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(home: Scaffold(body: TeamRosterScreen())),
        ),
      );
      await tester.pump();

      // The last "Assign" button is an Injured/Inactive slot (Development
      // slots come first) -- deliberate, since Development eligibility
      // has its own years-of-service restriction the test's injured
      // player might not clear, while Injured/Inactive has none.
      await tester.tap(find.text('Assign').last);
      await tester.pumpAndSettle();

      final rowFinder = find.textContaining('Currently Active');
      expect(rowFinder, findsWidgets);
      final firstRowText = tester.widget<Text>(rowFinder.first).data;
      expect(firstRowText, contains('🚑'));
    },
  );

  testWidgets(
    'tapping Assign on an empty Development slot and picking a roster '
    'player moves them into it',
    (tester) async {
      tester.view.physicalSize = const Size(800, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final franchise = _franchiseWith();
      final repository = await _seededRepository(franchise);
      final target = franchise.roster
          .firstWhere((m) => isDevelopmentalEligible(m.player))
          .player;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [saveRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(home: Scaffold(body: TeamRosterScreen())),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Assign').first);
      await tester.pumpAndSettle();

      expect(find.text('Assign to Developmental'), findsOneWidget);
      expect(find.text('On Your Roster'), findsOneWidget);
      // The candidate row's own label, not a bare name search -- the
      // target is also still shown (behind the modal barrier) in the
      // Active Roster section underneath, which a looser finder would
      // match first and then fail to hit-test (it's obscured).
      final targetLabel =
          '${target.primaryPosition.abbreviation} ${target.lastName} '
          '(${target.ratings.overall} OVR, ${target.ratings.potential} POT)';
      await tester.tap(find.text(targetLabel));
      await tester.pumpAndSettle();

      // Sheet closed, and the move persisted.
      expect(find.text('Assign to Developmental'), findsNothing);
      expect(find.text('Development Slots (1/2)'), findsOneWidget);
      final saved = await repository.readSave(kCurrentFranchiseSaveId);
      final savedFranchise = franchiseFromJson(
        SaveEnvelope.fromJson(saved!).payload,
      );
      expect(
        savedFranchise.roster
            .firstWhere((m) => m.player.id == target.id)
            .status,
        RosterStatus.developmental,
      );
    },
  );

  testWidgets('signing a free agent from the Assign sheet places them directly '
      'into the slot, not the active roster', (tester) async {
    tester.view.physicalSize = const Size(800, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final youngFreeAgent = playerWithOverall(
      60,
      name: 'Young Prospect',
      yearsOfService: 1,
    );
    final franchise = _franchiseWith(freeAgents: [youngFreeAgent]);
    final repository = await _seededRepository(franchise);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [saveRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: Scaffold(body: TeamRosterScreen())),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Assign').first);
    await tester.pumpAndSettle();

    expect(find.text('Free Agents'), findsOneWidget);
    final targetLabel =
        '${youngFreeAgent.primaryPosition.abbreviation} '
        '${youngFreeAgent.lastName} (${youngFreeAgent.ratings.overall} '
        'OVR, ${youngFreeAgent.ratings.potential} POT)';
    await tester.tap(find.text(targetLabel));
    await tester.pumpAndSettle();

    final saved = await repository.readSave(kCurrentFranchiseSaveId);
    final savedFranchise = franchiseFromJson(
      SaveEnvelope.fromJson(saved!).payload,
    );
    final signed = savedFranchise.roster.firstWhere(
      (m) => m.player.id == youngFreeAgent.id,
    );
    expect(signed.status, RosterStatus.developmental);
    expect(
      savedFranchise.freeAgents.any((p) => p.id == youngFreeAgent.id),
      isFalse,
    );
  });

  testWidgets('tapping a player row opens their Player Detail screen', (
    tester,
  ) async {
    // The roster row is display-sorted by position then overall, not
    // generation order, so `targetPlayer` (roster[0], generation order)
    // could land anywhere in the list -- tall enough to guarantee every
    // active row is on-screen at once rather than guessing at a scroll
    // offset.
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final franchise = _franchiseWith();
    final repository = await _seededRepository(franchise);
    final targetPlayer = franchise.roster.first.player;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [saveRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: Scaffold(body: TeamRosterScreen())),
      ),
    );
    await tester.pump();

    await tester.tap(find.textContaining(targetPlayer.name).first);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, targetPlayer.name), findsOneWidget);
    expect(find.text('Ratings'), findsOneWidget);
  });

  testWidgets(
    'tapping the coach row opens the Coach Detail screen -- a direct GM '
    'ask (2026-08-19): "Head coach needs a detail screen"',
    (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final franchise = _franchiseWith();
      final repository = await _seededRepository(franchise);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [saveRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(home: Scaffold(body: TeamRosterScreen())),
        ),
      );
      await tester.pump();

      await tester.tap(find.text(franchise.coach.name));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, franchise.coach.name), findsOneWidget);
      expect(find.text('Career Record'), findsOneWidget);
      expect(find.text('Coaching Stats'), findsOneWidget);
      expect(find.text('First season as head coach'), findsOneWidget);
    },
  );

  testWidgets('the Card Lab button is hidden -- dev tool, not for a normal '
      'playthrough (2026-08-07)', (tester) async {
    final franchise = _franchiseWith();
    final repository = await _seededRepository(franchise);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [saveRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: Scaffold(body: TeamRosterScreen())),
      ),
    );
    await tester.pump();

    expect(find.text('Card Lab'), findsNothing);
  });
}
