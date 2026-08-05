import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/league/domain/initial_league.dart';
import 'package:womensbballmgr/features/league/domain/team.dart';

void main() {
  test('contains exactly 40 teams', () {
    expect(kLeagueTeamPool, hasLength(40));
  });

  test('splits evenly, 20 per conference', () {
    final byConference = <Conference, int>{};
    for (final team in kLeagueTeamPool) {
      byConference[team.conference] = (byConference[team.conference] ?? 0) + 1;
    }

    expect(byConference[Conference.atlantic], 20);
    expect(byConference[Conference.pacific], 20);
  });

  test('every abbreviation is unique and exactly three uppercase letters', () {
    final abbreviations = kLeagueTeamPool.map((t) => t.abbreviation).toSet();
    expect(abbreviations, hasLength(40));

    for (final abbreviation in abbreviations) {
      expect(
        RegExp(r'^[A-Z]{3}$').hasMatch(abbreviation),
        isTrue,
        reason: '$abbreviation should be exactly three uppercase letters',
      );
    }
  });

  test('every team name is unique', () {
    final names = kLeagueTeamPool.map((t) => t.name).toSet();
    expect(names, hasLength(40));
  });

  test('color hex strings parse to opaque colors', () {
    for (final team in kLeagueTeamPool) {
      expect(team.colors.primary.a, 1.0);
      expect(team.colors.secondary.a, 1.0);
      expect(team.colors.accent.a, 1.0);
    }
  });
}
