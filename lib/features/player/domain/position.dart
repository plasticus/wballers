enum Position { pointGuard, shootingGuard, smallForward, powerForward, center }

extension PositionLabel on Position {
  /// Display label, e.g. "Power Forward" -- `.name` alone gives the
  /// lowercase-camelCase enum identifier, which isn't fit for UI display.
  String get label => switch (this) {
    Position.pointGuard => 'Point Guard',
    Position.shootingGuard => 'Shooting Guard',
    Position.smallForward => 'Small Forward',
    Position.powerForward => 'Power Forward',
    Position.center => 'Center',
  };

  /// The standard 1-2 letter abbreviation ("PG", "C") used anywhere a full
  /// [label] would be too wide -- roster rows, box scores, compact cards.
  /// Previously duplicated privately in several presentation files;
  /// promoted to a shared extension so they stay in sync by construction.
  String get abbreviation => switch (this) {
    Position.pointGuard => 'PG',
    Position.shootingGuard => 'SG',
    Position.smallForward => 'SF',
    Position.powerForward => 'PF',
    Position.center => 'C',
  };
}
