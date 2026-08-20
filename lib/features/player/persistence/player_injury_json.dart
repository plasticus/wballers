import '../domain/player_injury.dart';

Map<String, dynamic> playerInjuryToJson(PlayerInjury injury) {
  return {
    'severity': injury.severity.name,
    'gamesRemainingAtSeverity': injury.gamesRemainingAtSeverity,
  };
}

PlayerInjury playerInjuryFromJson(Map<String, dynamic> json) {
  return PlayerInjury(
    severity: InjurySeverity.values.byName(json['severity'] as String),
    gamesRemainingAtSeverity: json['gamesRemainingAtSeverity'] as int,
  );
}
