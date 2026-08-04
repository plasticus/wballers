# Women's Basketball Manager — Player Traits

Traits replace the earlier hidden-numeric-personality-stat idea (see
`question.md` decision 21): discrete, visible, earnable traits a coach
can scout for, rather than numbers nobody can see or act on. Distinct
from archetypes (`archetypes.md`), which describe playing style —
traits describe psychology, career, and (for the skill-specific set
below) situational bonuses beyond what the raw rating predicts.

Most traits are earned from in-season or in-game situations and need
Phase 2's season simulation and Phase 3's match engine to exist before
they can actually trigger. Some (the Potential pair, and any trait
rolled at generation time) are assignable at player generation/draft
time, which Phase 1 already supports.

## Work ethic / development

- **High Potential** — trains faster, more likely to reach or exceed their ceiling.
- **Low Potential** — trains slower, more likely to plateau below their ceiling.
- **Highly Coachable** — big training gains from a good Development coach; responds well to in-game tactical adjustments too.
- **Stubborn** — resists coaching; smaller training gains and slower to buy into tactical calls, regardless of coach quality.
- **Gym Rat** — keeps improving in the offseason without needing focused coaching attention; ages more gracefully.

## Durability

- **Iron Man** — rarely sits out; unusually reliable game-to-game availability.
- **Injury Prone** — more frequent, longer injuries than physical ratings alone would suggest.

## Leadership / chemistry

- **Leader** — small team-wide morale/chemistry boost just from being on the roster.
- **Malcontent** — team-wide morale penalty, worse during losing stretches. Opposite of Leader.
- **No Ego** — accepts a reduced role without a morale hit; the glue guy who keeps a roster balanced.
- **Super Ego** — morale drops if usage/shots are too low, even on a winning team. Opposite of No Ego.

## Mental / clutch

- **Clutch** — performance bump in late-game, high-leverage situations.
- **Choker** — performance dip in those same situations. Opposite of Clutch.
- **Hot Head** — elevated technical-foul/ejection risk after bad calls or physical play.
- **Prime Time** — raises effort and performance specifically against ranked opponents or in marquee matchups.
- **Icy Veins** — not shaken by pivotal moments; resistant to the pressure that would otherwise cause a dip, including free throws in close games.

## Loyalty / career

- **Loyal** — resists trade demands, takes team-friendly deals, morale holds up through losing seasons.
- **Flight Risk** — pushes for a trade the moment the team slumps or a bigger star arrives. Opposite of Loyal.
- **Ring Chaser** — accepts a reduced role on a contender; unhappy on a rebuilder regardless of personal stats.
- **Homegrown** — extra loyalty and fan-favorite bonus specifically for a player this franchise drafted and developed.

## Crowd

- **Home Court Hero** — fires up the home crowd; team gets a small home-court boost when this player is on a heater.
- **Road Warrior** — thrives specifically in hostile road environments, unfazed by crowd noise.

## Skill-specific ("badges")

Function like NBA 2K's badges, not like archetypes: a narrow, earnable
bonus on one specific check that beats what the raw rating alone
predicts. Archetypes describe a player's overall shape; these are
one-off edges layered on top.

- **Glass Cleaner** — rebounding: wins contested boards beyond what strength/interior ratings alone predict.
- **Pickpocket** — stealing: elevated success on steal/disruption attempts.
- **Rim Guardian** — front-court blocking: elevated block success protecting the rim.
- **Backcourt Barrier** — back-court blocking: elevated block success chasing down shots or contesting from the perimeter/in transition.
- **Sharpshooter** — three-pointers: extra bump on contested or high-volume attempts.
- **Slasher's Touch** — layups: extra bump finishing through contact/traffic.
- **Automatic** — free throws: elevated make rate as a raw skill, distinct from Icy Veins' pressure-resistance framing. Name is a placeholder suggestion, not yet confirmed.

## Shelved / future ideas

- **Media Magnet** — draws outsized press/fan attention — good for team prestige/marketing, but amplifies morale swings after a bad stretch. Shelved because it implies off-court/media systems the game isn't planning to build.
