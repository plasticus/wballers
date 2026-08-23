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
import 'package:womensbballmgr/features/franchise/domain/pending_retirement.dart';
import 'package:womensbballmgr/features/franchise/persistence/franchise_json.dart';
import 'package:womensbballmgr/features/league/domain/initial_league.dart';
import 'package:womensbballmgr/features/mail/domain/mail_item.dart';
import 'package:womensbballmgr/features/player/domain/retirement_reason.dart';
import 'package:womensbballmgr/features/player/presentation/retirement_decision_screen.dart';
import 'package:womensbballmgr/features/roster/domain/roster_membership.dart';
import 'package:womensbballmgr/features/roster/domain/roster_status.dart';
import 'package:womensbballmgr/features/roster/generation/starting_roster_generator.dart';
import 'package:womensbballmgr/features/training/domain/training_plan.dart';

import '../../../support/in_memory_save_repository.dart';
import '../../../support/league_test_helpers.dart';
import '../../../support/season_test_helpers.dart';
import '../../../support/training_test_helpers.dart';
import '../../roster/domain/roster_test_helpers.dart';

Franchise _franchiseWith({
  required RosterMembership target,
  int motivation = 50,
}) {
  final roster = [target, ...generateStartingRoster(1).skip(1)];
  return Franchise(
    id: 'franchise-1',
    gmName: 'Taylor Reed',
    team: kLeagueTeamPool.first,
    coach: Coach(
      name: 'Jordan Ellis',
      stats: CoachStats(
        offense: 50,
        defense: 50,
        development: 50,
        motivation: motivation,
        management: 50,
      ),
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
  ).copyWithPendingRetirements([
    PendingRetirement(
      playerId: target.player.id,
      reason: RetirementReason.hitMandatoryAge,
    ),
  ]);
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
  testWidgets('shows the player and the retirement reason', (tester) async {
    final target = playerWithOverall(70, id: 'p1', age: 38);
    final franchise = _franchiseWith(
      target: RosterMembership(player: target, status: RosterStatus.active),
    );
    final repository = await _seededRepository(franchise);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [saveRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          home: RetirementDecisionScreen(
            franchise: franchise,
            item: RetirementDecisionMailItem(
              pending: franchise.pendingRetirements.single,
              player: target,
              week: 1,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text(target.name), findsOneWidget);
    expect(find.text(RetirementReason.hitMandatoryAge.label), findsOneWidget);
    expect(find.text('Try to Convince Her to Stay'), findsOneWidget);
    expect(find.text('Let Her Retire'), findsOneWidget);
  });

  testWidgets(
    'letting her retire (after confirming) removes her from the roster '
    'and pops back',
    (tester) async {
      final target = playerWithOverall(70, id: 'p1', age: 38);
      final franchise = _franchiseWith(
        target: RosterMembership(player: target, status: RosterStatus.active),
      );
      final repository = await _seededRepository(franchise);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [saveRepositoryProvider.overrideWithValue(repository)],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RetirementDecisionScreen(
                          franchise: franchise,
                          item: RetirementDecisionMailItem(
                            pending: franchise.pendingRetirements.single,
                            player: target,
                            week: 1,
                          ),
                        ),
                      ),
                    ),
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

      await tester.tap(find.text('Let Her Retire'));
      await tester.pumpAndSettle();
      // Confirmation dialog's own button shares the same label as the
      // screen's -- both are in the tree now, so tap the dialog's (last).
      await tester.tap(find.text('Let Her Retire').last);
      await tester.pumpAndSettle();

      // Back on the launcher screen.
      expect(find.text('Open'), findsOneWidget);
      final updated = ProviderScope.containerOf(
        tester.element(find.text('Open')),
      );
      final finalFranchise = updated.read(currentFranchiseProvider).value!;
      expect(finalFranchise.roster.any((m) => m.player.id == 'p1'), isFalse);
      expect(finalFranchise.freeAgents.any((p) => p.id == 'p1'), isFalse);
      expect(finalFranchise.pendingRetirements, isEmpty);
    },
  );

  testWidgets(
    'attempting persuasion always resolves the pending entry and pops '
    'back, regardless of outcome',
    (tester) async {
      final target = playerWithOverall(70, id: 'p1', age: 38);
      final franchise = _franchiseWith(
        target: RosterMembership(player: target, status: RosterStatus.active),
        motivation: 50,
      );
      final repository = await _seededRepository(franchise);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [saveRepositoryProvider.overrideWithValue(repository)],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RetirementDecisionScreen(
                          franchise: franchise,
                          item: RetirementDecisionMailItem(
                            pending: franchise.pendingRetirements.single,
                            player: target,
                            week: 1,
                          ),
                        ),
                      ),
                    ),
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

      await tester.tap(find.text('Try to Convince Her to Stay'));
      await tester.pumpAndSettle();

      expect(find.text('Open'), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.text('Open')),
      );
      final finalFranchise = container.read(currentFranchiseProvider).value!;
      expect(finalFranchise.pendingRetirements, isEmpty);
      // Self-consistent either way: still on the roster (persuaded) or
      // gone entirely, never routed to freeAgents.
      final stillRostered = finalFranchise.roster.any(
        (m) => m.player.id == 'p1',
      );
      if (!stillRostered) {
        expect(finalFranchise.freeAgents.any((p) => p.id == 'p1'), isFalse);
      }
    },
  );
}
