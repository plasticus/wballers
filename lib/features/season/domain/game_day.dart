/// Which day of the week a game falls on -- `0B_Planned.md`'s declared
/// game days: Sunday and Thursday for the regular season and Continental
/// Cup, with Tuesday added during the postseason to support a
/// 3-games/week pace. Enum declaration order is chronological order
/// within a calendar week (Sun, Tue, Thu) -- `.index` doubles as a sort
/// key.
enum GameDay { sunday, tuesday, thursday }

extension GameDayLabel on GameDay {
  /// Display label, e.g. "Sunday" -- `.name` alone gives the lowercase
  /// enum identifier, which isn't fit for UI display.
  String get label {
    return switch (this) {
      GameDay.sunday => 'Sunday',
      GameDay.tuesday => 'Tuesday',
      GameDay.thursday => 'Thursday',
    };
  }

  /// 3-letter abbreviated label, e.g. "Sun" -- for tight layouts (the
  /// Full League schedule's date column) where [label]'s full weekday
  /// name wraps to two lines (a direct GM report, 2026-08-15).
  String get shortLabel {
    return switch (this) {
      GameDay.sunday => 'Sun',
      GameDay.tuesday => 'Tue',
      GameDay.thursday => 'Thu',
    };
  }

  /// Real-calendar day offset from a week's own Sunday -- Sunday=0,
  /// Tuesday=2, Thursday=4 -- distinct from [Enum.index] (0/1/2), which is
  /// just declaration order. What [formatFictionalDate] adds to a week's
  /// anchor date to land on the right day.
  int get _calendarOffset => switch (this) {
    GameDay.sunday => 0,
    GameDay.tuesday => 2,
    GameDay.thursday => 4,
  };
}

/// Week 1's Sunday, anchoring the whole fictional season calendar --
/// `0B_Planned.md`'s 24-week table calls week 1 "(~May 1)"; this picks one
/// concrete date in that neighborhood to actually compute from. Not tied
/// to any particular real year -- the year itself is never displayed (see
/// [formatFictionalDate]), so which real year it lands in is arbitrary.
final _kSeasonWeek1Sunday = DateTime.utc(2026, 5, 3);

const _kMonthAbbreviations = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// A flavor-text calendar date for a given (week, day) on the fictional
/// season schedule, e.g. "May 3" -- no year (this league's calendar isn't
/// tied to a real one). Purely for display; nothing else in the app reads
/// or stores this, so it's fine that it's derived fresh every call rather
/// than persisted anywhere.
String formatFictionalDate(int week, GameDay day) {
  final date = _kSeasonWeek1Sunday.add(
    Duration(days: (week - 1) * 7 + day._calendarOffset),
  );
  return '${_kMonthAbbreviations[date.month - 1]} ${date.day}';
}
