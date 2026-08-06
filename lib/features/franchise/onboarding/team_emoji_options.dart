/// A big curated pool of team-mascot-flavored emoji for onboarding's team
/// emoji picker -- animals, mythical/mascot symbols, and a few
/// competition-flavored icons, way more than the 20-team "wings" pool
/// used to offer. Deliberately not deduped against `kLeagueTeamPool`'s own
/// 40 team emoji here -- `OnboardingScreen` filters out whatever this
/// playthrough's league actually drew, the same "never shares an emoji
/// with a club you'll actually play against" guarantee the old picker
/// had, just sourced from a much bigger list.
const kTeamEmojiOptions = <String>[
  // Big cats & predators
  '🦁', '🐯', '🐆', '🐺', '🦊', '🐻', '🐻‍❄️', '🐼',
  // Horned & hooved
  '🐂', '🐃', '🐄', '🐎', '🦄', '🐗', '🐖', '🐏', '🐑', '🐐', '🦙', '🦌',
  '🦬', '🦏', '🦛', '🐫', '🐪', '🦒',
  // Small mammals
  '🐰', '🐇', '🦔', '🦡', '🦫', '🦦', '🦨', '🦝', '🐿️', '🦥',
  // Trunked & tusked
  '🐘', '🦣',
  // Birds
  '🦅', '🦆', '🦢', '🦉', '🦜', '🦩', '🐓', '🦃', '🦤', '🕊️', '🐦‍⬛',
  // Sea life
  '🦈', '🐬', '🐳', '🐋', '🐙', '🦑', '🦀', '🦞', '🦐', '🐠', '🐟', '🐡',
  '🦭', '🐢', '🪸',
  // Reptiles, amphibians, bugs
  '🐍', '🦎', '🐸', '🐝', '🦂', '🕷️', '🦋', '🐞',
  // Mythical / mascot energy
  '🐉', '🐲', '🦖', '🦕', '👑', '🛡️', '⚔️', '🏆', '⚡', '🔥', '💫', '⭐',
  '🌟', '✨', '☄️', '🌪️', '🌊', '❄️', '🎯',
];
