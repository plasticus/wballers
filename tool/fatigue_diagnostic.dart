// ignore_for_file: avoid_print
//
// Stamina/fatigue validation study (2026-08-17, a direct GM ask, right
// after `fatigue.dart`'s formulas were sanity-checked by hand against
// `substitution_policy.dart`'s target-minutes table): "is there a way to
// simulate like 20 games with it, and tell me how it affects the team,
// before moving on?" -- the hand-checked cases in `TODO.md` item 8 were
// two picked scenarios; this drives the REAL, shipped `simulateMatch`
// across many real games with real generated rosters and real
// possession-by-possession noise, to see the same formulas behave under
// actual game variance rather than hand-picked inputs.
//
// Run via `flutter test tool/fatigue_diagnostic.dart` (same
// `dart:ui`-via-Flutter-tooling reasoning as `aging_curve_diagnostic.dart`
// -- `generateAiRoster` pulls in portrait/appearance generation, which
// transitively needs Flutter's tooling to resolve). Deliberately outside
// `test/` -- a one-off data pull, not a pass/fail regression test.
//
// What it does:
//   1. Generates 4 distinct pairs of real 12-player AI rosters
//      (`generateAiRoster`), each pair playing 5 games against each other
//      (20 games total) -- holding each pair fixed across its 5 games
//      isolates fatigue's own game-to-game variance from roster
//      variance, while still covering several different roster shapes.
//   2. Every game runs through the real, shipped `simulateMatch` --
//      energy tracking (`fatigue.dart`) is now wired into the engine for
//      real, not reimplemented here.
//   3. Reports `MatchResult.finalEnergy` (today diagnostic-only, not yet
//      applied to any rating) bucketed two ways:
//      - by target-minutes rotation tier (`substitution_policy.dart`'s
//        reference table: 1-3/4-5/6-7/8-9/10/11-12), to see whether
//        heavy-minute starters and rarely-used bench players end up with
//        the fatigue spread you'd expect.
//      - by the player's own Stamina rating, independent of rotation
//        tier, restricted to players who actually saw real minutes -- to
//        confirm Stamina itself (not just "how many minutes you play")
//        is driving the outcome.
//   4. Converts final energy into the implied `fatigueBonusFor` rating
//      penalty it *would* apply once wired into live contests (still not
//      wired in -- see `match_engine.dart`'s own doc comment).
//
// Output: a human-readable report to stdout, plus the raw JSON below it
// for anyone who wants to chart it.
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/match/domain/match_result.dart';
import 'package:womensbballmgr/features/match/engine/fatigue.dart';
import 'package:womensbballmgr/features/match/engine/match_engine.dart';
import 'package:womensbballmgr/features/match/engine/substitution_policy.dart';
import 'package:womensbballmgr/features/player/domain/player.dart';
import 'package:womensbballmgr/features/roster/generation/ai_roster_generator.dart';

const _rosterPairCount = 4;
const _gamesPerPair = 5;

/// Matches `substitution_policy.dart`'s reference table's row boundaries,
/// 0-indexed off a target-minutes-descending sort.
String _tierFor(int rankIndex) {
  if (rankIndex <= 2) return '1-3 (30 min target)';
  if (rankIndex <= 4) return '4-5 (26 min target)';
  if (rankIndex <= 6) return '6-7 (14 min target)';
  if (rankIndex <= 8) return '8-9 (8 min target)';
  if (rankIndex == 9) return '10 (6 min target)';
  return '11-12 (4 min target)';
}

String _staminaBucket(int stamina) {
  if (stamina <= 60) return 'poor (<=60)';
  if (stamina <= 80) return 'average (61-80)';
  return 'great (81+)';
}

class _Sample {
  _Sample({
    required this.tier,
    required this.stamina,
    required this.minutesPlayed,
    required this.finalEnergy,
  });

  final String tier;
  final int stamina;
  final double minutesPlayed;
  final double finalEnergy;

  double get impliedPenalty => -fatigueBonusFor(finalEnergy);
}

Map<String, dynamic> _summarize(Iterable<double> values) {
  final list = values.toList();
  if (list.isEmpty) {
    return {'count': 0, 'mean': null, 'min': null, 'max': null};
  }
  return {
    'count': list.length,
    'mean': double.parse(
      (list.reduce((a, b) => a + b) / list.length).toStringAsFixed(2),
    ),
    'min': double.parse(list.reduce(min).toStringAsFixed(2)),
    'max': double.parse(list.reduce(max).toStringAsFixed(2)),
  };
}

void _run() {
  final random = Random(20260817);
  final samples = <_Sample>[];
  var otGames = 0;
  final combinedScores = <int>[];

  for (var pair = 0; pair < _rosterPairCount; pair++) {
    final homeRoster = generateAiRoster(random).map((m) => m.player).toList();
    final awayRoster = generateAiRoster(random).map((m) => m.player).toList();
    final homeTargets = targetMinutesFor(homeRoster);
    final awayTargets = targetMinutesFor(awayRoster);

    final homeByRank = [...homeRoster]
      ..sort((a, b) => homeTargets[b]!.compareTo(homeTargets[a]!));
    final awayByRank = [...awayRoster]
      ..sort((a, b) => awayTargets[b]!.compareTo(awayTargets[a]!));
    final tierByPlayer = <Player, String>{
      for (var i = 0; i < homeByRank.length; i++) homeByRank[i]: _tierFor(i),
      for (var i = 0; i < awayByRank.length; i++) awayByRank[i]: _tierFor(i),
    };

    for (var g = 0; g < _gamesPerPair; g++) {
      final MatchResult result = simulateMatch(
        random,
        homeRoster: homeRoster,
        awayRoster: awayRoster,
      );
      if (result.homeScoreByQuarter.length > 4) otGames++;
      combinedScores.add(result.homeScore + result.awayScore);

      for (final p in [...homeRoster, ...awayRoster]) {
        samples.add(
          _Sample(
            tier: tierByPlayer[p]!,
            stamina: p.ratings.stamina,
            minutesPlayed: result.minutesPlayed[p] ?? 0.0,
            finalEnergy: result.finalEnergy[p] ?? kMaxEnergy,
          ),
        );
      }
    }
  }

  final totalGames = _rosterPairCount * _gamesPerPair;

  // --- By rotation tier ---
  final tierOrder = [
    '1-3 (30 min target)',
    '4-5 (26 min target)',
    '6-7 (14 min target)',
    '8-9 (8 min target)',
    '10 (6 min target)',
    '11-12 (4 min target)',
  ];
  final byTier = <String, dynamic>{};
  for (final tier in tierOrder) {
    final inTier = samples.where((s) => s.tier == tier);
    final belowThreshold = inTier.where(
      (s) => s.finalEnergy < kFatigueThreshold,
    );
    final severe = inTier.where((s) => s.finalEnergy < 50);
    byTier[tier] = {
      'minutesPlayed': _summarize(inTier.map((s) => s.minutesPlayed)),
      'finalEnergy': _summarize(inTier.map((s) => s.finalEnergy)),
      'impliedPenaltyPct': _summarize(
        inTier.map((s) => s.impliedPenalty * 100),
      ),
      'pctPlayerGamesFatigued': double.parse(
        (100 * belowThreshold.length / inTier.length).toStringAsFixed(1),
      ),
      'pctPlayerGamesSeverelyFatigued': double.parse(
        (100 * severe.length / inTier.length).toStringAsFixed(1),
      ),
    };
  }

  // --- By stamina bucket, restricted to real minutes (>=10) so bench
  // noise doesn't wash out the signal ---
  final staminaOrder = ['poor (<=60)', 'average (61-80)', 'great (81+)'];
  final byStamina = <String, dynamic>{};
  final activeSamples = samples.where((s) => s.minutesPlayed >= 10).toList();
  for (final bucket in staminaOrder) {
    final inBucket = activeSamples.where(
      (s) => _staminaBucket(s.stamina) == bucket,
    );
    byStamina[bucket] = {
      'minutesPlayed': _summarize(inBucket.map((s) => s.minutesPlayed)),
      'finalEnergy': _summarize(inBucket.map((s) => s.finalEnergy)),
    };
  }

  final output = {
    'totalGames': totalGames,
    'otGames': otGames,
    'totalPlayerGameSamples': samples.length,
    'byRotationTier': byTier,
    'byStaminaBucketMinPlayed10': byStamina,
  };

  final avgCombinedScore =
      combinedScores.reduce((a, b) => a + b) / combinedScores.length;
  print('');
  print('=== Fatigue diagnostic: $totalGames games ($otGames went to OT) ===');
  print('');
  print(
    '-- Scoring calibration check (fatigue now live in every contest) --',
  );
  print(
    '  avg combined score: ${avgCombinedScore.toStringAsFixed(1)} '
    '(match_engine.dart doc comment cites ~201 as the prior calibration '
    'target, pre-fatigue)',
  );
  print('');
  print('-- By rotation tier (final energy / implied penalty) --');
  for (final tier in tierOrder) {
    final t = byTier[tier] as Map<String, dynamic>;
    final energy = t['finalEnergy'] as Map<String, dynamic>;
    final penalty = t['impliedPenaltyPct'] as Map<String, dynamic>;
    final minutes = t['minutesPlayed'] as Map<String, dynamic>;
    print(
      '  $tier: avg ${minutes['mean']} min played -> '
      'avg energy ${energy['mean']} (range ${energy['min']}-${energy['max']}), '
      'avg implied penalty ${penalty['mean']}% '
      '(${t['pctPlayerGamesFatigued']}% of player-games below the '
      '${kFatigueThreshold.toInt()} threshold, '
      '${t['pctPlayerGamesSeverelyFatigued']}% below 50)',
    );
  }
  print('');
  print('-- By Stamina rating, players with >=10 minutes played --');
  for (final bucket in staminaOrder) {
    final b = byStamina[bucket] as Map<String, dynamic>;
    final energy = b['finalEnergy'] as Map<String, dynamic>;
    final minutes = b['minutesPlayed'] as Map<String, dynamic>;
    print(
      '  Stamina $bucket: n=${energy['count']}, '
      'avg ${minutes['mean']} min played -> avg energy ${energy['mean']}',
    );
  }
  print('');
  print('---FATIGUE-JSON-START---');
  print(const JsonEncoder.withIndent('  ').convert(output));
  print('---FATIGUE-JSON-END---');
}

void main() {
  test('generate fatigue diagnostic data', _run);
}
