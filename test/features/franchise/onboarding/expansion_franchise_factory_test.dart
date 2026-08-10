import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/franchise/onboarding/expansion_franchise_factory.dart'
    show createExpansionFranchise, deriveTeamAbbreviation, kStarterPalettes;
import 'package:womensbballmgr/features/league/domain/team.dart';
import 'package:womensbballmgr/features/portrait/domain/portrait_manifest.dart';
import 'package:womensbballmgr/features/portrait/domain/portrait_weights.dart';
import 'package:womensbballmgr/features/roster/domain/roster_status.dart';

final _portraitManifest = PortraitManifest(
  hair: const ['hair_afro.png'],
  eyes: const ['eyes_1center.png'],
  eyebrows: const ['eyebrow_1.png'],
  nose: const ['nose_1.png'],
  mouth: const ['mouth_1.png'],
  facial: const ['facial_goat.png'],
  accessories: const ['goggles_1.png'],
  shoulders: const ['shoulder_black.png', 'shoulder_grey.png'],
  hats: const ['hat_fedora.png'],
  glasses: const ['glasses_round.png'],
);

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
        replacedTeamAbbreviation: 'DET',
        colors: kStarterPalettes.first,
        emoji: '🏀',
        simulationSeed: 555,
      );
      final b = createExpansionFranchise(
        gmName: 'Jordan Ellis',
        clubName: 'Comets',
        homeCity: 'Springfield, IL',
        conference: Conference.atlantic,
        replacedTeamAbbreviation: 'DET',
        colors: kStarterPalettes.first,
        emoji: '🏀',
        simulationSeed: 555,
      );

      expect(a.id, b.id);
      expect(a.coach.name, b.coach.name);
      expect(a.coach.stats.overall, b.coach.stats.overall);
      expect(a.team.colors.primaryHex, b.team.colors.primaryHex);
      for (var i = 0; i < a.roster.length; i++) {
        expect(a.roster[i].player.name, b.roster[i].player.name);
      }
      expect(
        a.seasonProgress.schedule.games.length,
        b.seasonProgress.schedule.games.length,
      );
    });

    test('generates a season schedule that includes the GM\'s own club, '
        'not the team it replaced', () {
      final franchise = createExpansionFranchise(
        gmName: 'Jordan Ellis',
        clubName: 'Comets',
        homeCity: 'Springfield, IL',
        conference: Conference.atlantic,
        replacedTeamAbbreviation: 'DET',
        colors: kStarterPalettes.first,
        emoji: '🏀',
        simulationSeed: 555,
      );

      final scheduledAbbreviations = {
        for (final game in franchise.seasonProgress.schedule.games) ...[
          game.homeTeamAbbreviation,
          game.awayTeamAbbreviation,
        ],
      };
      expect(scheduledAbbreviations, contains(franchise.team.abbreviation));
      expect(scheduledAbbreviations, isNot(contains('DET')));
    });

    test('a fresh franchise starts at the preseason with nothing played '
        'yet', () {
      final franchise = createExpansionFranchise(
        gmName: 'Jordan Ellis',
        clubName: 'Comets',
        homeCity: 'Springfield, IL',
        conference: Conference.atlantic,
        replacedTeamAbbreviation: 'DET',
        colors: kStarterPalettes.first,
        emoji: '🏀',
        simulationSeed: 555,
      );

      expect(franchise.seasonProgress.nextGameDayIndex, 0);
      expect(franchise.seasonProgress.playedGames, isEmpty);
    });

    test('the GM is not the coach -- both are set, and distinctly', () {
      final franchise = createExpansionFranchise(
        gmName: 'Jordan Ellis',
        clubName: 'Comets',
        homeCity: 'Springfield, IL',
        conference: Conference.pacific,
        replacedTeamAbbreviation: 'DEN',
        colors: kStarterPalettes.first,
        emoji: '🏀',
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

    test('sets the team identity and a one-short-of-full active roster', () {
      final franchise = createExpansionFranchise(
        gmName: 'Jordan Ellis',
        clubName: 'Comets',
        homeCity: 'Springfield, IL',
        conference: Conference.pacific,
        replacedTeamAbbreviation: 'DEN',
        colors: kStarterPalettes.first,
        emoji: '🏀',
        simulationSeed: 1,
      );

      expect(franchise.team.name, 'Comets');
      expect(franchise.team.location, 'Springfield, IL');
      expect(franchise.team.conference, Conference.pacific);
      expect(franchise.team.abbreviation, 'COM');
      // 11, not 12 -- a real Day-0 hook: the GM has to sign a free agent
      // to fill the last spot before advancing (see
      // `starting_roster_generator.dart`'s doc comment).
      expect(
        franchise.roster.where((m) => m.status == RosterStatus.active),
        hasLength(11),
      );
    });

    test('explicit homeState/abbreviation match the AI pool\'s "ABBR · City, '
        'ST" convention exactly -- the real fix behind a direct GM report '
        '(2026-08-10): a club named "Deebers" in "Des Moines" was only ever '
        'showing "DEE · Des Moines", never "Des Moines, IA" or a chosen '
        'abbreviation', () {
      final franchise = createExpansionFranchise(
        gmName: 'Jordan Ellis',
        clubName: 'Des Moines Deebers',
        homeCity: 'Des Moines',
        homeState: 'IA',
        abbreviation: 'DSM',
        conference: Conference.pacific,
        replacedTeamAbbreviation: 'DEN',
        colors: kStarterPalettes.first,
        emoji: '🏀',
        simulationSeed: 1,
      );

      expect(franchise.team.name, 'Des Moines Deebers');
      expect(franchise.team.location, 'Des Moines, IA');
      expect(franchise.team.abbreviation, 'DSM');
    });

    test('an empty homeState falls back to bare homeCity, same as omitting '
        'it entirely', () {
      final franchise = createExpansionFranchise(
        gmName: 'Jordan Ellis',
        clubName: 'Comets',
        homeCity: 'Springfield',
        homeState: '',
        abbreviation: 'COM',
        conference: Conference.pacific,
        replacedTeamAbbreviation: 'DEN',
        colors: kStarterPalettes.first,
        emoji: '🏀',
        simulationSeed: 1,
      );

      expect(franchise.team.location, 'Springfield');
    });

    test('generates a free-agent pool with a real high-potential '
        'prospect in it', () {
      final franchise = createExpansionFranchise(
        gmName: 'Jordan Ellis',
        clubName: 'Comets',
        homeCity: 'Springfield, IL',
        conference: Conference.pacific,
        replacedTeamAbbreviation: 'DEN',
        colors: kStarterPalettes.first,
        emoji: '🏀',
        simulationSeed: 1,
      );

      expect(franchise.freeAgents, hasLength(12));
      // The one deliberately-planted "decent" prospect always lands
      // right around the target potential -- filler players can
      // occasionally roll a high potential too (it's driven by age, not
      // quality center, so this isn't a safe way to single the prospect
      // out), but at least one player at this level is guaranteed.
      expect(
        franchise.freeAgents.map((p) => p.ratings.potential),
        contains(inInclusiveRange(77, 83)),
      );
    });

    test('leaves every appearance null when portraitWeights is omitted', () {
      final franchise = createExpansionFranchise(
        gmName: 'Jordan Ellis',
        clubName: 'Comets',
        homeCity: 'Springfield, IL',
        conference: Conference.pacific,
        replacedTeamAbbreviation: 'DEN',
        colors: kStarterPalettes.first,
        emoji: '🏀',
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
        replacedTeamAbbreviation: 'DEN',
        colors: kStarterPalettes.first,
        emoji: '🏀',
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

    test('the coach gets shoulders when portraitManifest is also given, '
        'players never do', () {
      final franchise = createExpansionFranchise(
        gmName: 'Jordan Ellis',
        clubName: 'Comets',
        homeCity: 'Springfield, IL',
        conference: Conference.pacific,
        replacedTeamAbbreviation: 'DEN',
        colors: kStarterPalettes.first,
        emoji: '🏀',
        simulationSeed: 1,
        portraitWeights: _portraitWeights,
        portraitManifest: _portraitManifest,
      );

      expect(franchise.coach.appearance!.shoulders, isNotNull);
      expect(
        franchise.roster.every((m) => m.player.appearance!.shoulders == null),
        isTrue,
      );
    });
  });
}
