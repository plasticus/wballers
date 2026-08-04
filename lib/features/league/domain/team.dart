import 'dart:ui' show Color;

enum Conference { atlantic, pacific }

/// A team's brand colors, stored as the canonical `#RRGGBB` hex strings from
/// `teams.md` so this data stays trivially diffable against its source, with
/// [Color] getters for the UI layer to consume directly.
class TeamColors {
  const TeamColors({
    required this.primaryHex,
    required this.secondaryHex,
    required this.accentHex,
  });

  final String primaryHex;
  final String secondaryHex;
  final String accentHex;

  Color get primary => _parseHex(primaryHex);
  Color get secondary => _parseHex(secondaryHex);
  Color get accent => _parseHex(accentHex);

  static Color _parseHex(String hex) {
    return Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));
  }
}

/// A fictional franchise in the 20-team Atlantic/Pacific league. See
/// `teams.md` for the editable design source this is transcribed from.
class Team {
  const Team({
    required this.abbreviation,
    required this.location,
    required this.name,
    required this.conference,
    required this.colors,
    required this.identityNote,
  });

  /// Always exactly three uppercase letters, e.g. `BOS`.
  final String abbreviation;

  /// Real-world city/region, e.g. `Boston, MA`. Flavor only — not part of
  /// the team's brand name.
  final String location;

  /// The full branded team name, e.g. `Boston Beacon`.
  final String name;

  final Conference conference;
  final TeamColors colors;
  final String identityNote;

  @override
  String toString() => '$abbreviation ($name)';
}
