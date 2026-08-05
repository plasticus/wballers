# Women's League Portraits (wballers)

This is a separate portrait system for the women's league. It shares the rendering engine (`../render.js`) with the men's league but uses its own base sprite and part folders.

## Getting Started

1. Replace `base/BlankBaldwoman32H0.png` with a female base sprite (`H1.png`/`H2.png` are taller variants for the portrait height-shift feature).
2. Draw parts in the folders below.
3. Run `python3 ../generate_manifest.py .` from this folder to regenerate `manifest.json`.
4. Add players to `players.json` (or generate them from a spreadsheet later).
5. Run `python3 player_edit_server.py` and open `http://localhost:8001/`.
6. Open `http://localhost:8001/compare_bases.html` to compare the feminine base-sprite variations.

## Feminine Face Tips

Compared to the men's base:

- **Jaw / chin:** Rounder and softer. Avoid the square/blocky chin. Taper the jawline inward toward the chin.
- **Face shape:** Slightly rounder overall; cheekbones can be a little higher.
- **Eyes:** Larger relative to the face, more open. A little eyelash or upper-lid line helps.
- **Eyebrows:** Thinner, more arched, less heavy than the men's brows.
- **Nose:** Smaller, narrower bridge, softer tip.
- **Mouth:** Fuller lips, slightly larger. Often sits a touch higher on the face.
- **Forehead / hairline:** Can be a little shorter / rounder at the hairline.
- **Facial hair:** Leave the `facial/` folder empty — not used.
- **Shoulders / hats / glasses:** Same idea as the men's league, but sized/shaped for the female base.

## Folder Structure

- `hair/` — hairstyles
- `eyes/` — eye sprites
- `eyebrows/` — eyebrow sprites
- `nose/` — nose sprites
- `mouth/` — mouth sprites
- `accessories/` — earrings, headbands, goggles
- `shoulders/` — coach shoulder lines
- `hats/` — coach hats
- `glasses/` — coach glasses
- `facial/` — intentionally empty for the women's league

## Color Placeholders

Use the same magenta placeholder system as the men's league:
- Paint hair/eyebrows in shades of magenta (`#ff00ff`, `#aa00aa`).
- `render.js` will recolor them based on `hairColor` / `topHairColor`.
