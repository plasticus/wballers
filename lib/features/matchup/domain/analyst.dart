import '../../portrait/domain/portrait_appearance.dart';
import '../../portrait/generation/portrait_generator.dart'
    show kDefaultBaseSprite;

/// One panelist on the pre-game "Matchup Analysis" screen's analyst
/// panel -- a name and a portrait, nothing else. Her pick (which team she
/// favors) is never stored on her; it's computed fresh per matchup by
/// `matchup_analysis.dart`'s `analystVerdicts`, off whatever criterion
/// she's assigned there.
class Analyst {
  const Analyst({required this.name, required this.appearance});

  final String name;
  final PortraitAppearance appearance;
}

/// Returns [appearance] restyled for the analyst desk: a suit-jacket
/// silhouette and glasses layered on, everything else (face, hair, skin)
/// untouched. Coach-only [PortraitAppearance] fields, so this also forces
/// `isCoach: true` -- used for [kNarrativeVeteranSeatFallback]'s eventual
/// real replacement once a franchise's own veteran retires (see
/// `Franchise.narrativeVeteranAppearance`), not for the 4 fixed analysts
/// below, who are already generated as coaches.
PortraitAppearance asAnalystPortrait(PortraitAppearance appearance) {
  return appearance.copyWith(
    isCoach: true,
    shoulders: 'shoulder_black',
    glasses: 'glasses_thin_gold',
  );
}

/// The 4 fixed panelists every GM sees, every franchise -- a recurring
/// broadcast cast, not randomly generated per save (like a real network's
/// on-air talent doesn't change depending on who's watching). Exact
/// `PortraitAppearance` field values below were captured from the
/// GM-approved design lab (2026-08-12,
/// https://claude.ai/code/artifact/1323d3db-6fe2-49e7-90dc-417388e4b4a0,
/// round 3's final update: named skin tones, forced distinct haircuts) --
/// regenerated once via the same seeds/overrides that produced the
/// approved renders, then hardcoded here rather than re-rolled at runtime,
/// so the shipped faces are exactly the ones already reviewed.
const kAnalystReyes = Analyst(
  name: 'Reyes',
  appearance: PortraitAppearance(
    baseSprite: kDefaultBaseSprite,
    skinTone: 'medium',
    hair: 'hair_shaggy3',
    hairColor: 'gray',
    eyes: 'eyes_downleft',
    eyebrows: 'eyebrow_4',
    nose: 'nose_5',
    mouth: 'mouth_3',
    isCoach: true,
    shoulders: 'shoulder_beige',
  ),
);

const kAnalystShoemaker = Analyst(
  name: 'Shoemaker',
  appearance: PortraitAppearance(
    baseSprite: kDefaultBaseSprite,
    skinTone: 'pale',
    hair: 'hair_long',
    hairColor: 'blonde',
    eyes: 'eyes_wide',
    eyebrows: 'eyebrow_1',
    nose: 'nose_3',
    mouth: 'mouth_4',
    isCoach: true,
    shoulders: 'shoulder_brown',
  ),
);

const kAnalystAdebayo = Analyst(
  name: 'Adebayo',
  appearance: PortraitAppearance(
    baseSprite: kDefaultBaseSprite,
    skinTone: 'chocolate',
    hair: 'hair_afro',
    hairColor: 'black',
    eyes: 'eyes_1center',
    eyebrows: 'eyebrow_8',
    nose: 'nose_3',
    mouth: 'mouth_6',
    isCoach: true,
    shoulders: 'shoulder_brown',
  ),
);

const kAnalystValeJones = Analyst(
  name: 'Vale-Jones',
  appearance: PortraitAppearance(
    baseSprite: kDefaultBaseSprite,
    skinTone: 'deep',
    hair: 'hair_long2',
    hairColor: 'black',
    eyes: 'eyes_2left',
    eyebrows: 'eyebrow_7',
    nose: 'nose_2',
    mouth: 'mouth_2',
    isCoach: true,
    shoulders: 'shoulder_grey',
  ),
);

/// Seat 1's fallback look, shown until a franchise's own narrative
/// veteran (`starting_roster_generator.dart`'s hand-placed "grizzled
/// vet") actually retires -- same deep skin tone and `hair_chinlength3`
/// the real veteran ends up styled with (`asAnalystPortrait`), a
/// deliberate throughline so the seat reads consistently even though the
/// face underneath changes once she takes it over for real.
const kNarrativeVeteranSeatFallback = Analyst(
  name: 'Preston',
  appearance: PortraitAppearance(
    baseSprite: kDefaultBaseSprite,
    skinTone: 'deep',
    hair: 'hair_chinlength3',
    hairColor: 'darkbrown',
    eyes: 'eyes_1right',
    eyebrows: 'eyebrow_5',
    nose: 'nose_2',
    mouth: 'mouth_4',
    accessories: 'ear_both_block_silver',
    isCoach: true,
    shoulders: 'shoulder_black',
  ),
);

/// The 5 fixed panelists in their real seat order -- seat 1 (Preston) is
/// only ever [kNarrativeVeteranSeatFallback] here; the screen itself
/// swaps in the real veteran's own portrait once she's retired, since
/// that's franchise-specific data this constant list can't hold.
const kAnalystPanel = [
  kNarrativeVeteranSeatFallback,
  kAnalystReyes,
  kAnalystShoemaker,
  kAnalystAdebayo,
  kAnalystValeJones,
];
