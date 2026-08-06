import '../domain/team.dart';

Map<String, dynamic> teamColorsToJson(TeamColors colors) {
  return {
    'primaryHex': colors.primaryHex,
    'secondaryHex': colors.secondaryHex,
    'accentHex': colors.accentHex,
  };
}

TeamColors teamColorsFromJson(Map<String, dynamic> json) {
  return TeamColors(
    primaryHex: json['primaryHex'] as String,
    secondaryHex: json['secondaryHex'] as String,
    accentHex: json['accentHex'] as String,
  );
}

Map<String, dynamic> teamToJson(Team team) {
  return {
    'abbreviation': team.abbreviation,
    'location': team.location,
    'name': team.name,
    'conference': team.conference.name,
    'colors': teamColorsToJson(team.colors),
    'identityNote': team.identityNote,
    'emoji': team.emoji,
  };
}

Team teamFromJson(Map<String, dynamic> json) {
  return Team(
    abbreviation: json['abbreviation'] as String,
    location: json['location'] as String,
    name: json['name'] as String,
    conference: Conference.values.byName(json['conference'] as String),
    colors: teamColorsFromJson(json['colors'] as Map<String, dynamic>),
    identityNote: json['identityNote'] as String,
    emoji: json['emoji'] as String,
  );
}
