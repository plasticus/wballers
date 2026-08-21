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
import 'package:womensbballmgr/features/league/domain/initial_league.dart';
import 'package:womensbballmgr/features/player/domain/player.dart';
import 'package:womensbballmgr/features/player/presentation/player_card_widgets.dart';
import 'package:womensbballmgr/features/roster/generation/starting_roster_generator.dart';
import 'package:womensbballmgr/features/training/domain/player_rating_field.dart';
import 'package:womensbballmgr/features/training/domain/training_coach.dart';
import 'package:womensbballmgr/features/training/domain/training_focus.dart';
import 'package:womensbballmgr/features/training/domain/training_plan.dart';
import 'package:womensbballmgr/features/training/presentation/training_screen.dart';

import '../../../support/in_memory_save_repository.dart';
import '../../../support/league_test_helpers.dart';
import '../../../support/season_test_helpers.dart';

const _coaches = [
  TrainingCoach(name: 'Coach Amara'),
  TrainingCoach(name: 'Coach Blake'),
  TrainingCoach(name: 'Coach Cruz'),
];

Franchise _franchiseWith({TrainingPlan? trainingPlan}) {
  final roster = generateStartingRoster(1);
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
    trainingCoaches: _coaches,
    trainingPlan: trainingPlan ?? TrainingPlan.initial(),
    nextTrainingWeek: 1,
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
  testWidgets('shows the team focus picker and one card per training coach', (
    tester,
  ) async {
    final franchise = _franchiseWith();
    final repository = await _seededRepository(franchise);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [saveRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(home: TrainingScreen(franchise: franchise)),
      ),
    );
    await tester.pump();

    expect(find.text('Team Focus'), findsOneWidget);
    // "Individual Coach #1/#2/#3" -- the generated coaches' own names
    // (2026-08-07: "the three training coaches don't need names").
    expect(find.text('Individual Coach #1'), findsOneWidget);
    expect(find.text('Individual Coach #2'), findsOneWidget);
    expect(find.text('Individual Coach #3'), findsOneWidget);
    expect(find.text('Coach Amara'), findsNothing);
    // No development-rating readout (2026-08-10, a direct GM ask) -- a
    // training coach carries no rating of its own to show at all.
    expect(find.textContaining('DEV'), findsNothing);
    // Unassigned by default (TrainingPlan.initial) -- no focus picker shown
    // for any of the 3 idle coaches yet.
    expect(find.text('Unassigned'), findsNWidgets(3));
    expect(find.text('Broad'), findsNothing);
    // The brief plain-language explainer, below the Save button
    // (2026-08-10, TODO.md item 6, a direct GM ask -- "I am writing the
    // program, and even I don't know how it works").
    expect(find.text('How Training Works'), findsOneWidget);
  });

  testWidgets('the Season To Date card\'s View Report button opens '
      'SeasonToDateReportScreen (2026-08-10, TODO.md item 5)', (tester) async {
    final franchise = _franchiseWith();
    final repository = await _seededRepository(franchise);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [saveRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(home: TrainingScreen(franchise: franchise)),
      ),
    );
    await tester.pump();

    expect(find.text('Season To Date'), findsOneWidget);
    await tester.tap(find.text('View Report'));
    await tester.pumpAndSettle();

    expect(find.text('Season To Date Report'), findsOneWidget);
    expect(
      find.text('No training has resolved yet this season.'),
      findsOneWidget,
    );
  });

  testWidgets('changing the team focus and saving persists it', (tester) async {
    // The Save button needs to be on-screen for tap() to hit test it --
    // the default test surface is too short for this screen's 3 coach
    // cards plus the team focus section above them.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final franchise = _franchiseWith();
    final repository = await _seededRepository(franchise);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [saveRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TrainingScreen(franchise: franchise),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Off'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save Training Plan'));
    await tester.pumpAndSettle();

    // Back on the launcher screen.
    expect(find.text('Open'), findsOneWidget);

    final saved = await repository.readSave(kCurrentFranchiseSaveId);
    final savedFranchise = franchiseFromJson(
      SaveEnvelope.fromJson(saved!).payload,
    );
    expect(savedFranchise.trainingPlan.teamFocus, TrainingFocus.offense);
  });

  testWidgets(
    'assigning a coach to a player reveals the broad/specific focus picker',
    (tester) async {
      // The first coach's "Unassigned" field needs to be on-screen for
      // tap() to hit test it -- the default test surface is too short
      // now that the Season To Date card sits above the team focus
      // section (2026-08-10, TODO.md item 5).
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final franchise = _franchiseWith();
      final repository = await _seededRepository(franchise);
      final firstPlayerLabel = _playerMenuItemLabel(
        franchise.roster.first.player,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [saveRepositoryProvider.overrideWithValue(repository)],
          child: MaterialApp(home: TrainingScreen(franchise: franchise)),
        ),
      );
      await tester.pump();

      // Open the first coach's player dropdown and pick the first roster
      // player.
      await tester.tap(find.text('Unassigned').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(firstPlayerLabel).last);
      await tester.pumpAndSettle();

      expect(find.text('Broad'), findsOneWidget);
      expect(find.text('Specific'), findsOneWidget);
    },
  );

  testWidgets('saving an individual coach assignment persists it', (
    tester,
  ) async {
    // Same "Save button must be on-screen" rationale as above -- assigning
    // a player also expands a coach card with its broad/specific picker,
    // pushing Save even further down.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final franchise = _franchiseWith();
    final repository = await _seededRepository(franchise);
    final targetPlayer = franchise.roster.first.player;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [saveRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(home: TrainingScreen(franchise: franchise)),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Unassigned').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(_playerMenuItemLabel(targetPlayer)).last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save Training Plan'));
    await tester.pumpAndSettle();

    final saved = await repository.readSave(kCurrentFranchiseSaveId);
    final savedFranchise = franchiseFromJson(
      SaveEnvelope.fromJson(saved!).payload,
    );
    final firstSlot = savedFranchise.trainingPlan.coachSlots.first;
    expect(firstSlot.playerId, targetPlayer.id);
    expect(firstSlot.focus!.isSpecific, isFalse);
    expect(firstSlot.focus!.broadFocus, TrainingFocus.balanced);
  });

  testWidgets('a coach already assigned elsewhere is loaded correctly on '
      'open', (tester) async {
    final targetPlayerId = generateStartingRoster(1).first.player.id;
    final franchise = _franchiseWith(
      trainingPlan: TrainingPlan(
        teamFocus: TrainingFocus.defense,
        coachSlots: [
          TrainingCoachSlot(
            playerId: targetPlayerId,
            focus: const IndividualTrainingFocus.specific(
              PlayerRatingField.speed,
            ),
          ),
          const TrainingCoachSlot(),
          const TrainingCoachSlot(),
        ],
      ),
    );
    final repository = await _seededRepository(franchise);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [saveRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(home: TrainingScreen(franchise: franchise)),
      ),
    );
    await tester.pump();

    final targetPlayer = franchise.roster
        .firstWhere((m) => m.player.id == targetPlayerId)
        .player;
    // The closed/collapsed field shows last name plus OVR/POT/AGE as bare
    // numbers (`_CoachPickerSelectedItem`), not the full open-menu identity
    // line -- check each piece instead of one combined string.
    final lastName = targetPlayer.name.split(' ').skip(1).join(' ');
    expect(find.text(lastName), findsOneWidget);
    // `_findBareStatChip` matches by raw numeric value alone (the widget
    // itself carries nothing else to tell an OVR chip from a POT chip),
    // so when the two happen to coincide -- expected and common now for
    // `starting_roster_generator.dart`'s franchise-vet slot, whose
    // potential is deliberately centered on the same value as her current
    // ability (2026-08-14 revision: she's not a training project, she's
    // already near her ceiling) -- the same number legitimately renders
    // twice (her OVR chip and her POT chip both showing it).
    final overallMatchesPotential =
        targetPlayer.ratings.overall == targetPlayer.ratings.potential;
    expect(
      _findBareStatChip(targetPlayer.ratings.overall),
      overallMatchesPotential ? findsNWidgets(2) : findsOneWidget,
    );
    expect(
      _findBareStatChip(targetPlayer.ratings.potential),
      overallMatchesPotential ? findsNWidgets(2) : findsOneWidget,
    );
    expect(_findBareStatChip(targetPlayer.age), findsOneWidget);
    expect(find.text('Specific'), findsOneWidget);
    expect(find.text('Speed'), findsOneWidget);
    // Still 2 idle coaches.
    expect(find.text('Unassigned'), findsNWidgets(2));
  });

  testWidgets(
    'a coach slot pointing at a player who has since left the roster '
    '(traded, released, retired) loads as unassigned instead of crashing '
    '(2026-08-21, a GM bug report: this used to blank the whole screen)',
    (tester) async {
      const staleId = 'no-longer-on-the-roster';
      final franchise = _franchiseWith(
        trainingPlan: TrainingPlan(
          teamFocus: TrainingFocus.defense,
          coachSlots: [
            const TrainingCoachSlot(
              playerId: staleId,
              focus: IndividualTrainingFocus.specific(PlayerRatingField.speed),
            ),
            const TrainingCoachSlot(),
            const TrainingCoachSlot(),
          ],
        ),
      );
      final repository = await _seededRepository(franchise);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [saveRepositoryProvider.overrideWithValue(repository)],
          child: MaterialApp(home: TrainingScreen(franchise: franchise)),
        ),
      );
      await tester.pump();

      // No crash, and every one of the 3 slots reads unassigned -- the
      // stale reference was dropped, not preserved as a broken assignment.
      expect(tester.takeException(), isNull);
      expect(find.text('Unassigned'), findsNWidgets(3));
      expect(find.text('Specific'), findsNothing);
    },
  );
}

/// Mirrors `training_screen.dart`'s private `_CoachPickerMenuItem` identity
/// line -- can't import a private widget's exact text, so this is kept in
/// sync by hand. `'PG #49 Silva'`: position, jersey (when assigned), last
/// name -- the OVR/POT/AGE numbers are separate `StatChip` widgets now, not
/// part of this string.
String _playerMenuItemLabel(Player player) {
  final jersey = player.jerseyNumber != null ? '#${player.jerseyNumber} ' : '';
  final lastName = player.name.split(' ').skip(1).join(' ');
  return '${player.primaryPosition.abbreviation} $jersey$lastName';
}

/// A `StatChip` rendered with no label (bare number) showing exactly
/// [value] -- the Coach Picker's collapsed/selected state.
Finder _findBareStatChip(int value) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is StatChip && widget.label.isEmpty && widget.value == value,
  );
}
