import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/coach/domain/coach_archetype.dart';
import 'package:womensbballmgr/features/franchise/domain/franchise.dart';
import 'package:womensbballmgr/features/franchise/onboarding/expansion_franchise_factory.dart';
import 'package:womensbballmgr/features/league/domain/team.dart';
import 'package:womensbballmgr/features/league/domain/team_identity.dart';
import 'package:womensbballmgr/features/league/team_detail_screen.dart';
import 'package:womensbballmgr/features/roster/domain/roster_status.dart';

import '../../support/franchise_test_helpers.dart';

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

void main() {
  testWidgets(
    'shows the coach, roster, record, and style -- everything a direct '
    'GM ask called for (2026-08-20: "current head coach, their roster, '
    'their record, and their style")',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final franchise = _newFranchise();
      final aiTeam = franchise.league.aiTeams.first;
      final identity = identityFor(aiTeam.team.abbreviation);

      await tester.pumpWidget(
        MaterialApp(
          home: TeamDetailScreen(
            franchise: franchise,
            teamAbbreviation: aiTeam.team.abbreviation,
          ),
        ),
      );
      await tester.pump();

      // Style.
      expect(find.text(identity.styleLabel), findsOneWidget);
      // Coach.
      expect(find.text('Head Coach'), findsOneWidget);
      expect(find.text(aiTeam.coach.name), findsOneWidget);
      // Appears twice -- once in the style summary, once in the coach
      // card -- both real, both correct.
      expect(find.textContaining(identity.archetype.label), findsWidgets);
      // Record -- no games played yet.
      expect(find.textContaining('0-0'), findsOneWidget);
      // Roster.
      final active = aiTeam.roster
          .where((m) => m.status == RosterStatus.active)
          .toList();
      expect(find.text('Active Roster (${active.length})'), findsOneWidget);
      expect(find.textContaining(active.first.player.name), findsOneWidget);
    },
  );

  testWidgets('the coach summary never shows GM-own-coach-only fields '
      '(seasonsAsHeadCoach/career record) that would always misleadingly '
      'read 0 for an AI coach', (tester) async {
    final franchise = _newFranchise();
    final aiTeam = franchise.league.aiTeams.first;

    await tester.pumpWidget(
      MaterialApp(
        home: TeamDetailScreen(
          franchise: franchise,
          teamAbbreviation: aiTeam.team.abbreviation,
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Career'), findsNothing);
    expect(find.textContaining('Championships'), findsNothing);
  });
}
