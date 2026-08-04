import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/league/domain/initial_league.dart';
import 'package:womensbballmgr/features/league/domain/team.dart';
import 'package:womensbballmgr/features/league/league_screen.dart';

void main() {
  testWidgets('lists every team, grouped under both conference headers', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LeagueScreen()));

    final atlanticTeams = kInitialLeagueTeams.where(
      (team) => team.conference == Conference.atlantic,
    );
    final pacificTeams = kInitialLeagueTeams.where(
      (team) => team.conference == Conference.pacific,
    );

    expect(find.text('Atlantic Conference'), findsOneWidget);
    for (final team in atlanticTeams) {
      expect(find.text(team.name), findsOneWidget);
    }

    // The Pacific section is below the fold in the test viewport; the
    // ListView only builds slivers near the viewport, so scroll to it.
    await tester.scrollUntilVisible(
      find.text('Pacific Conference'),
      300,
      scrollable: find.byType(Scrollable),
    );

    expect(find.text('Pacific Conference'), findsOneWidget);
    for (final team in pacificTeams) {
      expect(find.text(team.name), findsOneWidget);
    }
  });
}
