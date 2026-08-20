import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/coach/domain/coach_archetype.dart';
import 'package:womensbballmgr/features/league/domain/initial_league.dart';
import 'package:womensbballmgr/features/league/domain/team_identity.dart';
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
        '${identity.positionLean.label}-leaning.',
      );
    });
  });
}
