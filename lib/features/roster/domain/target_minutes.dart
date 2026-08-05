/// Reference target-minutes-by-rank table (see `0B_Planned.md`'s Phase 3
/// automatic-substitution design): the top 12 active-roster ranks sum to a
/// full 200-minute game. Ranks past 12 (developmental) always get zero --
/// nothing in Phase 1/1.5 spends these minutes yet, this table only powers
/// the bench-order screen's informational notes for now.
const kTargetMinutesByRank = <int>[
  30, 30, 30, // ranks 1-3
  26, 26, // ranks 4-5
  14, 14, // ranks 6-7
  8, 8, // ranks 8-9
  6, // rank 10
  4, 4, // ranks 11-12
];

/// Target minutes for the player at [rank] (1-indexed). Ranks beyond the
/// 12-player active roster always resolve to zero.
int targetMinutesForRank(int rank) {
  if (rank < 1 || rank > kTargetMinutesByRank.length) return 0;
  return kTargetMinutesByRank[rank - 1];
}
