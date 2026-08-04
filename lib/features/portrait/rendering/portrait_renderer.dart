import 'dart:typed_data';
import 'dart:ui' as ui;

import '../domain/portrait_appearance.dart';
import 'pixel_recolor.dart';
import 'portrait_colors.dart';
import 'portrait_image_loader.dart';

/// Render at an integer multiple of the 32x32 source art so pixel edges
/// stay crisp (`portraits.md`).
const kPortraitOutputSize = 128;

Future<ui.Image> _loadPlain(String category, String fileKey) {
  return decodeAssetImage('$category/$fileKey.png');
}

Future<ui.Image> _loadMagentaRecolored(
  String category,
  String fileKey,
  String colorKey,
) async {
  final source = await decodeAssetImage('$category/$fileKey.png');
  final pixels = await imageToRgba(source);
  final target = resolveHairColor(colorKey);
  if (target != null) {
    recolorMagentaPlaceholder(pixels, target);
  }
  return rgbaToImage(pixels, source.width, source.height);
}

Future<ui.Image> _loadRecoloredBase(
  PortraitAppearance appearance,
  RgbColor? jersey,
) async {
  final source = await decodeAssetImage(appearance.baseSprite);
  final pixels = await imageToRgba(source);
  final skin = kSkinTones[appearance.skinTone];
  if (skin != null) {
    recolorBaseSprite(
      pixels,
      skin: skin,
      jersey: appearance.isCoach ? null : jersey,
    );
  }
  return rgbaToImage(pixels, source.width, source.height);
}

Future<ui.Image> _loadRecoloredNose(PortraitAppearance appearance) async {
  final source = await decodeAssetImage('nose/${appearance.nose}.png');
  final pixels = await imageToRgba(source);
  final skin = kSkinTones[appearance.skinTone];
  if (skin != null) {
    recolorNoseShadow(pixels, skin);
  }
  return rgbaToImage(pixels, source.width, source.height);
}

/// Composites every layer for [appearance], in the exact order
/// `portraits.md` specifies, and returns encoded PNG bytes at
/// [outputSize]x[outputSize]. [jersey] recolors the shirt collar for
/// athletes only -- coaches never get a jersey recolor, matching
/// `render.js`'s `isCoach` handling.
Future<Uint8List> renderPortraitPng(
  PortraitAppearance appearance, {
  RgbColor? jersey,
  int outputSize = kPortraitOutputSize,
}) async {
  final layers = <ui.Image>[await _loadRecoloredBase(appearance, jersey)];

  if (appearance.isCoach && appearance.shoulders != null) {
    layers.add(await _loadPlain('shoulders', appearance.shoulders!));
  }
  if (appearance.hair != null) {
    layers.add(
      await _loadMagentaRecolored(
        'hair',
        appearance.hair!,
        appearance.topHairColor ?? appearance.hairColor,
      ),
    );
  }
  if (appearance.isCoach && appearance.hat != null) {
    layers.add(await _loadPlain('hats', appearance.hat!));
  }
  layers.add(await _loadPlain('eyes', appearance.eyes));
  if (appearance.eyebrows != null) {
    layers.add(
      await _loadMagentaRecolored(
        'eyebrows',
        appearance.eyebrows!,
        appearance.hairColor,
      ),
    );
  }
  if (appearance.isCoach && appearance.glasses != null) {
    layers.add(await _loadPlain('glasses', appearance.glasses!));
  }
  layers.add(await _loadRecoloredNose(appearance));
  layers.add(await _loadPlain('mouth', appearance.mouth));
  if (appearance.isCoach && appearance.facial != null) {
    layers.add(
      await _loadMagentaRecolored(
        'facial',
        appearance.facial!,
        appearance.hairColor,
      ),
    );
  }
  if (appearance.accessories != null) {
    layers.add(await _loadPlain('accessories', appearance.accessories!));
  }

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final paint = ui.Paint()..filterQuality = ui.FilterQuality.none;
  final zoom = outputSize / kPortraitAssetSize;
  canvas.scale(zoom);
  for (final layer in layers) {
    canvas.drawImage(layer, ui.Offset.zero, paint);
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(outputSize, outputSize);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}
