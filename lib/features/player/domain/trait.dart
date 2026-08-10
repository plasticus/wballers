/// The seven groupings `traits.md` organizes the catalog into -- used to
/// give a trait display something meaningful to color-code by, beyond an
/// arbitrary per-trait color.
enum TraitCategory {
  workEthic,
  durability,
  leadership,
  mental,
  loyalty,
  crowd,
  skillBadge,
}

/// Discrete, visible, earnable player traits (`traits.md`, question.md
/// decision 21) -- distinct from [Archetype], which describes playing
/// style. Traits describe psychology, career, and (for the skill-specific
/// set) situational bonuses beyond what the raw rating predicts.
enum Trait {
  // Work ethic / development
  highPotential,
  lowPotential,
  highlyCoachable,
  stubborn,
  gymRat,

  // Durability
  ironMan,
  injuryProne,

  // Leadership / chemistry
  leader,
  malcontent,
  noEgo,
  superEgo,

  // Mental / clutch
  clutch,
  choker,
  hotHead,
  primeTime,
  icyVeins,

  // Loyalty / career
  loyal,
  flightRisk,
  ringChaser,
  homegrown,

  // Crowd
  homeCourtHero,
  roadWarrior,

  // Skill-specific ("badges")
  glassCleaner,
  pickpocket,
  rimGuardian,
  backcourtBarrier,
  sharpshooter,
  slashersTouch,
  automatic,
}

extension TraitDetails on Trait {
  TraitCategory get category => switch (this) {
    Trait.highPotential ||
    Trait.lowPotential ||
    Trait.highlyCoachable ||
    Trait.stubborn ||
    Trait.gymRat => TraitCategory.workEthic,
    Trait.ironMan || Trait.injuryProne => TraitCategory.durability,
    Trait.leader ||
    Trait.malcontent ||
    Trait.noEgo ||
    Trait.superEgo => TraitCategory.leadership,
    Trait.clutch ||
    Trait.choker ||
    Trait.hotHead ||
    Trait.primeTime ||
    Trait.icyVeins => TraitCategory.mental,
    Trait.loyal ||
    Trait.flightRisk ||
    Trait.ringChaser ||
    Trait.homegrown => TraitCategory.loyalty,
    Trait.homeCourtHero || Trait.roadWarrior => TraitCategory.crowd,
    Trait.glassCleaner ||
    Trait.pickpocket ||
    Trait.rimGuardian ||
    Trait.backcourtBarrier ||
    Trait.sharpshooter ||
    Trait.slashersTouch ||
    Trait.automatic => TraitCategory.skillBadge,
  };

  String get label => switch (this) {
    Trait.highPotential => 'High Potential',
    Trait.lowPotential => 'Low Potential',
    Trait.highlyCoachable => 'Highly Coachable',
    Trait.stubborn => 'Stubborn',
    Trait.gymRat => 'Gym Rat',
    Trait.ironMan => 'Iron Man',
    Trait.injuryProne => 'Injury Prone',
    Trait.leader => 'Leader',
    Trait.malcontent => 'Malcontent',
    Trait.noEgo => 'No Ego',
    Trait.superEgo => 'Super Ego',
    Trait.clutch => 'Clutch',
    Trait.choker => 'Choker',
    Trait.hotHead => 'Hot Head',
    Trait.primeTime => 'Prime Time',
    Trait.icyVeins => 'Icy Veins',
    Trait.loyal => 'Loyal',
    Trait.flightRisk => 'Flight Risk',
    Trait.ringChaser => 'Ring Chaser',
    Trait.homegrown => 'Homegrown',
    Trait.homeCourtHero => 'Home Court Hero',
    Trait.roadWarrior => 'Road Warrior',
    Trait.glassCleaner => 'Glass Cleaner',
    Trait.pickpocket => 'Pickpocket',
    Trait.rimGuardian => 'Rim Guardian',
    Trait.backcourtBarrier => 'Backcourt Barrier',
    Trait.sharpshooter => 'Sharpshooter',
    Trait.slashersTouch => "Slasher's Touch",
    Trait.automatic => 'Automatic',
  };

  String get description => switch (this) {
    Trait.highPotential =>
      'Trains faster, more likely to reach or exceed their ceiling.',
    Trait.lowPotential =>
      'Trains slower, more likely to plateau below their ceiling.',
    Trait.highlyCoachable =>
      'Big training gains from a good Development coach; responds well to '
          'in-game tactical adjustments too.',
    Trait.stubborn =>
      'Resists coaching; smaller training gains and slower to buy into '
          'tactical calls, regardless of coach quality.',
    Trait.gymRat =>
      'Keeps improving in the offseason without needing focused coaching '
          'attention; ages more gracefully.',
    Trait.ironMan =>
      'Rarely sits out; unusually reliable game-to-game '
          'availability.',
    Trait.injuryProne =>
      'More frequent, longer injuries than physical ratings alone would '
          'suggest.',
    Trait.leader =>
      'Small team-wide morale/chemistry boost just from '
          'being on the roster.',
    Trait.malcontent =>
      'Team-wide morale penalty, worse during losing stretches.',
    Trait.noEgo =>
      'Accepts a reduced role without a morale hit; the glue guy who keeps '
          'a roster balanced.',
    Trait.superEgo =>
      'Morale drops if usage/shots are too low, even on a winning team.',
    Trait.clutch =>
      'Performance bump in late-game, high-leverage '
          'situations.',
    Trait.choker => 'Performance dip in those same situations.',
    Trait.hotHead =>
      'Elevated technical-foul/ejection risk after bad calls or physical '
          'play.',
    Trait.primeTime =>
      'Raises effort and performance specifically against ranked opponents '
          'or in marquee matchups.',
    Trait.icyVeins =>
      'Not shaken by pivotal moments; resistant to the pressure that would '
          'otherwise cause a dip, including free throws in close games.',
    Trait.loyal =>
      'Resists trade demands, takes team-friendly deals, morale holds up '
          'through losing seasons.',
    Trait.flightRisk =>
      'Pushes for a trade the moment the team slumps or a bigger star '
          'arrives.',
    Trait.ringChaser =>
      'Accepts a reduced role on a contender; unhappy on a rebuilder '
          'regardless of personal stats.',
    Trait.homegrown =>
      'Extra loyalty and fan-favorite bonus specifically for a player this '
          'franchise drafted and developed.',
    Trait.homeCourtHero =>
      'Extra ratings bump at home, on top of every home player\'s own '
          'home-court boost.',
    Trait.roadWarrior =>
      'Extra ratings bump on the road, unfazed by playing in front of a '
          'hostile crowd.',
    Trait.glassCleaner =>
      'Rebounding: wins contested boards beyond what strength/interior '
          'ratings alone predict.',
    Trait.pickpocket =>
      'Stealing: elevated success on steal/disruption '
          'attempts.',
    Trait.rimGuardian =>
      'Front-court blocking: elevated block success '
          'protecting the rim.',
    Trait.backcourtBarrier =>
      'Back-court blocking: elevated block success chasing down shots or '
          'contesting from the perimeter/in transition.',
    Trait.sharpshooter =>
      'Three-pointers: extra bump on contested or high-volume attempts.',
    Trait.slashersTouch =>
      'Layups: extra bump finishing through contact/traffic.',
    Trait.automatic => 'Free throws: elevated make rate as a raw skill.',
  };
}

/// Mutually exclusive pairs (`traits.md`) -- a player should never carry
/// both sides at once. Some are explicitly labeled "Opposite of X" in the
/// source doc; Highly Coachable/Stubborn and Iron Man/Injury Prone are
/// conceptually opposite even though the doc doesn't use that exact word.
const List<(Trait, Trait)> kOppositeTraitPairs = [
  (Trait.highPotential, Trait.lowPotential),
  (Trait.highlyCoachable, Trait.stubborn),
  (Trait.ironMan, Trait.injuryProne),
  (Trait.leader, Trait.malcontent),
  (Trait.noEgo, Trait.superEgo),
  (Trait.clutch, Trait.choker),
  (Trait.loyal, Trait.flightRisk),
];

Trait? oppositeOf(Trait trait) {
  for (final pair in kOppositeTraitPairs) {
    if (pair.$1 == trait) return pair.$2;
    if (pair.$2 == trait) return pair.$1;
  }
  return null;
}

/// Homegrown requires having been drafted by this franchise, which isn't
/// meaningful for a freshly generated roster -- expansion rosters aren't
/// drafted through the game's own (not-yet-built) draft system. Every
/// other trait is eligible to roll at player-generation time.
final Set<Trait> kGenerationEligibleTraits = Trait.values
    .where((trait) => trait != Trait.homegrown)
    .toSet();
