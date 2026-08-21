import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/coach/domain/coach_archetype.dart';
import 'package:womensbballmgr/features/league/domain/initial_league.dart';
import 'package:womensbballmgr/features/league/domain/team_identity.dart';
import 'package:womensbballmgr/features/matchup/domain/offense_shape.dart';
import 'package:womensbballmgr/features/player/domain/player.dart';

void main() {
  group('identityFor (2026-08-20, a direct GM ask: lightweight team '
      'identities)', () {
    test('is deterministic for the same abbreviation, called repeatedly', () {
      final a = identityFor('BOS');
      final b = identityFor('BOS');

      expect(a.archetype, b.archetype);
      expect(a.positionLean, b.positionLean);
    });

    test('different abbreviations can produce different identities', () {
      final identities = {
        for (final team in kLeagueTeamPool)
          team.abbreviation: identityFor(team.abbreviation),
      };

      // Not every one of the 40 real teams should land on the exact same
      // archetype -- real variety, not a constant-valued bug.
      final archetypes = identities.values.map((i) => i.archetype).toSet();
      final positionLeans = identities.values
          .map((i) => i.positionLean)
          .toSet();
      expect(archetypes.length, greaterThan(1));
      expect(positionLeans.length, greaterThan(1));
    });

    test('styleLabel is plain facts, no authored prose (a direct GM call: '
        '"no prose, just the facts")', () {
      final identity = identityFor('BOS');

      expect(
        identity.styleLabel,
        'Coaching style: ${identity.archetype.label}. Roster strength: '
        '${identity.positionLean.label}-leaning. Preferred shape: '
        '${identity.preferredShape.label}.',
      );
    });

    test('preferredShape lands on OffenseShape.traditional roughly half the '
        'time, split evenly across the other 3 shapes the rest '
        '(2026-08-21, a direct GM ask: "50% would try for the standard '
        'shape, and 50% other stuff")', () {
      final counts = <OffenseShape, int>{
        for (final shape in OffenseShape.values) shape: 0,
      };
      for (var i = 0; i < 2000; i++) {
        final shape = identityFor('TEAM$i').preferredShape;
        counts[shape] = counts[shape]! + 1;
      }
      // Traditional should land close to 50% -- generous tolerance
      // since this is real randomness, not a hand-picked fixture.
      expect(counts[OffenseShape.traditional]!, greaterThan(2000 * 0.4));
      expect(counts[OffenseShape.traditional]!, lessThan(2000 * 0.6));
      // Every other shape should show up too -- roughly a sixth each.
      for (final shape in [
        OffenseShape.paceAndSpace,
        OffenseShape.postUp,
        OffenseShape.motion,
      ]) {
        expect(counts[shape]!, greaterThan(0));
      }
    });
  });
}
