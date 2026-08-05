import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/league/domain/ai_team_roster.dart';
import 'package:womensbballmgr/features/league/domain/initial_league.dart';
import 'package:womensbballmgr/features/league/domain/league.dart';

void main() {
  test('rejects anything other than exactly 19 AI teams', () {
    expect(
      () => League(
        aiTeams: [
          for (final team in kLeagueTeamPool.take(18))
            AiTeamRoster(team: team, roster: const []),
        ],
      ),
      throwsA(isA<AssertionError>()),
    );
  });

  test('accepts exactly 19', () {
    expect(
      () => League(
        aiTeams: [
          for (final team in kLeagueTeamPool.take(19))
            AiTeamRoster(team: team, roster: const []),
        ],
      ),
      returnsNormally,
    );
  });
}
