import '../../player/domain/player_injury.dart';
import '../../season/domain/game_day.dart';
import '../domain/injury_report_entry.dart';

Map<String, dynamic> injuryReportEntryToJson(InjuryReportEntry entry) {
  return {
    'playerId': entry.playerId,
    'name': entry.name,
    'teamAbbreviation': entry.teamAbbreviation,
    'severity': entry.severity.name,
    'week': entry.week,
    'day': entry.day.name,
    'season': entry.season,
  };
}

InjuryReportEntry injuryReportEntryFromJson(Map<String, dynamic> json) {
  return InjuryReportEntry(
    playerId: json['playerId'] as String,
    name: json['name'] as String,
    teamAbbreviation: json['teamAbbreviation'] as String,
    severity: InjurySeverity.values.byName(json['severity'] as String),
    week: json['week'] as int,
    day: GameDay.values.byName(json['day'] as String),
    season: json['season'] as int,
  );
}
