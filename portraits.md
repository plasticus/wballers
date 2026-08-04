# Women's Basketball Manager — Portrait System

## Purpose

Portraits are a core customization feature, not decoration. Every fictional athlete and coach has a layered pixel-art portrait that can be generated from weighted choices, edited by the player, rendered consistently in Flutter, and cached locally as a PNG.

The existing artwork is the source set for the first release. It is all 32×32 transparent PNG pixel art, created for compositing without smoothing.

## Provenance and license

Every portrait sprite (base sprite, hair, eyes, eyebrows, nose, mouth, accessories, shoulders, hats, glasses) is original artwork hand-drawn by the developer in LibreSprite. No third-party or stock art is used, so there are no external licensing obligations to track.

## Asset audit

| Asset group | Count | Used by | Notes |
| --- | ---: | --- | --- |
| Base sprite | 1 | Player and coach | `BlankBaldwoman32.png`; the available base is feminine and must be the Flutter default. |
| Hair | 41 | Player and coach | Recolored from magenta placeholders. |
| Eyes | 11 | Player and coach | Drawn unchanged. |
| Eyebrows | 10 | Player and coach | Recolored from magenta placeholders. |
| Nose | 7 | Player and coach | Shadow recolored to match skin tone. |
| Mouth | 9 | Player and coach | Drawn unchanged. |
| Accessories | 33 | Player and coach | Earrings, goggles, and headbands. |
| Shoulders | 4 | Coach only | Coach clothing/shoulder overlays. |
| Hats | 4 | Coach only | Coach-only overlays. |
| Glasses | 7 | Coach only | Coach-only overlays. |
| Facial hair | 14 | Coach only | Existing legacy assets; keep unavailable to women athletes. |

**Total:** 141 PNG assets, all 32×32 pixels.

## Existing source files

- `manifest.json` lists the available asset filenames by category.
- `weights.json` defines weighted random generation for skin tone, hair color, hair style, facial features, accessories, and rare novelty hair colors.
- `render.js` is the browser reference implementation for layer order and per-pixel recoloring.
- `BlankBaldwoman32.png` is the actual base sprite in this repository.

### Migration note

`render.js` currently falls back to `BlankBaldman32.png`, which is not present in this project. Flutter must use `BlankBaldwoman32.png` as the explicit default base asset. Do not carry over that fallback filename.

## Appearance model

Store compact appearance data in the save file. The cached PNG is derived data and can always be re-rendered after a portrait-system update.

```text
PortraitAppearance
  version
  baseSprite
  skinTone
  hair
  hairColor
  topHairColor       // optional; supports special/earned colors
  eyes
  eyebrows           // optional
  nose
  mouth
  accessories        // optional
  isCoach
  shoulders           // coach only, optional
  hat                 // coach only, optional
  glasses             // coach only, optional
  facial              // coach only, optional
```

Player-facing portrait editing should expose the relevant athlete fields: skin tone, hair style, hair color, special hair color when unlocked, eyes, eyebrows, nose, mouth, and accessories. Coach editing additionally exposes shoulders, hats, glasses, and the legacy facial-hair set.

## Rendering order

The order below is the behavioral reference from `render.js`. Order matters: long or fringe hairstyles should sit above eyebrows, for example.

### Athlete

1. Recolored base sprite (skin tone and team jersey collar)
2. Hair
3. Eyes
4. Eyebrows
5. Nose
6. Mouth
7. Accessories

### Coach

1. Recolored base sprite (skin tone; do not jersey-recolor)
2. Shoulder overlay, when selected
3. Hair
4. Hat, when selected
5. Eyes
6. Eyebrows
7. Glasses, when selected
8. Nose
9. Mouth
10. Facial hair, when selected
11. Accessories

## Color behavior

### Skin tones

The current generation set contains five tones: `pale`, `light`, `medium`, `deep`, and `chocolate`. The base sprite’s exact base-skin and shadow colors are replaced with the selected tone and a proportional shadow tone. Nose-shadow pixels use the same proportional shadow calculation.

### Natural hair colors

`black`, `darkbrown`, `brown`, `lightbrown`, `blonde`, `auburn`, `red`, `gray`, and `white` are supported color keys. Hair, eyebrows, and coach facial hair use their natural hair color.

### Special hair colors

`limegreen`, `neonpink`, `skyblue`, and `fuchsia` already exist in the reference generator as rare novelty colors. In Women's Basketball Manager, treat these as unlockable cosmetics—primarily through awards and achievements—not ordinary random generation. Apply a special color only to the top-hair layer (`topHairColor`), leaving eyebrows and facial hair natural.

### Pixel replacement rule

Hair-like assets use a magenta placeholder. In the reference renderer, any non-transparent pixel with equal red and blue channels, green at most 5, and red above 0 is recolored. Its brightness is retained by multiplying the target color by `red / 255`.

The base sprite replaces only exact source colors for base skin, skin shadow, and the navy shirt collar. This exact-match approach protects linework and pixel-art shading.

## Random generation

Use `weights.json` as the initial source of weighted choices. Generate a portrait from a deterministic seeded random source so a player remains visually stable across saves and simulation reruns.

- Choose skin tone first.
- Choose a natural hair color using the skin-tone-specific distribution.
- Choose hair, eyes, nose, mouth, eyebrows, and accessories using their configured weights.
- Generate no athlete facial hair.
- Default athlete accessories to none most of the time, as currently weighted.
- Select special hair colors only from unlocked cosmetic rules; do not let them change the athlete’s identity when a save is restored.

The current weights favor longer and traditionally feminine hairstyles. Review and expand them over time, but retain weight data separately from code so balancing and new art do not require renderer changes.

## Flutter implementation

1. Copy the approved artwork into a Flutter asset directory, preserving category folders and filenames.
2. Convert `manifest.json`, `weights.json`, and the color tables into typed Dart data or generated asset metadata.
3. Load source PNGs as `ui.Image` values and cache them by asset path.
4. Recolor the base, nose, and magenta-placeholder assets at the pixel level using `dart:ui` image data or a canvas-backed image pipeline.
5. Composite the layers onto a 32×32 `Canvas` in the specified order with pixel smoothing disabled (`FilterQuality.none`).
6. Render at integer multiples only—such as 64, 96, or 128 pixels—to preserve sharp pixel art.
7. Export the completed composition with `Image.toByteData(format: ImageByteFormat.png)` and cache it under a versioned local portrait path.
8. Invalidate/rebuild the cached PNG whenever appearance data, jersey color, base art, or portrait renderer version changes.

The app UI should display the cached PNG for roster lists and use the live renderer in the portrait editor. This keeps scrolling fast while preserving instant preview during edits.

## Local storage rules

- Save `PortraitAppearance` alongside the player or coach record.
- Save a `portraitRendererVersion` and cache key with each generated PNG.
- Cache path should be scoped to the local save and portrait owner, for example `saves/<save-id>/portraits/<player-id>-v<version>.png`.
- Regenerate missing or stale images automatically. A missing cache must never make a player unusable.
- Do not make portrait rendering or caching depend on a network connection.

## Acceptance checks

- Every asset listed in the generated Flutter manifest loads successfully.
- A seeded appearance renders identically across app restarts.
- Layer-order tests prove that hair overlays eyebrows and coach hats/glasses render in their correct positions.
- Color tests cover every skin tone, every natural hair color, each special hair color, jersey recoloring, and the unmodified coach shirt.
- Athlete portraits never show coach-only overlays or facial hair.
- Edited portraits immediately update and remain correct after save/reload.
- Cached PNGs retain crisp pixel edges at supported display sizes.

## Implementation status (question.md decision 28)

Built: the domain models, seeded generation, the full `dart:ui` recoloring/compositing pipeline (pixel-for-pixel port of `render.js`), file-based PNG caching keyed on appearance version and jersey color, display via `PortraitImage` (with the accessible fallback portrait) on `TeamRosterScreen`, and a portrait editor (`PortraitEditorScreen`, question.md decision 29) covering every field the doc calls for -- skin tone, hair style/color, eyes, eyebrows, nose, mouth, accessories for athletes, plus shoulders/hats/glasses/facial hair for the coach.

Two departures from a literal reading of `weights.json`, both because this doc's own text overrides the source prototype's behavior: neon/special hair colors are never rolled at generation time, and the editor doesn't expose them either (both are unlock-only, gated behind an achievement system that doesn't exist yet); coach-only shoulders/hats/glasses are never auto-generated (`weights.json` has no weight tables for them at all -- pure customization, which is exactly what the editor is for).

Still open: unlock-gated special hair colors in the editor (needs the achievement system first), and the achievement/nickname system itself.

## Future art work

- Add more player hairstyles, accessories, face features, and diverse base sprites only after they follow the same 32×32 alignment and palette conventions.
- Add player-specific unlock cosmetics through achievement rules, rather than changing the core portrait schema.
- Consider team apparel overlays later if the base-sprite shirt collar is not enough for roster presentation.
