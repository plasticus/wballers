import '../../franchise/domain/franchise.dart';
import '../../season/domain/season_progress.dart';

/// The last schedule week trades are allowed in -- "definitively mark
/// the Trade Deadline as End of Week 6," a direct GM call (2026-08-19),
/// replacing the earlier "~15 turns, never locked to a real week" fudge.
/// The window stays open through every game day in week
/// [kTradeDeadlineWeek]; the instant the GM starts a Week
/// `kTradeDeadlineWeek + 1` game, it's shut for the rest of the season --
/// `TeamCalendarScreen`/the Dashboard's Season card both show it as a
/// real milestone sitting between those two weeks.
const kTradeDeadlineWeek = 6;

/// Whether [franchise] is currently inside its trade window -- the draft
/// must already be finalized ([Franchise.draftInProgress] `null`, "opens
/// after the draft") and the next game day still on the clock has to
/// fall in [kTradeDeadlineWeek] or earlier. Checked against whichever
/// game day is *next up* (`gameDaysInOrder`, same pointer
/// `SeasonProgress.nextGameDayIndex` already tracks) rather than a flat
/// game-day count -- weeks don't all carry the same number of game days
/// (byes, Cup rounds, All-Star week), so only a real week comparison
/// lands exactly on "closed the moment Week 7 starts," calendar-based
/// rather than turn-count-based. A bye week still counts toward closing
/// the window even if the GM's own club sits it out -- the deadline is
/// leaguewide, not tied to the GM's own next game.
bool isTradeWindowOpen(Franchise franchise) {
  if (franchise.draftInProgress != null) return false;
  final progress = franchise.seasonProgress;
  final gameDays = gameDaysInOrder(progress.schedule);
  if (progress.nextGameDayIndex >= gameDays.length) return false;
  final (nextWeek, _) = gameDays[progress.nextGameDayIndex];
  return nextWeek <= kTradeDeadlineWeek;
}
