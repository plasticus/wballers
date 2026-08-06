# Women's Basketball Manager — Vision & Ideas

Premise-level thinking that isn't phase-scoped build work — either because
it's foundational (Section I), because it's genuinely still undecided
whether it belongs in scope (Section II), or because it's a useful
principle/reference that doesn't fit a phase bucket at all (Section III).
See `0A_Completed.md`/`0B_Planned.md` for the phase-organized build status.

## I. Vision & broad strokes

**What the game is.** An Android-first, single-player women's basketball
franchise manager. The player creates an expansion club, develops a
changing roster across seasons, drafts and trades players, and makes
limited but meaningful coaching choices during games. The league is
entirely fictional. The game works completely offline after install — no
accounts, no cloud sync, no multiplayer, no real-world player/team data.

**Core game shape.** A franchise-management-first hybrid: the player
manages a roster over multiple seasons, while individual games provide
play-by-play and limited coaching decisions rather than full manual play.
Automatic substitutions keep the player focused on strategy, not
micromanaging every minute of every game.

**Match presentation, in build order.** Play-by-play first; then
quarter-break and timeout coaching choices; then a simple court
visualization showing shot locations and related game action. No need for
full animated on-court play — this is meant to stay legible and readable,
not become an animation project.

**New-game experience.** The player creates an expansion franchise, chooses
its name and identity, and inherits a weak roster. Starting rosters —
and, per the newer 40-team-pool idea, the league's own composition — should
vary meaningfully between playthroughs.

**Essential franchise systems.** Player development, drafts, and trades are
priorities for the first fully playable franchise experience. Everything
else follows once that core loop actually works.

**Solo experience.** No player-vs-player or other online competition is
planned, ever. This is a solo game, full stop.

**League foundation.** 20 fictional teams (with the newer plan to expand
the design pool to 40 and randomly draw 20 into play per game), organized
into Atlantic and Pacific conferences. Names should evoke professional
women's basketball without resembling any real team.

**Earned identity.** Players can earn nicknames and special hair colors
through awards and achievements — league MVP, scoring leader, defensive
MVP, and others. The game suggests a nickname; the coach may edit *that
suggestion*. This is deliberately not a free-assignment tool — a GM can't
hand a nickname to an arbitrary player on a whim, it has to be earned
first. (Worth remembering: this got built wrong once already, as a free
text field, and had to be corrected. The instinct to make things more
permissive "since it's not explicitly forbidden" is the wrong default for
anything framed as earned/unlocked in this game.)

**Portraits as a core feature, not decoration.** Deep customization matters
here — the coach can extensively customize player and coach portraits,
including editing individual players after they're generated. This is one
of the more distinctive parts of the game's identity, not a nice-to-have
skin.

**Fictional world, taken seriously.** Every team, athlete, coach, college,
logo, and data point is fictional. Real U.S. and Canadian cities are fine;
mirroring real organizations is not. The rookie pipeline runs through
roughly 100 fictional colleges in believable locations.

**Business model.** Free-to-play with AdMob banner placements on selected
screens (dashboard/home, gameplay). Ads should never appear on every screen
or interrupt play.

**Platforms.** Android launches first. Web is the next platform priority.
iOS is not currently in scope.

**Name.** *Women's Basketball Manager.*

## II. Maybe pile

Things that have come up but are intentionally not committed to yet —
mostly because they're a bit outside the primary scope right now, and it's
better to get the core game closer to done before deciding whether they
belong. Expect items to move here from the Planned doc as priorities
sharpen, and occasionally to move *out* of here into Planned once the game
is far enough along to evaluate them properly.

- **A bigger Team-tab reorg**: a real team hub beyond today's flat roster
  list, a side-by-side player comparison tool, and roster search/filtering.
  Scratched from Planned for now — not important while the roster screen
  itself is still getting small polish passes; revisit once Phase 2's
  league/season systems give the Team tab more to actually show.
- **Team captain designation.** Bundled with bench order in an earlier
  pass; the bench-order screen itself got built (`0A_Completed.md`), but
  naming a captain never got designed and isn't important enough yet to
  hold a Planned slot.
- **Splitting end-of-season ceremony machinery into its own phase**
  (a "Phase 2.5" or "3.5") rather than a bullet inside Phase 2. Flagged as
  a structural possibility, not decided — revisit once the rest of Phase 2
  is further along and the actual scope of the ceremony work is clearer.
- **A "Difficulty" setting.** Moved here from Planned (2026-08-06) —
  genuinely not decided whether the game needs one at all. If it does get
  built, the GM's own leading idea: keep it simple, an easy-mode game-time
  stat boost (e.g. +10%) rather than touching the underlying action-success
  formulas directly.

## III. Etc.

**Cross-cutting principles** (apply at every phase, not just one):

- Version every simulation rule and saved-game migration; never silently
  invalidate a franchise. (Caveat, current and temporary: during this
  pre-release phase, the standing practice for a schema-breaking change is
  actually to delete and recreate the local save rather than write
  backward-compatibility parsing — there's no real save data at stake yet.
  Revisit this once the game has real save data worth preserving across
  schema changes.)
- Prioritize automated tests for domain logic and the simulation engine
  before UI-level tests.
- Keep the game playable without a connection at every stage.
- Maintain a vertical slice at all times: create expansion team → manage
  roster → play/simulate a game → see consequences → save.
- Player generation stays fully procedural. No curated/hand-authored
  starting players — every roster, including AI teams, comes out of the
  same seeded generator.

**Suggested milestones** (player-visible outcomes, roughly phase-aligned):

| Milestone | Player-visible outcome |
| --- | --- |
| Foundation demo | Open an offline Android app and start/resume a local save. |
| Expansion roster slice | Create a club, receive a varied weak roster, edit a lineup, and save it. |
| Season slice | Simulate a short season, view standings, develop players, and reach a draft. |
| Tactical slice | Follow live play-by-play, make quarter/timeout choices, and read a clear box score. |
| Presentation slice | See shot locations on a simple court presentation. |
| Release candidate | Play multiple reliable seasons with balanced results and recoverable saves. |

**First implementation target** (the thin vertical slice the whole project
was originally scoped around): create an expansion franchise → name it →
receive a weak generated roster → browse generated, editable portraits →
set a valid starting five and bench → simulate one exhibition through
play-by-play → read the box score → save and restore. It validates the
local app foundation, roster UX, portrait system, and core game loop before
full-league depth gets added.
