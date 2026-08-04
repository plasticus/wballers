import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/franchise/onboarding/expansion_franchise_factory.dart';
import 'package:womensbballmgr/features/league/domain/team.dart';
import 'package:womensbballmgr/features/roster/domain/roster_status.dart';

void main() {
  group('deriveTeamAbbreviation', () {
    test('takes the first three letters, uppercased', () {
      expect(deriveTeamAbbreviation('Comets'), 'COM');
    });

    test('strips spaces and punctuation before taking letters', () {
      expect(deriveTeamAbbreviation("Sea Storm"), 'SEA');
      expect(deriveTeamAbbreviation('Twin Cities Skalds'), 'TWI');
    });

    test('pads a too-short name with X', () {
      expect(deriveTeamAbbreviation('Ice'), 'ICE');
      expect(deriveTeamAbbreviation('Go'), 'GOX');
    });
  });

  group('createExpansionFranchise', () {
    test('the same seed produces an identical franchise', () {
      final a = createExpansionFranchise(
        coachName: 'Jordan Ellis',
        clubName: 'Comets',
        homeCity: 'Springfield, IL',
        conference: Conference.atlantic,
        simulationSeed: 555,
      );
      final b = createExpansionFranchise(
        coachName: 'Jordan Ellis',
        clubName: 'Comets',
        homeCity: 'Springfield, IL',
        conference: Conference.atlantic,
        simulationSeed: 555,
      );

      expect(a.id, b.id);
      expect(a.team.colors.primaryHex, b.team.colors.primaryHex);
      for (var i = 0; i < a.roster.length; i++) {
        expect(a.roster[i].player.name, b.roster[i].player.name);
      }
    });

    test('sets the coach, team identity, and a full active roster', () {
      final franchise = createExpansionFranchise(
        coachName: 'Jordan Ellis',
        clubName: 'Comets',
        homeCity: 'Springfield, IL',
        conference: Conference.pacific,
        simulationSeed: 1,
      );

      expect(franchise.coach.name, 'Jordan Ellis');
      expect(franchise.team.name, 'Comets');
      expect(franchise.team.location, 'Springfield, IL');
      expect(franchise.team.conference, Conference.pacific);
      expect(franchise.team.abbreviation, 'COM');
      expect(
        franchise.roster.where((m) => m.status == RosterStatus.active),
        hasLength(12),
      );
    });
  });
}
