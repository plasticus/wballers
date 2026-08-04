import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/franchise/onboarding/expansion_franchise_factory.dart';
import 'package:womensbballmgr/features/league/domain/team.dart';
import 'package:womensbballmgr/features/portrait/domain/portrait_weights.dart';
import 'package:womensbballmgr/features/roster/domain/roster_status.dart';

final _portraitWeights = PortraitWeights(
  skinTone: const {'medium': 1},
  hairColorByTone: const {
    'medium': {'black': 1},
  },
  hair: const {'hair_afro': 1},
  neonHair: const {'natural': 1},
  eyes: const {'eyes_1center': 1},
  nose: const {'nose_1': 1},
  mouth: const {'mouth_1': 1},
  eyebrows: const {'eyebrow_1': 1},
  facial: const {'facial_goat': 1},
  accessories: const {'none': 1},
);

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
        gmName: 'Jordan Ellis',
        clubName: 'Comets',
        homeCity: 'Springfield, IL',
        conference: Conference.atlantic,
        simulationSeed: 555,
      );
      final b = createExpansionFranchise(
        gmName: 'Jordan Ellis',
        clubName: 'Comets',
        homeCity: 'Springfield, IL',
        conference: Conference.atlantic,
        simulationSeed: 555,
      );

      expect(a.id, b.id);
      expect(a.coach.name, b.coach.name);
      expect(a.coach.stats.overall, b.coach.stats.overall);
      expect(a.team.colors.primaryHex, b.team.colors.primaryHex);
      for (var i = 0; i < a.roster.length; i++) {
        expect(a.roster[i].player.name, b.roster[i].player.name);
      }
    });

    test('the GM is not the coach -- both are set, and distinctly', () {
      final franchise = createExpansionFranchise(
        gmName: 'Jordan Ellis',
        clubName: 'Comets',
        homeCity: 'Springfield, IL',
        conference: Conference.pacific,
        simulationSeed: 1,
      );

      expect(franchise.gmName, 'Jordan Ellis');
      expect(franchise.coach.name, isNotEmpty);
      expect(
        franchise.coach.name,
        isNot('Jordan Ellis'),
        reason: 'the coach is a generated NPC, not the GM',
      );
    });

    test('sets the team identity and a full active roster', () {
      final franchise = createExpansionFranchise(
        gmName: 'Jordan Ellis',
        clubName: 'Comets',
        homeCity: 'Springfield, IL',
        conference: Conference.pacific,
        simulationSeed: 1,
      );

      expect(franchise.team.name, 'Comets');
      expect(franchise.team.location, 'Springfield, IL');
      expect(franchise.team.conference, Conference.pacific);
      expect(franchise.team.abbreviation, 'COM');
      expect(
        franchise.roster.where((m) => m.status == RosterStatus.active),
        hasLength(12),
      );
    });

    test('leaves every appearance null when portraitWeights is omitted', () {
      final franchise = createExpansionFranchise(
        gmName: 'Jordan Ellis',
        clubName: 'Comets',
        homeCity: 'Springfield, IL',
        conference: Conference.pacific,
        simulationSeed: 1,
      );

      expect(franchise.coach.appearance, isNull);
      expect(
        franchise.roster.every((m) => m.player.appearance == null),
        isTrue,
      );
    });

    test('generates a coach and every roster player an appearance when '
        'portraitWeights is given', () {
      final franchise = createExpansionFranchise(
        gmName: 'Jordan Ellis',
        clubName: 'Comets',
        homeCity: 'Springfield, IL',
        conference: Conference.pacific,
        simulationSeed: 1,
        portraitWeights: _portraitWeights,
      );

      expect(franchise.coach.appearance, isNotNull);
      expect(franchise.coach.appearance!.isCoach, isTrue);
      expect(
        franchise.roster.every(
          (m) => m.player.appearance != null && !m.player.appearance!.isCoach,
        ),
        isTrue,
      );
    });
  });
}
