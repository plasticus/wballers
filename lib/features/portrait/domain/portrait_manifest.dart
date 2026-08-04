/// The available portrait asset filenames by category (`manifest.json`,
/// `portraits.md`). Used by the renderer to resolve an asset path; the
/// generator instead draws on [PortraitWeights], which is the source of
/// truth for what's choosable (including "none").
class PortraitManifest {
  const PortraitManifest({
    required this.hair,
    required this.eyes,
    required this.eyebrows,
    required this.nose,
    required this.mouth,
    required this.facial,
    required this.accessories,
    required this.shoulders,
    required this.hats,
    required this.glasses,
  });

  final List<String> hair;
  final List<String> eyes;
  final List<String> eyebrows;
  final List<String> nose;
  final List<String> mouth;
  final List<String> facial;
  final List<String> accessories;
  final List<String> shoulders;
  final List<String> hats;
  final List<String> glasses;
}

PortraitManifest portraitManifestFromJson(Map<String, dynamic> json) {
  List<String> stringList(String key) =>
      (json[key] as List<dynamic>).cast<String>();

  return PortraitManifest(
    hair: stringList('hair'),
    eyes: stringList('eyes'),
    eyebrows: stringList('eyebrows'),
    nose: stringList('nose'),
    mouth: stringList('mouth'),
    facial: stringList('facial'),
    accessories: stringList('accessories'),
    shoulders: stringList('shoulders'),
    hats: stringList('hats'),
    glasses: stringList('glasses'),
  );
}
