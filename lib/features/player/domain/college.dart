/// Which of `colleges.md`'s 5 broad regions a [College] belongs to --
/// flavor/grouping only, no mechanical effect.
enum CollegeRegion { west, midwest, northeast, south, canada }

/// How strong a program's recruiting pipeline usually is. Per
/// `colleges.md`'s own draft-pool guidelines: this affects which college a
/// player gets assigned to ([weightedColleges] weights toward [premier]
/// schools) but **never** their actual ratings -- potential, growth, and
/// outcomes are generated completely independently of it (`0B_Planned.md`'s
/// Draft item).
enum CollegePrestige { developing, strong, premier }

/// One fictional college a domestic (non-international, see
/// `player_generator_data.dart`'s `kInternationalHometowns`) player went
/// to (`colleges.md` is the source of truth this was transcribed from --
/// update both together if the list changes). Started as a draft-prospect-
/// only concept (`draft/domain/draft_prospect.dart`) before moving here
/// (2026-08-10) once every generated player -- not just draft prospects --
/// started getting one (`Player.college`, `player_generator.dart`): a
/// domestic player's alma mater isn't really a draft-specific fact.
class College {
  const College({
    required this.abbreviation,
    required this.name,
    required this.location,
    required this.region,
    required this.prestige,
  });

  /// Exactly 3 uppercase letters, unique across [kColleges].
  final String abbreviation;
  final String name;

  /// "City, State/Province" -- display text, not structured data.
  final String location;
  final CollegeRegion region;
  final CollegePrestige prestige;
}

/// All 100 fictional colleges from `colleges.md`, in the same order.
const List<College> kColleges = [
  College(
    abbreviation: 'RCU',
    name: 'Redwood Coast University',
    location: 'Eureka, CA',
    region: CollegeRegion.west,
    prestige: CollegePrestige.strong,
  ),
  College(
    abbreviation: 'CVU',
    name: 'Cascade Valley University',
    location: 'Bend, OR',
    region: CollegeRegion.west,
    prestige: CollegePrestige.premier,
  ),
  College(
    abbreviation: 'SVI',
    name: 'Soundview Institute',
    location: 'Tacoma, WA',
    region: CollegeRegion.west,
    prestige: CollegePrestige.strong,
  ),
  College(
    abbreviation: 'CRU',
    name: 'Columbia Ridge University',
    location: 'Yakima, WA',
    region: CollegeRegion.west,
    prestige: CollegePrestige.developing,
  ),
  College(
    abbreviation: 'HDS',
    name: 'High Desert State',
    location: 'Boise, ID',
    region: CollegeRegion.west,
    prestige: CollegePrestige.strong,
  ),
  College(
    abbreviation: 'SBU',
    name: 'Silver Basin University',
    location: 'Reno, NV',
    region: CollegeRegion.west,
    prestige: CollegePrestige.developing,
  ),
  College(
    abbreviation: 'SOT',
    name: 'Sonoran Technical Institute',
    location: 'Tucson, AZ',
    region: CollegeRegion.west,
    prestige: CollegePrestige.premier,
  ),
  College(
    abbreviation: 'FRC',
    name: 'Front Range College',
    location: 'Fort Collins, CO',
    region: CollegeRegion.west,
    prestige: CollegePrestige.strong,
  ),
  College(
    abbreviation: 'WSS',
    name: 'Wasatch State School',
    location: 'Provo, UT',
    region: CollegeRegion.west,
    prestige: CollegePrestige.developing,
  ),
  College(
    abbreviation: 'PSU',
    name: 'Prairie Sky University',
    location: 'Billings, MT',
    region: CollegeRegion.west,
    prestige: CollegePrestige.developing,
  ),
  College(
    abbreviation: 'CVL',
    name: 'Central Valley State',
    location: 'Fresno, CA',
    region: CollegeRegion.west,
    prestige: CollegePrestige.premier,
  ),
  College(
    abbreviation: 'IEU',
    name: 'Inland Empire University',
    location: 'Riverside, CA',
    region: CollegeRegion.west,
    prestige: CollegePrestige.strong,
  ),
  College(
    abbreviation: 'GGC',
    name: 'Golden Gate Coast College',
    location: 'Oakland, CA',
    region: CollegeRegion.west,
    prestige: CollegePrestige.strong,
  ),
  College(
    abbreviation: 'SSC',
    name: 'Salish Sea College',
    location: 'Bellingham, WA',
    region: CollegeRegion.west,
    prestige: CollegePrestige.developing,
  ),
  College(
    abbreviation: 'SRU',
    name: 'Snake River University',
    location: 'Idaho Falls, ID',
    region: CollegeRegion.west,
    prestige: CollegePrestige.developing,
  ),
  College(
    abbreviation: 'FCC',
    name: 'Four Corners College',
    location: 'Durango, CO',
    region: CollegeRegion.west,
    prestige: CollegePrestige.strong,
  ),
  College(
    abbreviation: 'HMU',
    name: 'Highland Mesa University',
    location: 'Albuquerque, NM',
    region: CollegeRegion.west,
    prestige: CollegePrestige.premier,
  ),
  College(
    abbreviation: 'LTC',
    name: 'Lake Tahoe College',
    location: 'Carson City, NV',
    region: CollegeRegion.west,
    prestige: CollegePrestige.developing,
  ),
  College(
    abbreviation: 'WVU',
    name: 'Willamette Valley University',
    location: 'Salem, OR',
    region: CollegeRegion.west,
    prestige: CollegePrestige.strong,
  ),
  College(
    abbreviation: 'PST',
    name: 'Puget Sound Technical',
    location: 'Everett, WA',
    region: CollegeRegion.west,
    prestige: CollegePrestige.developing,
  ),
  College(
    abbreviation: 'LSI',
    name: 'Lakeshore Institute',
    location: 'Milwaukee, WI',
    region: CollegeRegion.midwest,
    prestige: CollegePrestige.premier,
  ),
  College(
    abbreviation: 'NSC',
    name: 'North Star College',
    location: 'Duluth, MN',
    region: CollegeRegion.midwest,
    prestige: CollegePrestige.strong,
  ),
  College(
    abbreviation: 'RBU',
    name: 'Riverbend University',
    location: 'Davenport, IA',
    region: CollegeRegion.midwest,
    prestige: CollegePrestige.developing,
  ),
  College(
    abbreviation: 'GPS',
    name: 'Great Plains State',
    location: 'Lincoln, NE',
    region: CollegeRegion.midwest,
    prestige: CollegePrestige.strong,
  ),
  College(
    abbreviation: 'FHU',
    name: 'Flint Hills University',
    location: 'Manhattan, KS',
    region: CollegeRegion.midwest,
    prestige: CollegePrestige.developing,
  ),
  College(
    abbreviation: 'RRC',
    name: 'Red River College',
    location: 'Fargo, ND',
    region: CollegeRegion.midwest,
    prestige: CollegePrestige.strong,
  ),
  College(
    abbreviation: 'BHI',
    name: 'Black Hills Institute',
    location: 'Rapid City, SD',
    region: CollegeRegion.midwest,
    prestige: CollegePrestige.developing,
  ),
  College(
    abbreviation: 'MMU',
    name: 'Midland Metro University',
    location: 'Des Moines, IA',
    region: CollegeRegion.midwest,
    prestige: CollegePrestige.strong,
  ),
  College(
    abbreviation: 'CSS',
    name: 'Crossroads State School',
    location: 'Indianapolis, IN',
    region: CollegeRegion.midwest,
    prestige: CollegePrestige.premier,
  ),
  College(
    abbreviation: 'LEU',
    name: 'Lake Erie University',
    location: 'Toledo, OH',
    region: CollegeRegion.midwest,
    prestige: CollegePrestige.strong,
  ),
  College(
    abbreviation: 'AVC',
    name: 'Allegheny Valley College',
    location: 'Erie, PA',
    region: CollegeRegion.midwest,
    prestige: CollegePrestige.developing,
  ),
  College(
    abbreviation: 'TSS',
    name: 'Timberline State School',
    location: 'Marquette, MI',
    region: CollegeRegion.midwest,
    prestige: CollegePrestige.developing,
  ),
  College(
    abbreviation: 'PGU',
    name: 'Prairie Gate University',
    location: 'Springfield, IL',
    region: CollegeRegion.midwest,
    prestige: CollegePrestige.strong,
  ),
  College(
    abbreviation: 'GWT',
    name: 'Gateway Technical',
    location: 'St. Louis, MO',
    region: CollegeRegion.midwest,
    prestige: CollegePrestige.premier,
  ),
  College(
    abbreviation: 'BGS',
    name: 'Bluegrass State',
    location: 'Lexington, KY',
    region: CollegeRegion.midwest,
    prestige: CollegePrestige.strong,
  ),
  College(
    abbreviation: 'HHU',
    name: 'Hoosier Hills University',
    location: 'Bloomington, IN',
    region: CollegeRegion.midwest,
    prestige: CollegePrestige.developing,
  ),
  College(
    abbreviation: 'RBC',
    name: 'Rust Belt College',
    location: 'Youngstown, OH',
    region: CollegeRegion.midwest,
    prestige: CollegePrestige.developing,
  ),
  College(
    abbreviation: 'MRU',
    name: 'Maple River University',
    location: 'Mankato, MN',
    region: CollegeRegion.midwest,
    prestige: CollegePrestige.strong,
  ),
  College(
    abbreviation: 'HRT',
    name: 'Heartland Technical',
    location: 'Wichita, KS',
    region: CollegeRegion.midwest,
    prestige: CollegePrestige.premier,
  ),
  College(
    abbreviation: 'BCC',
    name: 'Bay Shore College',
    location: 'Green Bay, WI',
    region: CollegeRegion.midwest,
    prestige: CollegePrestige.developing,
  ),
  College(
    abbreviation: 'GSU',
    name: 'Granite State University',
    location: 'Concord, NH',
    region: CollegeRegion.northeast,
    prestige: CollegePrestige.strong,
  ),
  College(
    abbreviation: 'PHC',
    name: 'Pine Harbor College',
    location: 'Portland, ME',
    region: CollegeRegion.northeast,
    prestige: CollegePrestige.developing,
  ),
  College(
    abbreviation: 'CHV',
    name: 'Champlain Valley University',
    location: 'Burlington, VT',
    region: CollegeRegion.northeast,
    prestige: CollegePrestige.strong,
  ),
  College(
    abbreviation: 'EMC',
    name: 'Empire Metro College',
    location: 'Albany, NY',
    region: CollegeRegion.northeast,
    prestige: CollegePrestige.premier,
  ),
  College(
    abbreviation: 'HHY',
    name: 'Hudson Heights University',
    location: 'Poughkeepsie, NY',
    region: CollegeRegion.northeast,
    prestige: CollegePrestige.strong,
  ),
  College(
    abbreviation: 'KST',
    name: 'Keystone Technical',
    location: 'Scranton, PA',
    region: CollegeRegion.northeast,
    prestige: CollegePrestige.developing,
  ),
  College(
    abbreviation: 'DBU',
    name: 'Delaware Bay University',
    location: 'Dover, DE',
    region: CollegeRegion.northeast,
    prestige: CollegePrestige.developing,
  ),
  College(
    abbreviation: 'GSC',
    name: 'Garden State College',
    location: 'Trenton, NJ',
    region: CollegeRegion.northeast,
    prestige: CollegePrestige.strong,
  ),
  College(
    abbreviation: 'HPU',
    name: 'Harbor Point University',
    location: 'Baltimore, MD',
    region: CollegeRegion.northeast,
    prestige: CollegePrestige.premier,
  ),
  College(
    abbreviation: 'CDC',
    name: 'Capital District College',
    location: 'Washington, DC',
    region: CollegeRegion.northeast,
    prestige: CollegePrestige.strong,
  ),
  College(
    abbreviation: 'ODM',
    name: 'Old Dominion Metro',
    location: 'Richmond, VA',
    region: CollegeRegion.northeast,
    prestige: CollegePrestige.developing,
  ),
  College(
    abbreviation: 'BRS',
    name: 'Blue Ridge State',
    location: 'Roanoke, VA',
    region: CollegeRegion.northeast,
    prestige: CollegePrestige.strong,
  ),
  College(
    abbreviation: 'ACU',
    name: 'Appalachian Crest University',
    location: 'Morgantown, WV',
    region: CollegeRegion.northeast,
    prestige: CollegePrestige.developing,
  ),
  College(
    abbreviation: 'SCI',
    name: 'Steel City Institute',
    location: 'Pittsburgh, PA',
    region: CollegeRegion.northeast,
    prestige: CollegePrestige.premier,
  ),
  College(
    abbreviation: 'SVC',
    name: 'Susquehanna Valley College',
    location: 'Harrisburg, PA',
    region: CollegeRegion.northeast,
    prestige: CollegePrestige.developing,
  ),
  College(
    abbreviation: 'ADS',
    name: 'Adirondack State',
    location: 'Syracuse, NY',
    region: CollegeRegion.northeast,
    prestige: CollegePrestige.strong,
  ),
  College(
    abbreviation: 'LIM',
    name: 'Long Island Metro',
    location: 'Hempstead, NY',
    region: CollegeRegion.northeast,
    prestige: CollegePrestige.strong,
  ),
  College(
    abbreviation: 'CRI',
    name: 'Connecticut River Institute',
    location: 'Hartford, CT',
    region: CollegeRegion.northeast,
    prestige: CollegePrestige.developing,
  ),
  College(
    abbreviation: 'BSC',
    name: 'Bay State College',
    location: 'Worcester, MA',
    region: CollegeRegion.northeast,
    prestige: CollegePrestige.premier,
  ),
  College(
    abbreviation: 'PCU',
    name: 'Providence Coast University',
    location: 'Providence, RI',
    region: CollegeRegion.northeast,
    prestige: CollegePrestige.strong,
  ),
  College(
    abbreviation: 'PSS',
    name: 'Palmetto State School',
    location: 'Columbia, SC',
    region: CollegeRegion.south,
    prestige: CollegePrestige.strong,
  ),
  College(
    abbreviation: 'PEC',
    name: 'Peach State College',
    location: 'Atlanta, GA',
    region: CollegeRegion.south,
    prestige: CollegePrestige.premier,
  ),
  College(
    abbreviation: 'GCT',
    name: 'Gulf Coast Technical',
    location: 'Mobile, AL',
    region: CollegeRegion.south,
    prestige: CollegePrestige.developing,
  ),
  College(
    abbreviation: 'MGU',
    name: 'Magnolia University',
    location: 'Jackson, MS',
    region: CollegeRegion.south,
    prestige: CollegePrestige.strong,
  ),
  College(
    abbreviation: 'DRS',
    name: 'Delta River State',
    location: 'Little Rock, AR',
    region: CollegeRegion.south,
    prestige: CollegePrestige.developing,
  ),
  College(
    abbreviation: 'OZV',
    name: 'Ozark Valley University',
    location: 'Fayetteville, AR',
    region: CollegeRegion.south,
    prestige: CollegePrestige.strong,
  ),
  College(
    abbreviation: 'BYS',
    name: 'Bayou State School',
    location: 'Baton Rouge, LA',
    region: CollegeRegion.south,
    prestige: CollegePrestige.premier,
  ),
  College(
    abbreviation: 'LSM',
    name: 'Lone Star Metro',
    location: 'San Antonio, TX',
    region: CollegeRegion.south,
    prestige: CollegePrestige.strong,
  ),
  College(
    abbreviation: 'RGC',
    name: 'Rio Grande College',
    location: 'El Paso, TX',
    region: CollegeRegion.south,
    prestige: CollegePrestige.developing,
  ),
  College(
    abbreviation: 'HPL',
    name: 'High Plains University',
    location: 'Amarillo, TX',
    region: CollegeRegion.south,
    prestige: CollegePrestige.strong,
  ),
  College(
    abbreviation: 'SCU',
    name: 'Suncoast University',
    location: 'Tampa, FL',
    region: CollegeRegion.south,
    prestige: CollegePrestige.premier,
  ),
  College(
    abbreviation: 'EVT',
    name: 'Everglade Technical',
    location: 'Orlando, FL',
    region: CollegeRegion.south,
    prestige: CollegePrestige.strong,
  ),
  College(
    abbreviation: 'SPC',
    name: 'Space Coast College',
    location: 'Melbourne, FL',
    region: CollegeRegion.south,
    prestige: CollegePrestige.developing,
  ),
  College(
    abbreviation: 'TVU',
    name: 'Tennessee Valley University',
    location: 'Knoxville, TN',
    region: CollegeRegion.south,
    prestige: CollegePrestige.strong,
  ),
  College(
    abbreviation: 'MCC',
    name: 'Music City College',
    location: 'Nashville, TN',
    region: CollegeRegion.south,
    prestige: CollegePrestige.premier,
  ),
  College(
    abbreviation: 'CPU',
    name: 'Carolina Piedmont University',
    location: 'Greensboro, NC',
    region: CollegeRegion.south,
    prestige: CollegePrestige.strong,
  ),
  College(
    abbreviation: 'OBC',
    name: 'Outer Banks College',
    location: 'Greenville, NC',
    region: CollegeRegion.south,
    prestige: CollegePrestige.developing,
  ),
  College(
    abbreviation: 'SMS',
    name: 'Smoky Mountain State',
    location: 'Asheville, NC',
    region: CollegeRegion.south,
    prestige: CollegePrestige.strong,
  ),
  College(
    abbreviation: 'CGU',
    name: 'Coastal Georgia University',
    location: 'Savannah, GA',
    region: CollegeRegion.south,
    prestige: CollegePrestige.developing,
  ),
  College(
    abbreviation: 'RCL',
    name: 'Red Clay College',
    location: 'Macon, GA',
    region: CollegeRegion.south,
    prestige: CollegePrestige.developing,
  ),
  College(
    abbreviation: 'PRU',
    name: 'Pacific Rain University',
    location: 'Victoria, BC',
    region: CollegeRegion.canada,
    prestige: CollegePrestige.premier,
  ),
  College(
    abbreviation: 'FVC',
    name: 'Fraser Valley College',
    location: 'Abbotsford, BC',
    region: CollegeRegion.canada,
    prestige: CollegePrestige.strong,
  ),
  College(
    abbreviation: 'RMN',
    name: 'Rocky Mountain North University',
    location: 'Calgary, AB',
    region: CollegeRegion.canada,
    prestige: CollegePrestige.strong,
  ),
  College(
    abbreviation: 'PCC',
    name: 'Prairie Crown College',
    location: 'Regina, SK',
    region: CollegeRegion.canada,
    prestige: CollegePrestige.developing,
  ),
  College(
    abbreviation: 'RRN',
    name: 'Red River North University',
    location: 'Winnipeg, MB',
    region: CollegeRegion.canada,
    prestige: CollegePrestige.strong,
  ),
  College(
    abbreviation: 'SSS',
    name: 'Superior Shores College',
    location: 'Thunder Bay, ON',
    region: CollegeRegion.canada,
    prestige: CollegePrestige.developing,
  ),
  College(
    abbreviation: 'GHU',
    name: 'Golden Horseshoe University',
    location: 'Hamilton, ON',
    region: CollegeRegion.canada,
    prestige: CollegePrestige.premier,
  ),
  College(
    abbreviation: 'COC',
    name: 'Capital Ottawa College',
    location: 'Ottawa, ON',
    region: CollegeRegion.canada,
    prestige: CollegePrestige.strong,
  ),
  College(
    abbreviation: 'SLT',
    name: 'St. Lawrence Technical',
    location: 'Kingston, ON',
    region: CollegeRegion.canada,
    prestige: CollegePrestige.developing,
  ),
  College(
    abbreviation: 'LMU',
    name: 'Laurentian Metro University',
    location: 'Sudbury, ON',
    region: CollegeRegion.canada,
    prestige: CollegePrestige.strong,
  ),
  College(
    abbreviation: 'MLC',
    name: 'Maple Coast College',
    location: 'Toronto, ON',
    region: CollegeRegion.canada,
    prestige: CollegePrestige.premier,
  ),
  College(
    abbreviation: 'QCI',
    name: 'Quebec City Institute',
    location: 'Quebec City, QC',
    region: CollegeRegion.canada,
    prestige: CollegePrestige.strong,
  ),
  College(
    abbreviation: 'SMU',
    name: 'St. Maurice University',
    location: 'Trois-Rivieres, QC',
    region: CollegeRegion.canada,
    prestige: CollegePrestige.developing,
  ),
  College(
    abbreviation: 'MBC',
    name: 'Maritime Bay College',
    location: 'Moncton, NB',
    region: CollegeRegion.canada,
    prestige: CollegePrestige.developing,
  ),
  College(
    abbreviation: 'FCN',
    name: 'Fundy Coast University',
    location: 'Saint John, NB',
    region: CollegeRegion.canada,
    prestige: CollegePrestige.strong,
  ),
  College(
    abbreviation: 'NLU',
    name: 'Northern Lakes University',
    location: 'Saskatoon, SK',
    region: CollegeRegion.canada,
    prestige: CollegePrestige.developing,
  ),
  College(
    abbreviation: 'ATC',
    name: 'Atlantic Technical College',
    location: 'Charlottetown, PE',
    region: CollegeRegion.canada,
    prestige: CollegePrestige.developing,
  ),
  College(
    abbreviation: 'CBU',
    name: 'Copper Belt University',
    location: 'Sudbury, ON',
    region: CollegeRegion.canada,
    prestige: CollegePrestige.strong,
  ),
  College(
    abbreviation: 'PLU',
    name: 'Polar Lights University',
    location: 'Whitehorse, YT',
    region: CollegeRegion.canada,
    prestige: CollegePrestige.developing,
  ),
  College(
    abbreviation: 'RSC',
    name: 'Rosewood College',
    location: 'London, ON',
    region: CollegeRegion.canada,
    prestige: CollegePrestige.developing,
  ),
];

/// [kColleges] repeated proportionally to their prestige (premier x3,
/// strong x2, developing x1) -- `colleges.md`'s draft-pool guideline that
/// prestige affects "prospect exposure," implemented as premier programs
/// simply producing more of the domestic-player pool, never as any effect
/// on an individual player's ratings ([College]'s own doc comment). Pick
/// a random entry from this (`weightedColleges()[random.nextInt(...)]`)
/// rather than picking straight from [kColleges] whenever a college needs
/// to feel realistically distributed by program strength -- both
/// `player_generator.dart` (every domestic player) and
/// `draft/generation/draft_generator.dart` (draft prospects specifically)
/// do this.
List<College> weightedColleges() {
  return [
    for (final college in kColleges)
      for (
        var i = 0;
        i <
            switch (college.prestige) {
              CollegePrestige.premier => 3,
              CollegePrestige.strong => 2,
              CollegePrestige.developing => 1,
            };
        i++
      )
        college,
  ];
}
