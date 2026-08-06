import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/franchise/onboarding/expansion_franchise_factory.dart';
import 'package:womensbballmgr/features/league/domain/team.dart';
import 'package:womensbballmgr/features/roster/domain/roster_membership.dart';
import 'package:womensbballmgr/features/roster/domain/roster_status.dart';
import 'package:womensbballmgr/features/season/application/franchise_rosters.dart';

void main() {
  final franchise = createExpansionFranchise(
    gmName: 'Jordan Ellis',
    clubName: 'Comets',
    homeCity: 'Springfield, IL',
    conference: Conference.atlantic,
    replacedTeamAbbreviation: 'BOS',
    colors: kStarterPalettes.first,
    emoji: '🏀',
    simulationSeed: 1,
  );

  group('rostersByAbbreviation', () {
    test('has an entry for the GM\'s own team plus every AI team', () {
      final rosters = rostersByAbbreviation(franchise);

      expect(rosters.length, 20);
      expect(rosters.containsKey(franchise.team.abbreviation), isTrue);
      for (final aiTeam in franchise.league.aiTeams) {
        expect(rosters.containsKey(aiTeam.team.abbreviation), isTrue);
      }
    });

    test('excludes non-active roster players', () {
      final original = franchise.roster;
      final adjustedRoster = [
        for (var i = 0; i < original.length; i++)
          if (i == 0)
            RosterMembership(
              player: original[i].player,
              status: RosterStatus.developmental,
            )
          else
            original[i],
      ];
      final adjusted = franchise.copyWithRoster(adjustedRoster);

      final rosters = rostersByAbbreviation(adjusted);

      final ownRoster = rosters[adjusted.team.abbreviation]!;
      expect(ownRoster.length, original.length - 1);
      expect(ownRoster.contains(original[0].player), isFalse);
    });
  });

  group('teamByAbbreviation', () {
    test('returns the GM\'s own team for its abbreviation', () {
      expect(
        teamByAbbreviation(franchise, franchise.team.abbreviation),
        franchise.team,
      );
    });

    test('returns the matching AI team for its abbreviation', () {
      final aiTeam = franchise.league.aiTeams.first;

      expect(
        teamByAbbreviation(franchise, aiTeam.team.abbreviation),
        aiTeam.team,
      );
    });

    test('throws for an abbreviation outside this league', () {
      expect(() => teamByAbbreviation(franchise, 'ZZZ'), throwsStateError);
    });
  });
}
