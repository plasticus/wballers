import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/portrait/persistence/portrait_catalog_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loadPortraitManifest parses the real bundled manifest.json', () async {
    final manifest = await loadPortraitManifest();

    expect(manifest.hair, isNotEmpty);
    expect(manifest.eyes, isNotEmpty);
    expect(manifest.eyebrows, isNotEmpty);
    expect(manifest.nose, isNotEmpty);
    expect(manifest.mouth, isNotEmpty);
    expect(manifest.facial, isNotEmpty);
    expect(manifest.accessories, isNotEmpty);
    expect(manifest.shoulders, isNotEmpty);
    expect(manifest.hats, isNotEmpty);
    expect(manifest.glasses, isNotEmpty);
  });

  test('loadPortraitWeights parses the real bundled weights.json', () async {
    final weights = await loadPortraitWeights();

    expect(weights.skinTone, isNotEmpty);
    expect(weights.hairColorByTone, isNotEmpty);
    for (final tone in weights.skinTone.keys) {
      expect(
        weights.hairColorByTone,
        contains(tone),
        reason: 'every skin tone needs a hair-color distribution',
      );
    }
    expect(weights.hair, isNotEmpty);
    expect(weights.neonHair, isNotEmpty);
    expect(weights.eyes, isNotEmpty);
    expect(weights.nose, isNotEmpty);
    expect(weights.mouth, isNotEmpty);
    expect(weights.eyebrows, isNotEmpty);
    expect(weights.facial, isNotEmpty);
    expect(weights.accessories, isNotEmpty);
  });
}
