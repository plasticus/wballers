import '../../franchise/domain/franchise.dart';

/// How many game days into a season the trade window stays open --
/// `trading-and-hidden-gems-notes.md`: "opens after the draft, runs
/// through 2 preseason games + up to 12 regular-season turns" -- 14 game
/// days total (indices 0-13), so the window covers game-day index 0
/// through [kTradeWindowLastGameDayIndex] inclusive, 14 distinct turns.
const kTradeWindowGameDayCount = 14;
const kTradeWindowLastGameDayIndex = kTradeWindowGameDayCount - 1;

/// Whether [franchise] is currently inside its trade window -- the draft
/// must already be finalized ([Franchise.draftInProgress] `null`, "opens
/// after the draft") and no more than [kTradeWindowGameDayCount] game
/// days can have been played yet this season. `SeasonProgress.nextGameDayIndex`
/// doubles as "how many game days have been played so far" (it's the
/// index of the *next* one), which is exactly the counter this window
/// needs -- no separate persisted turn counter required.
bool isTradeWindowOpen(Franchise franchise) {
  if (franchise.draftInProgress != null) return false;
  return franchise.seasonProgress.nextGameDayIndex <= kTradeWindowLastGameDayIndex;
}
