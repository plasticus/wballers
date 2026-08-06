import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/league/domain/team.dart';
import 'package:womensbballmgr/features/league/team_row.dart';
import 'package:womensbballmgr/features/season/domain/standings_entry.dart';

const _team = Team(
  abbreviation: 'BOS',
  location: 'Boston, MA',
  name: 'Boston Comets',
  conference: Conference.atlantic,
  colors: TeamColors(
    primaryHex: '#000000',
    secondaryHex: '#111111',
    accentHex: '#222222',
  ),
  identityNote: '',
  emoji: '🏀',
);

Future<void> _pump(WidgetTester tester, TeamRow row) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: row)));
  await tester.pump();
}

void main() {
  testWidgets('shows no rank or record when neither is given', (tester) async {
    await _pump(tester, const TeamRow(team: _team));

    expect(find.text(_team.name), findsOneWidget);
    expect(find.text(_team.emoji), findsOneWidget);
    expect(find.textContaining('-'), findsNothing);
  });

  testWidgets('shows the rank and W-L record when given', (tester) async {
    await _pump(
      tester,
      const TeamRow(
        team: _team,
        rank: 3,
        record: StandingsEntry(
          teamAbbreviation: 'BOS',
          wins: 12,
          losses: 4,
          pointsFor: 0,
          pointsAgainst: 0,
        ),
      ),
    );

    expect(find.text('3'), findsOneWidget);
    expect(find.text('12-4'), findsOneWidget);
  });

  testWidgets('shows the "Your Team" badge alongside a record', (tester) async {
    await _pump(
      tester,
      const TeamRow(
        team: _team,
        isUserTeam: true,
        record: StandingsEntry(
          teamAbbreviation: 'BOS',
          wins: 0,
          losses: 0,
          pointsFor: 0,
          pointsAgainst: 0,
        ),
      ),
    );

    expect(find.text('Your Team'), findsOneWidget);
    expect(find.text('0-0'), findsOneWidget);
  });
}
