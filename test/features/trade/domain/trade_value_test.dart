import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/trade/domain/trade_value.dart';

/// Covers the objective trade-value math locked 2026-08-19 -- see
/// `trading-and-hidden-gems-notes.md` for the full worked cases this
/// file's numbers came from. Every assertion here mirrors a real hand-
/// checked scenario from that back-and-forth, not an arbitrary pick.
void main() {
  group('tradeSwing', () {
    test('the anchor point: Management 50 lands on exactly 24', () {
      expect(tradeSwing(50), 24);
    });

    test('never drops below kMinTradeSwing, even at the bottom of the '
        'rating scale', () {
      expect(tradeSwing(1), kMinTradeSwing);
      expect(tradeSwing(29), kMinTradeSwing); // the real generation floor
    });

    test('matches the 3 reference points worked out by hand: 30/50/70 -> '
        '11/24/47', () {
      expect(tradeSwing(30), 11);
      expect(tradeSwing(50), 24);
      expect(tradeSwing(70), 47);
    });

    test('at the true coach-generation ceiling (79), swing is 60', () {
      expect(tradeSwing(kMaxCoachManagement), 60);
    });

    test('monotonically increasing across the whole 1-99 range', () {
      var previous = tradeSwing(1);
      for (var management = 2; management <= 99; management++) {
        final current = tradeSwing(management);
        expect(current, greaterThanOrEqualTo(previous));
        previous = current;
      }
    });
  });

  group('draftPickTradeValue', () {
    test('the locked ladder: round 1/2/3 -> 290/150/50', () {
      expect(draftPickTradeValue(1), 290);
      expect(draftPickTradeValue(2), 150);
      expect(draftPickTradeValue(3), 50);
    });

    test('round 1-to-2 is a bigger jump than round 2-to-3, on purpose -- '
        'matches the real generated draft data\'s own shape', () {
      final round1To2 = draftPickTradeValue(1) - draftPickTradeValue(2);
      final round2To3 = draftPickTradeValue(2) - draftPickTradeValue(3);
      expect(round1To2, greaterThan(round2To3));
    });

    test('an out-of-range round is worth nothing, not a crash', () {
      expect(draftPickTradeValue(4), 0);
      expect(draftPickTradeValue(0), 0);
    });
  });

  group('isTradeWithinManagementSwing -- the 3 canonical cases', () {
    test('Case A: a plain 1:1 works at Management 50 (gap 24, right at '
        'the edge) and fails at 30 (swing only 11)', () {
      // 900 vs 924.
      expect(
        isTradeWithinManagementSwing(
          offeredValue: 900,
          requestedValue: 924,
          management: 50,
        ),
        isTrue,
      );
      expect(
        isTradeWithinManagementSwing(
          offeredValue: 900,
          requestedValue: 924,
          management: 30,
        ),
        isFalse,
      );
    });

    test('Case B: All-Star (1080) + a 3rd-round pick for Phenom (960) + '
        'a 2nd-round pick -- works at Management 50, fails at 30', () {
      const offered = 1080 + 50; // All-Star + R3
      const requested = 960 + 150; // Phenom + R2
      expect(
        isTradeWithinManagementSwing(
          offeredValue: offered,
          requestedValue: requested,
          management: 50,
        ),
        isTrue,
      );
      expect(
        isTradeWithinManagementSwing(
          offeredValue: offered,
          requestedValue: requested,
          management: 30,
        ),
        isFalse,
      );
    });

    test('Case B, a bigger star (1140) instead of a plain All-Star -- '
        'even the best swap fails at Management 50, but clears at 70', () {
      const offered = 1140 + 150; // bigger star + R2 (the better swap)
      const requested = 960 + 290; // Phenom + R1
      expect(
        isTradeWithinManagementSwing(
          offeredValue: offered,
          requestedValue: requested,
          management: 50,
        ),
        isFalse,
      );
      expect(
        isTradeWithinManagementSwing(
          offeredValue: offered,
          requestedValue: requested,
          management: 70,
        ),
        isTrue,
      );
    });

    test('Case C: a 2-for-2 sweetened with a 3rd-round pick lands exactly '
        'even, so it clears at every Management level', () {
      const teamA = 900 + 950;
      const teamB = 900 + 900 + 50; // + R3
      expect(teamA, teamB); // exactly even, per the locked ladder
      expect(
        isTradeWithinManagementSwing(
          offeredValue: teamA,
          requestedValue: teamB,
          management: 1,
        ),
        isTrue,
      );
    });

    test('Case C, a wider natural gap -- neither pick closes it at '
        'Management 50, but the better one (R2) clears at 70', () {
      const teamA = 920 + 950;
      const teamBWithR3 = 880 + 880 + 50;
      const teamBWithR2 = 880 + 880 + 150;
      expect(
        isTradeWithinManagementSwing(
          offeredValue: teamA,
          requestedValue: teamBWithR3,
          management: 50,
        ),
        isFalse,
      );
      expect(
        isTradeWithinManagementSwing(
          offeredValue: teamA,
          requestedValue: teamBWithR2,
          management: 50,
        ),
        isFalse,
      );
      expect(
        isTradeWithinManagementSwing(
          offeredValue: teamA,
          requestedValue: teamBWithR2,
          management: 70,
        ),
        isTrue,
      );
    });

    test('is symmetric -- doesn\'t matter which side is "offered" vs '
        '"requested"', () {
      final forward = isTradeWithinManagementSwing(
        offeredValue: 900,
        requestedValue: 950,
        management: 50,
      );
      final backward = isTradeWithinManagementSwing(
        offeredValue: 950,
        requestedValue: 900,
        management: 50,
      );
      expect(forward, backward);
    });
  });
}
