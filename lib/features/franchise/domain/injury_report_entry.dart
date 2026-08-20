import '../../player/domain/player_injury.dart';
import '../../season/domain/game_day.dart';

/// One player's freshly-suffered injury, captured with real name/team/
/// severity details for the Mail tab's "Injury Report" (2026-08-20,
/// following the injuries design pass). `Franchise.injuryReports` is
/// where a season's own batch lives, reset at every `copyWithNewSeason`
/// the same way `Franchise.leagueRetirements` already is --
/// `InjuryReportMailItem` groups by [week]/[day] into one mail item per
/// game day that actually produced a new injury.
///
/// Unlike `LeagueRetirement`, this one covers *every* team -- the GM's
/// own roster included. There's no separate proactive "your player got
/// hurt" mail the way retirements get `RetirementDecisionMailItem`; this
/// digest is the only place that news shows up at all.
class InjuryReportEntry {
  const InjuryReportEntry({
    required this.playerId,
    required this.name,
    required this.teamAbbreviation,
    required this.severity,
    required this.week,
    required this.day,
    required this.season,
  });

  final String playerId;
  final String name;
  final String teamAbbreviation;
  final InjurySeverity severity;

  /// Which game day this injury happened on -- `game_day.dart`'s
  /// `formatFictionalDate(week, day)` turns this into a real date, and
  /// [InjuryReportMailItem] groups entries sharing a (week, day) pair
  /// into one mail item.
  final int week;
  final GameDay day;

  /// Which [Franchise.season] this happened during -- same zero-based
  /// convention every other season-tagged record uses.
  final int season;
}
