# Women's Basketball Manager — Player Archetypes

Position-specific play-style labels. Distinct from traits (`traits.md`,
question.md decision 21) — archetypes describe *how a player plays*,
traits describe psychology, career, and situational bonuses. Wired to
`PlayerRatings`: a player's archetype is rolled first, then ratings
generation biases toward it (see below).

| Position | Unique Archetypes |
| --- | --- |
| PG | Floor General, Scoring Point, Combo Guard |
| SG | Scoring Specialist, 3&D, Sniper, Defensive Specialist |
| SF | Versatile Forward, 3&D, Sniper, Point Forward, Defensive Specialist |
| PF | Versatile Forward, Point Forward, Rebound King, Defensive Specialist, Low Post Monster, Stretch-4 |
| C | Rim Runner, Low Post Monster, Rebound King, Shot Blocker, Stretch-5 |

**Implemented** (Phase 1.5, question.md decision 27): `Archetype` enum
and `kArchetypesByPosition` live in
`lib/features/player/domain/archetype.dart`, matching this table
exactly (repeated names across positions, e.g. "3&D" for SG/SF, are the
same enum value, valid for multiple positions). `generateArchetype`
(`lib/features/player/generation/archetype_generator.dart`) still picks
one option uniformly at random from the player's position -- but
`generatePlayer` (`player_generator.dart`) rolls it first, then biases
rating generation to fit it (`_archetypeBias`), so a Sniper reliably
ends up with high perimeter offense and a Low Post Monster with high
interior offense, rather than the archetype label being purely
cosmetic (Phase 2 work, `0A_Completed.md`).
