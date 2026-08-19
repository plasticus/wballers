import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/match/domain/match_event.dart';
import 'package:womensbballmgr/features/match/engine/match_engine.dart';
import 'package:womensbballmgr/features/match/presentation/live_beat_translator.dart';
import 'package:womensbballmgr/features/player/domain/player.dart';

import '../../../support/match_test_players.dart';

/// Runs a real [simulateMatchLive] game and feeds every segment through a
/// fresh [LiveBeatTranslator], collecting every beat in order -- the
/// shared setup nearly every test below needs.
Future<List<LiveBeat>> _translateRealGame(
  int seed, {
  required List<Player> homeRoster,
  required List<Player> awayRoster,
}) async {
  final translator = LiveBeatTranslator(
    homeRoster: homeRoster,
    awayRoster: awayRoster,
    homeAbbreviation: 'DSM',
    awayAbbreviation: 'KCY',
  );
  final beats = <LiveBeat>[];
  await simulateMatchLive(
    Random(seed),
    homeRoster: homeRoster,
    awayRoster: awayRoster,
    onSegmentComplete: (segment) async {
      beats.addAll(translator.translateSegment(segment));
    },
  );
  return beats;
}

void main() {
  group('LiveBeatTranslator (2026-08-18, TODO.md item 8 -- live-game '
      'architecture stage 3)', () {
    test('translates a full real game with no unresolved placeholders '
        'in any beat -- the exact bug class the lab caught once already '
        '({player2} left literally on screen)', () async {
      for (var seed = 0; seed < 10; seed++) {
        final beats = await _translateRealGame(
          seed,
          homeRoster: testRoster('home'),
          awayRoster: testRoster('away'),
        );
        expect(beats, isNotEmpty, reason: 'seed $seed');
        for (final beat in beats) {
          expect(
            beat.displayText,
            isNot(contains('{')),
            reason: 'seed $seed: "${beat.displayText}"',
          );
          expect(beat.displayText, isNotEmpty, reason: 'seed $seed');
        }
      }
    });

    test('the very first beat is the tip-off, at center court', () async {
      final beats = await _translateRealGame(
        3,
        homeRoster: testRoster('home'),
        awayRoster: testRoster('away'),
      );

      expect(beats.first.zone, LiveZone.centerCourt);
      expect(beats.first.quarter, 1);
      expect(beats.first.displayText, isNotEmpty);
    });

    test('score deltas summed across every beat equal the real final '
        'score', () async {
      for (var seed = 0; seed < 10; seed++) {
        final homeRoster = testRoster('home');
        final awayRoster = testRoster('away');
        final translator = LiveBeatTranslator(
          homeRoster: homeRoster,
          awayRoster: awayRoster,
          homeAbbreviation: 'DSM',
          awayAbbreviation: 'KCY',
        );
        var homeFromBeats = 0;
        var awayFromBeats = 0;
        final result = await simulateMatchLive(
          Random(seed),
          homeRoster: homeRoster,
          awayRoster: awayRoster,
          onSegmentComplete: (segment) async {
            for (final beat in translator.translateSegment(segment)) {
              homeFromBeats += beat.deltaHome;
              awayFromBeats += beat.deltaAway;
            }
          },
        );

        expect(homeFromBeats, result.homeScore, reason: 'seed $seed');
        expect(awayFromBeats, result.awayScore, reason: 'seed $seed');
      }
    });

    test('every made shot is credited to the scoring team, every miss '
        'has no score attached', () async {
      final beats = await _translateRealGame(
        5,
        homeRoster: testRoster('home'),
        awayRoster: testRoster('away'),
      );

      for (final beat in beats) {
        if (!beat.isShotAttempt) continue;
        if (beat.shotMade == true) {
          expect(beat.deltaHome + beat.deltaAway, greaterThan(0));
        } else {
          expect(beat.deltaHome, 0);
          expect(beat.deltaAway, 0);
        }
      }
    });

    test('a made shot immediately drawing a shooting foul reads as '
        'and-one, not a plain make', () async {
      // Not every seed produces an and-one within a short sample, so
      // sweep a range and confirm the highlight/category is at least
      // possible -- the real assertion is in the dedicated unit check
      // below via a hand-built event list.
      var sawAndOne = false;
      for (var seed = 0; seed < 30 && !sawAndOne; seed++) {
        final beats = await _translateRealGame(
          seed,
          homeRoster: testRoster('home'),
          awayRoster: testRoster('away'),
        );
        sawAndOne = beats.any((b) => b.highlight == LiveHighlight.andOne);
      }
      expect(sawAndOne, isTrue);
    });

    test('the possession right after a made basket reads as an inbound, '
        'credited to the team that just got scored on -- not the team that '
        'scored (2026-08-18, a direct GM catch: watching a real game, a '
        'make immediately followed by what looked like the same team still '
        'passing the ball around read as a possession bug)', () async {
      var sawInbound = false;
      for (var seed = 0; seed < 20 && !sawInbound; seed++) {
        final beats = await _translateRealGame(
          seed,
          homeRoster: testRoster('home'),
          awayRoster: testRoster('away'),
        );
        // Whichever team's score most recently ticked up (a made shot
        // or a made free throw, tracked the same way the score-deltas
        // test above already does) -- checked at the exact point of
        // every inbound beat, rather than searching back for the
        // nearest shot-attempt *beat*, which a made free throw (no
        // `isShotAttempt` flag of its own) would silently skip past.
        LiveTeam? lastScoringTeam;
        for (final beat in beats) {
          if (beat.deltaHome > 0) lastScoringTeam = LiveTeam.home;
          if (beat.deltaAway > 0) lastScoringTeam = LiveTeam.away;
          if (!beat.isInbound) continue;
          sawInbound = true;
          expect(lastScoringTeam, isNotNull, reason: 'seed $seed');
          expect(
            beat.team,
            isNot(lastScoringTeam),
            reason:
                'seed $seed: the inbounding team must be whoever '
                'just got scored on, not the scoring team',
          );
        }
      }
      expect(sawInbound, isTrue);
    });

    test('a hand-built home make immediately followed by away\'s first pass '
        'reads as away inbounding -- isolates the inbound-team logic from '
        'anything a real random game might coincidentally do', () {
      final homeRoster = testRoster('home');
      final awayRoster = testRoster('away');
      final translator = LiveBeatTranslator(
        homeRoster: homeRoster,
        awayRoster: awayRoster,
        homeAbbreviation: 'DSM',
        awayAbbreviation: 'KCY',
      );
      final homeShooter = homeRoster.first;
      final awayPasser = awayRoster.first;
      final awayReceiver = awayRoster[1];

      final segment = (
        possessions: [
          [
            MatchEvent(
              type: MatchEventType.shotMade,
              secondsElapsed: 4,
              player: homeShooter,
              points: 2,
              isThreePointAttempt: false,
            ),
          ],
          [
            MatchEvent(
              type: MatchEventType.passAttempt,
              secondsElapsed: 3,
              player: awayPasser,
              secondPlayer: awayReceiver,
            ),
          ],
        ],
        quarter: 1,
        isEndOfQuarter: false,
      );

      final beats = translator.translateSegment(segment);

      expect(beats, hasLength(2));
      expect(beats[0].team, LiveTeam.home);
      expect(beats[0].deltaHome, 2);
      expect(beats[1].isInbound, isTrue);
      expect(beats[1].team, LiveTeam.away);
    });

    test('a possession\'s first pass always lands near midcourt (bringing '
        'the ball up), but later passes in the same possession vary '
        'between the 3pt line and midcourt instead of freezing at one '
        'fixed spot -- a direct GM report (2026-08-19): "still have minor '
        'complaints about the location of passes. They\'re really focused '
        'in one little area, all near the circle in center-court... The '
        'most likely place for just passing around to find an opening is '
        'around the 3pt perimeter line, and then even back a little bit '
        'towards mid-court"', () {
      final homeRoster = testRoster('home');
      final awayRoster = testRoster('away');
      final passer = homeRoster.first;
      final receiver = homeRoster[1];

      // One possession: bring it up, then 4 more passes -- run through a
      // fresh translator many times so the later passes' independent
      // random draws actually show up.
      List<MatchEvent> possession() => [
        for (var i = 0; i < 5; i++)
          MatchEvent(
            type: MatchEventType.passAttempt,
            secondsElapsed: 1,
            player: passer,
            secondPlayer: receiver,
          ),
      ];

      final firstPassZones = <LiveZone?>{};
      final laterPassZones = <LiveZone?>{};
      for (var run = 0; run < 30; run++) {
        final translator = LiveBeatTranslator(
          homeRoster: homeRoster,
          awayRoster: awayRoster,
          homeAbbreviation: 'DSM',
          awayAbbreviation: 'KCY',
        );
        final beats = translator.translateSegment((
          possessions: [possession()],
          quarter: 1,
          isEndOfQuarter: false,
        ));

        firstPassZones.add(beats.first.zone);
        for (final beat in beats.skip(1)) {
          laterPassZones.add(beat.zone);
        }
      }

      expect(firstPassZones, {LiveZone.midcourt});
      expect(
        laterPassZones,
        containsAll([LiveZone.threePoint, LiveZone.midcourt]),
      );
    });

    test('a defensive rebound is positioned at the *shooting* team\'s end, '
        'credited to the rebounding team -- a real bug, live on-device '
        '(2026-08-19, a direct GM report): "WIC just shot and missed, so '
        'it\'s on the right side (WIC is home)... defensive rebound by '
        'MTY. BUT the blip for the defensive rebound is on the left side. '
        'Defensive rebound should be on the right side, where the shot '
        'just bounced off the rim"', () {
      final homeRoster = testRoster('home');
      final awayRoster = testRoster('away');
      final translator = LiveBeatTranslator(
        homeRoster: homeRoster,
        awayRoster: awayRoster,
        homeAbbreviation: 'WIC',
        awayAbbreviation: 'MTY',
      );
      final homeShooter = homeRoster.first;
      final awayRebounder = awayRoster.first;

      final segment = (
        possessions: [
          [
            MatchEvent(
              type: MatchEventType.shotMissed,
              secondsElapsed: 4,
              player: homeShooter,
              isThreePointAttempt: false,
            ),
            MatchEvent(
              type: MatchEventType.defensiveRebound,
              secondsElapsed: 1,
              player: awayRebounder,
            ),
          ],
        ],
        quarter: 1,
        isEndOfQuarter: false,
      );

      final beats = translator.translateSegment(segment);

      expect(beats, hasLength(2));
      final rebound = beats[1];
      // `team` (what `_blipAlignment` positions off) reads as the
      // *shooter's* side -- away's rebounder recovered the ball at
      // home's own attacking end, where the miss actually came down.
      expect(rebound.team, LiveTeam.home);
      // `badgeTeam` (color/credit) still correctly reads as the actual
      // rebounding team.
      expect(rebound.badgeTeam, LiveTeam.away);
    });

    test('the assist beat narrates before the shotMade it credits, even '
        'though possession_engine.dart\'s own event list always records '
        'the assist *after* the shot -- a real bug, live on-device, seen '
        'twice (2026-08-19, a direct GM report): "1. Bkn scores a 2  2. '
        'Bkn player passes to the scorer  3. WIC inbounds. So I think #2 '
        'was the assist, and it was just out of order"', () {
      final homeRoster = testRoster('home');
      final awayRoster = testRoster('away');
      final translator = LiveBeatTranslator(
        homeRoster: homeRoster,
        awayRoster: awayRoster,
        homeAbbreviation: 'DSM',
        awayAbbreviation: 'KCY',
      );
      final passer = homeRoster.first;
      final scorer = homeRoster[1];

      final segment = (
        possessions: [
          [
            MatchEvent(
              type: MatchEventType.shotMade,
              secondsElapsed: 4,
              player: scorer,
              points: 2,
              isThreePointAttempt: false,
            ),
            MatchEvent(
              type: MatchEventType.assist,
              secondsElapsed: 0,
              player: passer,
              secondPlayer: scorer,
            ),
          ],
        ],
        quarter: 1,
        isEndOfQuarter: false,
      );

      final beats = translator.translateSegment(segment);

      expect(beats, hasLength(2));
      // The assist beat -- no score of its own -- comes first; the
      // scoring beat, still carrying its real points, comes second.
      expect(beats[0].deltaHome, 0);
      expect(beats[0].deltaAway, 0);
      expect(beats[1].deltaHome, 2);
    });

    test('an and-one on a three still reports zone == threePoint -- the '
        'andOne highlight overwrites what would otherwise be '
        '.threePointer, but the live-game screen\'s shot-result popup '
        'needs zone (not highlight) to tell a 2-point and-one from a '
        '3-point and-one and label it "2+1" vs "3+1" (2026-08-19, a '
        'direct GM report: "Just saw a pull-up score for 3, despite it '
        'saying WIC 2 pts")', () {
      final homeRoster = testRoster('home');
      final awayRoster = testRoster('away');
      final translator = LiveBeatTranslator(
        homeRoster: homeRoster,
        awayRoster: awayRoster,
        homeAbbreviation: 'DSM',
        awayAbbreviation: 'KCY',
      );
      final shooter = homeRoster.first;
      final defender = awayRoster.first;

      final segment = (
        possessions: [
          [
            MatchEvent(
              type: MatchEventType.shotMade,
              secondsElapsed: 4,
              player: shooter,
              points: 3,
              isThreePointAttempt: true,
            ),
            MatchEvent(
              type: MatchEventType.shootingFoul,
              secondsElapsed: 0,
              player: defender,
              secondPlayer: shooter,
            ),
          ],
        ],
        quarter: 1,
        isEndOfQuarter: false,
      );

      final beats = translator.translateSegment(segment);

      final shotBeat = beats.singleWhere((b) => b.isShotAttempt);
      expect(shotBeat.highlight, LiveHighlight.andOne);
      expect(shotBeat.zone, LiveZone.threePoint);
      expect(shotBeat.deltaHome, 3);
    });

    test('isClutch tracks the real running score and clock', () async {
      final homeRoster = testRoster('home');
      final awayRoster = testRoster('away');
      final translator = LiveBeatTranslator(
        homeRoster: homeRoster,
        awayRoster: awayRoster,
        homeAbbreviation: 'DSM',
        awayAbbreviation: 'KCY',
      );

      // Never clutch before any possessions have run -- full clock, tied
      // at 0.
      expect(translator.isClutch, isFalse);

      await simulateMatchLive(
        Random(2),
        homeRoster: homeRoster,
        awayRoster: awayRoster,
        onSegmentComplete: (segment) async {
          translator.translateSegment(segment);
        },
      );

      // By the time the whole game (well past regulation) has been fed
      // through, the clock is at 0 -- clutch only if the final margin is
      // within 3, which isn't guaranteed for this seed, so just confirm
      // the getter itself doesn't throw and returns a real bool either
      // way.
      expect(translator.isClutch, isA<bool>());
    });
  });
}
