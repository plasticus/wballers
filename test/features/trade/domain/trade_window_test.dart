import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/draft/domain/draft_in_progress.dart';
import 'package:womensbballmgr/features/franchise/domain/franchise.dart';
import 'package:womensbballmgr/features/season/domain/season_progress.dart';
import 'package:womensbballmgr/features/trade/domain/trade_window.dart';

import '../../../support/franchise_test_helpers.dart';
import '../../../support/portrait_test_helpers.dart';

/// [franchise] with its next game day set to [gameDayIndex] -- same
/// "vary nextGameDayIndex directly against a real generated schedule"
/// pattern `trade_offer_generator_test.dart` already established.
Franchise _atGameDay(Franchise franchise, int gameDayIndex) {
  final progress = franchise.seasonProgress;
  return franchise.copyWithSeasonProgress(
    SeasonProgress(
      schedule: progress.schedule,
      playedGames: progress.playedGames,
      nextGameDayIndex: gameDayIndex,
    ),
  );
}

void main() {
  test('kTradeDeadlineWeek is locked to 6, per a direct GM call '
      '(2026-08-19)', () {
    expect(kTradeDeadlineWeek, 6);
  });

  test('stays open through every game day in the deadline week, and closes '
      'the instant the next game day is in the following week', () {
    final franchise = withFullActiveRoster(franchiseForPortraitTests());
    final gameDays = gameDaysInOrder(franchise.seasonProgress.schedule);

    // The last game day still in (or before) the deadline week --
    // window must still be open here.
    final lastIndexWithinDeadline = gameDays.lastIndexWhere(
      (entry) => entry.$1 <= kTradeDeadlineWeek,
    );
    expect(lastIndexWithinDeadline, greaterThanOrEqualTo(0));
    expect(
      isTradeWindowOpen(_atGameDay(franchise, lastIndexWithinDeadline)),
      isTrue,
    );

    // The first game day in the week right after -- window must
    // already be closed here, and stays closed for every later index
    // too.
    final firstIndexAfterDeadline = gameDays.indexWhere(
      (entry) => entry.$1 > kTradeDeadlineWeek,
    );
    expect(firstIndexAfterDeadline, greaterThan(lastIndexWithinDeadline));
    expect(
      isTradeWindowOpen(_atGameDay(franchise, firstIndexAfterDeadline)),
      isFalse,
    );
    expect(
      isTradeWindowOpen(_atGameDay(franchise, gameDays.length - 1)),
      isFalse,
    );
  });

  test('open at the very start of a fresh season (preseason)', () {
    final franchise = withFullActiveRoster(franchiseForPortraitTests());
    expect(isTradeWindowOpen(_atGameDay(franchise, 0)), isTrue);
  });

  test('closed once a draft is in progress, regardless of game day', () {
    final franchise = withFullActiveRoster(
      franchiseForPortraitTests(),
    ).copyWithDraftInProgress(const DraftInProgress(order: ['AAA'], rounds: 1));
    expect(isTradeWindowOpen(_atGameDay(franchise, 0)), isFalse);
  });

  test('closed once the whole season has been played out', () {
    final franchise = withFullActiveRoster(franchiseForPortraitTests());
    final gameDays = gameDaysInOrder(franchise.seasonProgress.schedule);
    expect(isTradeWindowOpen(_atGameDay(franchise, gameDays.length)), isFalse);
  });
}
