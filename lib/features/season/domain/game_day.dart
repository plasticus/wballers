/// Which day of the week a game falls on -- `0B_Planned.md`'s declared
/// game days: Sunday and Thursday for the regular season and Continental
/// Cup, with Tuesday added during the postseason to support a
/// 3-games/week pace. Enum declaration order is chronological order
/// within a calendar week (Sun, Tue, Thu) -- `.index` doubles as a sort
/// key.
enum GameDay { sunday, tuesday, thursday }
