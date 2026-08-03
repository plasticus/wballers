// Shared face-compositing engine. Used by both index.html (the character
// mixer/weight-tuning tool) and the roster site (team.html), so there is
// exactly one place that knows how to draw a face - the two pages never
// drift apart visually.
//
// Draw order (matters! e.g. long fringe hairstyles need to cover the
// eyebrow beneath them): skin+shirt base -> hair -> eyes -> eyebrows ->
// nose -> mouth -> facial hair -> accessories.

const BASE = (typeof window !== 'undefined' && window.BASE_SPRITE) || 'BlankBaldman32.png';

const HAIR_COLORS = {
  black: '#1b1b1b',
  darkbrown: '#3b2417',
  brown: '#5a3a22',
  lightbrown: '#8a5a34',
  blonde: '#d9b872',
  auburn: '#7a3320',
  red: '#a8432a',
  gray: '#8f8f8f',
  white: '#e8e8e8'
};

// Rare novelty dye-job colors - only ever applied to the top-of-head hair
// layer (see weights.toml's [neon_hair]), never to eyebrows/facial hair.
const NEON_COLORS = {
  limegreen: '#39ff14',
  neonpink: '#ff2fc2',
  skyblue: '#00bfff',
  fuchsia: '#c724b1'
};

// Combined lookup so getRecoloredMagenta can resolve either a natural or a
// neon color key.
const ALL_HAIR_COLORS = { ...HAIR_COLORS, ...NEON_COLORS };

const SKIN_TONES = {
  pale: '#fae0cb',
  light: '#f1c27d',
  medium: '#c69062',
  deep: '#926140',
  chocolate: '#5e3c28'
};
const SKIN_BASE = { r: 241, g: 194, b: 125 };
const SKIN_SHADOW = { r: 188, g: 151, b: 98 };
// The base sprite's shirt-collar color, exact-match recolored to a team's
// jersey color on the roster site. Left alone (undefined jerseyHex) on the
// character mixer, which has no notion of teams.
const SHIRT_BASE = { r: 29, g: 66, b: 138 };

const imageCache = {};
const recolorCache = {};
const IMG_CACHE_BUST = '?_=' + Date.now();

function loadImage(src) {
  const busted = src + IMG_CACHE_BUST;
  if (imageCache[busted]) return imageCache[busted];
  const promise = new Promise((resolve) => {
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = () => {
      console.warn('Failed to load image, skipping:', src);
      resolve(null);
    };
    img.src = busted;
  });
  imageCache[busted] = promise;
  return promise;
}

function hexToRgb(hex) {
  const n = parseInt(hex.slice(1), 16);
  return { r: (n >> 16) & 255, g: (n >> 8) & 255, b: n & 255 };
}

function getSkinShadow(targetBase) {
  return {
    r: Math.round(targetBase.r * (SKIN_SHADOW.r / SKIN_BASE.r)),
    g: Math.round(targetBase.g * (SKIN_SHADOW.g / SKIN_BASE.g)),
    b: Math.round(targetBase.b * (SKIN_SHADOW.b / SKIN_BASE.b))
  };
}

async function getRecoloredMagenta(folder, file, colorKey) {
  if (!colorKey || !ALL_HAIR_COLORS[colorKey]) {
    if (colorKey) console.warn('Unknown hair color key, drawing uncolored:', colorKey, folder + '/' + file);
    return loadImage(folder + '/' + file);
  }

  const cacheKey = folder + '/' + file + '|' + colorKey;
  if (recolorCache[cacheKey]) return recolorCache[cacheKey];

  const img = await loadImage(folder + '/' + file);
  const canvas = document.createElement('canvas');
  canvas.width = img.width;
  canvas.height = img.height;
  const ctx = canvas.getContext('2d');
  ctx.drawImage(img, 0, 0);

  const target = hexToRgb(ALL_HAIR_COLORS[colorKey]);
  const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
  const data = imageData.data;
  for (let i = 0; i < data.length; i += 4) {
    const r = data[i], g = data[i + 1], b = data[i + 2], a = data[i + 3];
    if (a === 0) continue;
    // magenta placeholder (any brightness): R == B, G ~ 0
    if (r === b && g <= 5 && r > 0) {
      const factor = r / 255;
      data[i] = Math.round(target.r * factor);
      data[i + 1] = Math.round(target.g * factor);
      data[i + 2] = Math.round(target.b * factor);
    }
  }
  ctx.putImageData(imageData, 0, 0);

  recolorCache[cacheKey] = canvas;
  return canvas;
}

// Recolors the base sprite's skin (+ shadow tone) and, if jerseyHex is
// given, its shirt collar too. jerseyHex omitted/null leaves the shirt at
// its default navy - that's what the character mixer wants, since it has
// no team context.
async function getRecoloredBase(skinToneKey, jerseyHex, baseSprite = BASE) {
  const hasSkin = skinToneKey && SKIN_TONES[skinToneKey];
  if (!hasSkin && !jerseyHex) return loadImage(baseSprite);

  const cacheKey = 'base|' + baseSprite + '|' + (skinToneKey || '') + '|' + (jerseyHex || '');
  if (recolorCache[cacheKey]) return recolorCache[cacheKey];

  const img = await loadImage(baseSprite);
  const canvas = document.createElement('canvas');
  canvas.width = img.width;
  canvas.height = img.height;
  const ctx = canvas.getContext('2d');
  ctx.drawImage(img, 0, 0);

  const targetSkin = hasSkin ? hexToRgb(SKIN_TONES[skinToneKey]) : SKIN_BASE;
  const targetShadow = hasSkin ? getSkinShadow(targetSkin) : SKIN_SHADOW;
  const targetShirt = jerseyHex ? hexToRgb(jerseyHex) : SHIRT_BASE;

  const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
  const data = imageData.data;
  for (let i = 0; i < data.length; i += 4) {
    const r = data[i], g = data[i + 1], b = data[i + 2];
    if (r === SKIN_BASE.r && g === SKIN_BASE.g && b === SKIN_BASE.b) {
      data[i] = targetSkin.r; data[i + 1] = targetSkin.g; data[i + 2] = targetSkin.b;
    } else if (r === SKIN_SHADOW.r && g === SKIN_SHADOW.g && b === SKIN_SHADOW.b) {
      data[i] = targetShadow.r; data[i + 1] = targetShadow.g; data[i + 2] = targetShadow.b;
    } else if (r === SHIRT_BASE.r && g === SHIRT_BASE.g && b === SHIRT_BASE.b) {
      data[i] = targetShirt.r; data[i + 1] = targetShirt.g; data[i + 2] = targetShirt.b;
    }
  }
  ctx.putImageData(imageData, 0, 0);

  recolorCache[cacheKey] = canvas;
  return canvas;
}

// Kept for backwards compatibility with existing call sites.
function getRecoloredSkin(skinToneKey) {
  return getRecoloredBase(skinToneKey, null);
}

async function getRecoloredNose(file, skinToneKey) {
  if (!skinToneKey || !SKIN_TONES[skinToneKey]) return loadImage('nose/' + file);

  const cacheKey = 'nose|' + file + '|' + skinToneKey;
  if (recolorCache[cacheKey]) return recolorCache[cacheKey];

  const img = await loadImage('nose/' + file);
  const canvas = document.createElement('canvas');
  canvas.width = img.width;
  canvas.height = img.height;
  const ctx = canvas.getContext('2d');
  ctx.drawImage(img, 0, 0);

  const targetBase = hexToRgb(SKIN_TONES[skinToneKey]);
  const targetShadow = getSkinShadow(targetBase);
  const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
  const data = imageData.data;
  for (let i = 0; i < data.length; i += 4) {
    const r = data[i], g = data[i + 1], b = data[i + 2], a = data[i + 3];
    if (a === 0) continue;
    // nose shadow color (#bc9762) -> skin shadow for selected tone
    if (r === SKIN_SHADOW.r && g === SKIN_SHADOW.g && b === SKIN_SHADOW.b) {
      data[i] = targetShadow.r;
      data[i + 1] = targetShadow.g;
      data[i + 2] = targetShadow.b;
    }
  }
  ctx.putImageData(imageData, 0, 0);

  recolorCache[cacheKey] = canvas;
  return canvas;
}

// face = {hair, hairColor, topHairColor, skinTone, eyes, eyebrows, nose,
// mouth, facial, accessories, shoulders} - same shape whether it came from
// the mixer's manual dropdowns, its random-grid roller, or a baked
// players.json entry. jerseyHex is optional (character mixer has no team
// context and omits it). isCoach skips the jersey recolor and can draw
// coach-only shoulder graphics.
async function drawFace(canvas, face, jerseyHex, isCoach = false, baseSprite = BASE) {
  const ctx = canvas.getContext('2d');
  ctx.clearRect(0, 0, canvas.width, canvas.height);

  const drawablePromises = [getRecoloredBase(face.skinTone, isCoach ? null : jerseyHex, baseSprite)];
  if (isCoach && face.shoulders) drawablePromises.push(loadImage('shoulders/' + face.shoulders));
  if (face.hair) drawablePromises.push(getRecoloredMagenta('hair', face.hair, face.topHairColor || face.hairColor));
  if (isCoach && face.hat) drawablePromises.push(loadImage('hats/' + face.hat));
  if (face.eyes) drawablePromises.push(loadImage('eyes/' + face.eyes));
  if (face.eyebrows) drawablePromises.push(getRecoloredMagenta('eyebrows', face.eyebrows, face.hairColor));
  if (isCoach && face.glasses) drawablePromises.push(loadImage('glasses/' + face.glasses));
  if (face.nose) drawablePromises.push(getRecoloredNose(face.nose, face.skinTone));
  if (face.mouth) drawablePromises.push(loadImage('mouth/' + face.mouth));
  if (isCoach && face.facial) drawablePromises.push(getRecoloredMagenta('facial', face.facial, face.hairColor));
  if (face.accessories) drawablePromises.push(loadImage('accessories/' + face.accessories));

  const drawables = (await Promise.all(drawablePromises)).filter(Boolean);

  ctx.save();
  ctx.imageSmoothingEnabled = false;
  const zoom = canvas.width / 32;
  ctx.scale(zoom, zoom);
  drawables.forEach(d => ctx.drawImage(d, 0, 0));
  ctx.restore();
}
