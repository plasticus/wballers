# Women's Basketball Manager — Player Archetypes

Position-specific play-style labels. Distinct from traits (`traits.md`,
question.md decision 21) — archetypes describe *how a player plays*,
traits describe psychology, career, and situational bonuses. Not yet
wired to `PlayerRatings` or any rating thresholds; that mapping is
still future work.

| Position | Unique Archetypes |
| --- | --- |
| PG | Floor General, Scoring Point, Combo Guard, POINT GOD |
| SG | Scoring Specialist, 3&D, Sniper, Defensive Specialist |
| SF | Versatile Forward, 3&D, Sniper, Point Forward, Defensive Specialist |
| PF | Versatile Forward, Point Forward, Rebound King, Defensive Specialist, Low Post Monster, Stretch-4 |
| C | Rim Runner, Low Post Monster, Rebound King, Shot Blocker, Stretch-5 |

**Implemented** (Phase 1.5, question.md decision 27): `Archetype` enum
and `kArchetypesByPosition` live in
`lib/features/player/domain/archetype.dart`, matching this table
exactly (repeated names across positions, e.g. "3&D" for SG/SF, are the
same enum value, valid for multiple positions). `generateArchetype`
(`lib/features/player/generation/archetype_generator.dart`) picks one
option uniformly at random from the player's position — not
rating-correlated. A rating-threshold-based mapping remains open future
work, as noted above.
