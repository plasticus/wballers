/// USA-only given names that floor a generated player's skin tone to
/// medium/deep/chocolate -- pale and light are excluded outright, not
/// just down-weighted, for anyone drawing one of these first names from
/// [Country.usa]'s pool. `player_generator.dart` is the only place this
/// gets applied, and USA is the *only* [Country] any name-based logic
/// touches -- every other country's skin tone comes from
/// `weights.json`'s `skin_tone_by_country` table alone, exactly like
/// [Country.usa]'s own base table does for every name not on this list.
///
/// A direct GM design call (2026-08-10): not an attempt at precise
/// ethnic-name modeling, and deliberately narrow in scope -- "some very
/// black ethnic names shouldn't be able to be below a skin-tier of
/// 3/Medium." A second, larger "borderline" set of USA names was
/// considered and explicitly rejected for this treatment -- those get no
/// restriction at all, same full pale-to-chocolate gamut as any other USA
/// name.
const kSkinToneFlooredGivenNames = <String>{
  "A'ja",
  'Aaliyah',
  'Aliyah',
  'Alisha',
  'Allisha',
  'Ayanna',
  'Bria',
  'Briana',
  'Brianna',
  'Chamique',
  'Chennedy',
  'Chiney',
  'Dearica',
  'Deja',
  'Destanni',
  'Destinee',
  'Destiny',
  'DeWanna',
  'Diamond',
  'Ebony',
  'Epiphanny',
  'Imani',
  'Jada',
  'Jasmine',
  'Jonquel',
  'Jordin',
  'Kahleah',
  'Keana',
  'Keisha',
  'Kia',
  'Kiah',
  'Kiana',
  'Kiara',
  'Krystal',
  'Kysre',
  'Latasha',
  'LaToya',
  'Layshia',
  'Monique',
  'Myisha',
  'NaLyssa',
  'Napheesa',
  'Nia',
  'Nneka',
  'Odyssey',
  'Raven',
  'Satou',
  'Seimone',
  'Shanice',
  'Shauna',
  'Simone',
  'Swin',
  'Taj',
  'Tamika',
  'Tanesha',
  'Tanisha',
  'Tasha',
  'Tasia',
  'Teaira',
  'Tiana',
  'Tierra',
  'Tyasha',
};
