import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/draft/domain/draft_in_progress.dart';
import 'package:womensbballmgr/features/draft/domain/draft_pick.dart';
import 'package:womensbballmgr/features/draft/domain/draft_prospect.dart';
import 'package:womensbballmgr/features/player/domain/college.dart';

import '../../roster/domain/roster_test_helpers.dart';

DraftPick _pick(int round, int pickNumber, String team) {
  return DraftPick(
    round: round,
    pickNumber: pickNumber,
    teamAbbreviation: team,
    prospect: DraftProspect(
      player: playerWithOverall(
        50,
        id: 'p-$pickNumber',
        name: 'Pick $pickNumber',
      ),
      college: kColleges.first,
    ),
  );
}

void main() {
  group('DraftInProgress', () {
    test('is not complete until every slot across every round has picked', () {
      final draft = DraftInProgress(
        order: const ['AAA', 'BBB'],
        rounds: 2,
        picks: [_pick(1, 1, 'AAA'), _pick(1, 2, 'BBB'), _pick(2, 3, 'AAA')],
      );

      expect(draft.isComplete, isFalse);
      expect(draft.onTheClock, 'BBB');
      expect(draft.nextRound, 2);
      expect(draft.nextOverallPick, 4);
    });

    test('is complete once order.length * rounds picks exist', () {
      final draft = DraftInProgress(
        order: const ['AAA', 'BBB'],
        rounds: 2,
        picks: [
          _pick(1, 1, 'AAA'),
          _pick(1, 2, 'BBB'),
          _pick(2, 3, 'AAA'),
          _pick(2, 4, 'BBB'),
        ],
      );

      expect(draft.isComplete, isTrue);
      expect(draft.onTheClock, isNull);
    });

    test(
      'a fresh draft has nobody on the clock but the first team in order',
      () {
        final draft = DraftInProgress(
          order: const ['AAA', 'BBB', 'CCC'],
          rounds: 3,
        );

        expect(draft.onTheClock, 'AAA');
        expect(draft.nextRound, 1);
        expect(draft.nextOverallPick, 1);
        expect(draft.isComplete, isFalse);
      },
    );

    test('onTheClock cycles back to the start of order every round', () {
      final draft = DraftInProgress(
        order: const ['AAA', 'BBB', 'CCC'],
        rounds: 3,
        picks: [_pick(1, 1, 'AAA'), _pick(1, 2, 'BBB'), _pick(1, 3, 'CCC')],
      );

      expect(draft.onTheClock, 'AAA');
      expect(draft.nextRound, 2);
    });

    test('onTheClock resolves through pickOwnershipOverrides -- a traded '
        'pick puts the acquiring team on the clock, not the natal one', () {
      final draft = DraftInProgress(
        order: const ['AAA', 'BBB', 'CCC'],
        rounds: 2,
        pickOwnershipOverrides: const {
          1: {'AAA': 'CCC'},
        },
      );

      expect(draft.onTheClock, 'CCC');
    });

    test('a traded pick\'s override only applies to its own round -- the '
        'natal team is still on the clock for every other round', () {
      final draft = DraftInProgress(
        order: const ['AAA', 'BBB'],
        rounds: 2,
        picks: [_pick(1, 1, 'CCC'), _pick(1, 2, 'BBB')],
        pickOwnershipOverrides: const {
          1: {'AAA': 'CCC'},
        },
      );

      // Round 2 has no override for AAA -- back to the natal owner.
      expect(draft.onTheClock, 'AAA');
    });

    group('remainingPicksFor (2026-08-22, a direct GM ask: "it should say all '
        'of my picks remaining, and their overall number")', () {
      test('lists every not-yet-made natal slot, one per round, in round '
          'order', () {
        final draft = DraftInProgress(
          order: const ['AAA', 'BBB', 'CCC'],
          rounds: 3,
        );

        final remaining = draft.remainingPicksFor('AAA');

        expect(remaining, [
          (round: 1, overallPickNumber: 1, natalTeamAbbreviation: 'AAA'),
          (round: 2, overallPickNumber: 4, natalTeamAbbreviation: 'AAA'),
          (round: 3, overallPickNumber: 7, natalTeamAbbreviation: 'AAA'),
        ]);
      });

      test('omits a slot that\'s already been made, even by someone '
          'else entirely', () {
        final draft = DraftInProgress(
          order: const ['AAA', 'BBB', 'CCC'],
          rounds: 2,
          picks: [_pick(1, 1, 'AAA'), _pick(1, 2, 'BBB'), _pick(1, 3, 'CCC')],
        );

        final remaining = draft.remainingPicksFor('AAA');

        expect(remaining, [
          (round: 2, overallPickNumber: 4, natalTeamAbbreviation: 'AAA'),
        ]);
      });

      test('includes a slot acquired via trade, naming the real natal '
          'team it came from -- and no longer includes it for the team '
          'that traded it away', () {
        final draft = DraftInProgress(
          order: const ['AAA', 'BBB', 'CCC'],
          rounds: 2,
          pickOwnershipOverrides: const {
            2: {'BBB': 'AAA'},
          },
        );

        final aaaRemaining = draft.remainingPicksFor('AAA');
        final bbbRemaining = draft.remainingPicksFor('BBB');

        expect(aaaRemaining, [
          (round: 1, overallPickNumber: 1, natalTeamAbbreviation: 'AAA'),
          // AAA's own natal round-2 slot, untouched by the trade.
          (round: 2, overallPickNumber: 4, natalTeamAbbreviation: 'AAA'),
          // Plus BBB's round-2 slot, acquired via the trade.
          (round: 2, overallPickNumber: 5, natalTeamAbbreviation: 'BBB'),
        ]);
        expect(bbbRemaining, [
          (round: 1, overallPickNumber: 2, natalTeamAbbreviation: 'BBB'),
        ]);
      });

      test('is empty for a team with no picks left at all', () {
        final draft = DraftInProgress(
          order: const ['AAA', 'BBB'],
          rounds: 1,
          picks: [_pick(1, 1, 'AAA'), _pick(1, 2, 'BBB')],
        );

        expect(draft.remainingPicksFor('AAA'), isEmpty);
      });
    });
  });
}
