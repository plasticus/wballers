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
}
