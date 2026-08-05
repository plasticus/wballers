import '../../player/domain/player.dart';

/// Positions for a 12-player active roster. Guarantees at least two
/// players at every position so a legal starting five and bench can
/// always be fielded; guards and forwards get a third body since those
/// rotations run deepest in practice. Shared by every 12-player roster
/// generator (the GM's own starting roster, AI team rosters) so they stay
/// in sync.
const kTwelvePlayerPositionPlan = <Position>[
  Position.pointGuard,
  Position.pointGuard,
  Position.shootingGuard,
  Position.shootingGuard,
  Position.shootingGuard,
  Position.smallForward,
  Position.smallForward,
  Position.smallForward,
  Position.powerForward,
  Position.powerForward,
  Position.center,
  Position.center,
];
