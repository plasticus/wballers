import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/portrait/domain/portrait_manifest.dart';

void main() {
  test('portraitManifestFromJson parses every category', () {
    final manifest = portraitManifestFromJson({
      'hair': ['hair_afro.png', 'hair_bun.png'],
      'eyes': ['eyes_1center.png'],
      'eyebrows': ['eyebrow_1.png'],
      'nose': ['nose_1.png'],
      'mouth': ['mouth_1.png'],
      'facial': ['facial_goat.png'],
      'accessories': ['goggles_1.png'],
      'shoulders': ['shoulder_black.png'],
      'hats': ['hat_fedora.png'],
      'glasses': ['glasses_round.png'],
    });

    expect(manifest.hair, ['hair_afro.png', 'hair_bun.png']);
    expect(manifest.eyes, ['eyes_1center.png']);
    expect(manifest.eyebrows, ['eyebrow_1.png']);
    expect(manifest.nose, ['nose_1.png']);
    expect(manifest.mouth, ['mouth_1.png']);
    expect(manifest.facial, ['facial_goat.png']);
    expect(manifest.accessories, ['goggles_1.png']);
    expect(manifest.shoulders, ['shoulder_black.png']);
    expect(manifest.hats, ['hat_fedora.png']);
    expect(manifest.glasses, ['glasses_round.png']);
  });
}
