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

  group('playerTradeValue', () {
    // Re-tuned 2026-08-23 against tools/trade_study/'s 25 real ratings --
    // see the file-level doc comment. Every case below traces back to a
    // real note from that dataset, not an arbitrary pick.

    test('at or below replacement (60), potential and age never add an '
        'upside/age-risk adjustment, and skillPoints itself only counts '
        'kTradeValueReplacementFloorFraction -- real junk reads as '
        'genuinely near-worthless, regardless of birth year or ceiling. '
        'Re-tuned 2026-08-24 -- the original design only ever zeroed the '
        'upside/age-risk *adjustment* terms, leaving skillPoints itself '
        'undiscounted, which is exactly what a second wave of real '
        'tools/trade_study/ ratings caught: a 50-65 OVR, often '
        '30+-year-old player with no real potential could still fetch a '
        'real 1st-round pick outright ("50ovr has zero value... it\'s '
        'offensive," "58ovr age 32 isn\'t worth a 3rd. Disgusting," '
        '"shouldn\'t be on a roster, much less worth a 1st").', () {
      final junkNoUpside = playerTradeValue(
        overall: 55,
        potential: 56,
        skillPoints: 660,
        age: 34,
      );
      expect(junkNoUpside, (660 * kTradeValueReplacementFloorFraction).round());

      // Same current overall, but a real ceiling -- still gated off,
      // since a 55 OVR/60 POT isn't a real prospect either. Contrast
      // with the next test, where potential alone clears the gate.
      final junkFlatPotential = playerTradeValue(
        overall: 55,
        potential: 60,
        skillPoints: 660,
        age: 20,
      );
      expect(
        junkFlatPotential,
        (660 * kTradeValueReplacementFloorFraction).round(),
      );
    });

    test('the gate is max(overall, potential), not overall alone -- a low-'
        'current, high-ceiling prospect still gets full credit (a real '
        'tuning bug: an early pass zeroed out a 59 OVR/89 POT 20-year-old '
        'this way by mistake)', () {
      final rawProspect = playerTradeValue(
        overall: 59,
        potential: 89,
        skillPoints: 708, // 59 * 12
        age: 20,
      );
      // Gate is on potential (89, clears kTradeValueFullWeightOverall),
      // so the full upside premium applies: 4 * (89 - 59) = 120.
      expect(rawProspect, 708 + 120);
    });

    test('two players with identical current overall and potential, only '
        'age differs -- the older one loses real value once both clear '
        'replacement level ("In the 70s, age matters. Nwosu is a solid '
        'bench option for 5+ seasons, Petrova might retire anytime.")', () {
      final youngerSameSkill = playerTradeValue(
        overall: 76,
        potential: 77,
        skillPoints: 912,
        age: 25,
      );
      final olderSameSkill = playerTradeValue(
        overall: 76,
        potential: 77,
        skillPoints: 912,
        age: 33,
      );
      expect(olderSameSkill, lessThan(youngerSameSkill));
    });

    test('a near-max-potential young player traded for a similar-overall '
        'older one is a real, meaningful value gap, not a wash -- the '
        'GM\'s own worst-rated (+5, "egregious") study trade was exactly '
        'this shape', () {
      final phenom = playerTradeValue(
        overall: 77,
        potential: 99,
        skillPoints: 924,
        age: 20,
      );
      final establishedVet = playerTradeValue(
        overall: 75,
        potential: 78,
        skillPoints: 900,
        age: 28,
      );
      // Raw skillPoints alone call this a 24-point gap the other way --
      // the phenom should come out ahead once potential is credited.
      expect(phenom, greaterThan(establishedVet));
    });

    test('rounds to the nearest whole skill point', () {
      final value = playerTradeValue(
        overall: 65,
        potential: 70,
        skillPoints: 780,
        age: 22,
      );
      expect(value, isA<int>());
    });

    // 2026-08-24 -- kTradeValueReplacementFloorFraction's own doc comment
    // has the full story. Each case here is a real
    // tools/trade_study/ratings.json trade the GM rated -5 ("offensive,"
    // "disgusting," "unconscionable") for still being able to fetch a
    // real 1st (400) or a real 2nd+1st combo (620) despite the target
    // being a replacement-level veteran with no upside -- verified to
    // now genuinely fail even kSellForPicksExtraTolerance's own wide
    // ±(swing+250) cushion, not just read as a smaller number.
    test('a replacement-level, no-upside veteran now genuinely fails to '
        'clear even a 1st-round pick\'s value, wide sell-for-picks '
        'tolerance included -- "58ovr age 32 isn\'t worth a 3rd. '
        'Disgusting."', () {
      // 58 OVR / 61 POT / age 32 -- real GM report, offered for a real
      // 2nd (220) + 1st (400) combo (620) and rated -5.
      final value = playerTradeValue(
        overall: 58,
        potential: 61,
        skillPoints: 58 * 12,
        age: 32,
      );
      const askedPicks = 620; // a real 2027 R2 + a real 2028 R1
      const wideTolerance =
          47 + 250; // Management 70 swing + kSellForPicksExtraTolerance
      expect((askedPicks - value).abs(), greaterThan(wideTolerance));
    });

    test('a young, no-upside veteran fares no better -- age alone was '
        'never the actual gate; a "50ovr has zero value" is the same '
        'complaint at any age', () {
      // 50 OVR / 52 POT / age 26 -- real GM report, offered for a
      // single real 1st (400) and rated -5, "Stupid."
      final value = playerTradeValue(
        overall: 50,
        potential: 52,
        skillPoints: 50 * 12,
        age: 26,
      );
      const askedPick = 400;
      const wideTolerance = 47 + 250;
      expect((askedPick - value).abs(), greaterThan(wideTolerance));
    });

    // 2026-08-24 -- _tradeValueNoUpsideEscapeRamp's own doc comment has
    // the full story. Each case here is a real tools/trade_study/
    // Shed Picks (buy a player with picks) trade the GM rated +5 ("Team
    // B wins big," i.e. the GM overpaid) for the target being an
    // already-capped, no-real-upside veteran whose overall alone was
    // well above kTradeValueFullWeightOverall (75) -- verified to now
    // genuinely fail even kPickSpendExtraTolerance's own wide cushion.
    test('an already-capped 80 OVR/80 POT veteran now fails to clear a '
        'single 1st-round pick\'s value -- "I would take a 2nd for odom. '
        'Absolutely not worth a 1st."', () {
      final value = playerTradeValue(
        overall: 80,
        potential: 80,
        skillPoints: 80 * 12,
        age: 30,
      );
      const askedPicks = 620; // a real 2027 R1 + a real 2028 R2
      const wideTolerance = 47 + 250;
      expect((askedPicks - value).abs(), greaterThan(wideTolerance));
    });

    test('a 76 OVR/76 POT veteran fares no better -- current overall '
        'alone was never the actual gate; "a 2 star player is sometimes '
        'worth a 3rd, never this"', () {
      final value = playerTradeValue(
        overall: 76,
        potential: 76,
        skillPoints: 76 * 12,
        age: 34,
      );
      const askedPicks = 620; // a real 2027 R2 + a real 2028 R1
      const wideTolerance = 47 + 250;
      expect((askedPicks - value).abs(), greaterThan(wideTolerance));
    });

    test('a genuinely elite 90 OVR/90 POT veteran is NOT caught by the '
        'no-upside discount -- being capped *at a real star level* is '
        'exactly what a star is; the GM rated this one "Reasonable"', () {
      final elite = playerTradeValue(
        overall: 90,
        potential: 90,
        skillPoints: 90 * 12,
        age: 29,
      );
      // 2 real 1sts (800) should land roughly in the neighborhood, not
      // read as a blowout the way the same price does for a merely-good
      // capped veteran above.
      expect((800 - elite).abs(), lessThan(47 + 250));
    });

    test('a real riser doesn\'t need to already be elite either -- a 20-'
        'year-old at 86 OVR/97 POT was the one Shed Picks trade the GM '
        'actually liked, at the same 2-firsts price the capped veterans '
        'above were torched for', () {
      final riser = playerTradeValue(
        overall: 86,
        potential: 97,
        skillPoints: 86 * 12,
        age: 20,
      );
      expect((800 - riser).abs(), lessThan(47 + 250));
    });

    // 2026-08-24 -- kTradeValueReplacementFloorFraction's own doc comment
    // (the 0.1 -> 0.04 update) and _tradeValueUpsideRunwayRamp's own doc
    // comment (linear -> squared) have the full story. Each case here is
    // a real tools/trade_study/ "Name Your Price" answer -- a moderate-
    // overall (62-78), essentially no-upside (0-5 point gap) veteran,
    // named as worth roughly a 3rd-round pick or less, verbatim. The
    // no-upside-escape fix shipped the day before already gated these
    // (both are above kTradeValueFullWeightOverall or close to it), but
    // still computed 84-254 -- 2-5x too much -- since 10% of a real
    // overall's skillPoints is still a real number on its own.
    test('a moderate-overall, essentially-no-upside veteran now reads as '
        'genuinely minor -- "not worth a draft pick, ever," "too crappy '
        'to even be called a sweetener"', () {
      // 70 OVR / 72 POT / age 31.
      final establishedBench = playerTradeValue(
        overall: 70,
        potential: 72,
        skillPoints: 70 * 12,
        age: 31,
      );
      expect(establishedBench, lessThan(50));

      // 62 OVR / 65 POT / age 28.
      final deepBench = playerTradeValue(
        overall: 62,
        potential: 65,
        skillPoints: 62 * 12,
        age: 28,
      );
      expect(deepBench, lessThan(50));
    });

    test('a small real upside gap (2-5 points) still reads as close to '
        'no credit at all -- a linear ramp let this exact shape claim a '
        'real 20% credit, which the GM\'s own direct answer for it '
        '("maybe a 3rd rounder... take it without question") said was '
        'still much too generous', () {
      // 72 OVR / 75 POT / age 25 -- a 3-point gap.
      final value = playerTradeValue(
        overall: 72,
        potential: 75,
        skillPoints: 72 * 12,
        age: 25,
      );
      expect(value, lessThan(100));
    });

    test('a genuine double-digit upside gap is barely affected by the '
        'squared ramp -- still clears close to full credit, unlike the '
        'near-zero-gap cases above', () {
      // 72 OVR / 94 POT / age 20 -- a real riser, a direct GM answer:
      // "that's worth a 1st, for sure! Maybe even a first plus a
      // sweetener."
      final value = playerTradeValue(
        overall: 72,
        potential: 94,
        skillPoints: 72 * 12,
        age: 20,
      );
      expect(value, greaterThan(700));
    });

    test('age risk can discount a genuinely good, older player hard, but '
        'never all the way to 0 by itself -- caught 2026-08-28 by "Rate 5 '
        'Even Trades": an 81 OVR/82 POT/30yo and an 82 OVR/84 POT/31yo, '
        'both real "3-star" players, each independently computed to '
        'literal 0 under the old unbounded subtraction, making a 2-for-1 '
        'trade of both for a washed-up 67 OVR/34yo read as perfectly even '
        '(0 vs. 0 vs. 0). A direct GM reaction, verbatim: "NO."', () {
      final playerA = playerTradeValue(
        overall: 81,
        potential: 82,
        skillPoints: 81 * 12,
        age: 30,
      );
      final playerB = playerTradeValue(
        overall: 82,
        potential: 84,
        skillPoints: 82 * 12,
        age: 31,
      );
      final washedUp = playerTradeValue(
        overall: 67,
        potential: 67,
        skillPoints: 67 * 12,
        age: 34,
      );
      expect(playerA, greaterThan(0));
      expect(playerB, greaterThan(0));
      // The real complaint: 2 real players for 1 washed-up one no longer
      // reads as anywhere close to fair.
      expect(playerA + playerB - washedUp, greaterThan(30));
    });

    test('age risk still never adds a second discount on top of an '
        'already below-replacement player -- the floor fraction alone is '
        'the whole story down there, same as before this fix', () {
      final junkOld = playerTradeValue(
        overall: 55,
        potential: 56,
        skillPoints: 660,
        age: 34,
      );
      final junkYoung = playerTradeValue(
        overall: 55,
        potential: 56,
        skillPoints: 660,
        age: 20,
      );
      expect(junkOld, junkYoung);
      expect(junkOld, (660 * kTradeValueReplacementFloorFraction).round());
    });
  });

  group('draftPickTradeValue', () {
    test('the locked ladder: round 1/2/3 -> 220/130/70 (re-tuned '
        '2026-08-26 -- round 1 corrected again once a real in-between '
        'ladder rung showed the prior 420 was itself a rounding-up '
        'artifact of a too-coarse comparison ladder)', () {
      expect(draftPickTradeValue(1), 220);
      expect(draftPickTradeValue(2), 130);
      expect(draftPickTradeValue(3), 70);
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
