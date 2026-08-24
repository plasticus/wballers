<?php
/**
 * Trade Value Study Tool
 * ----------------------
 * A standalone tool for calibrating "does this trade actually feel fair?"
 * against the real WBL trade math (lib/features/trade/domain/trade_value.dart),
 * assuming a coach with 70 Management (a direct GM ask, 2026-08-23).
 *
 * Generates a fresh batch of trades every run (deterministic per `seed`,
 * so reloading the same URL shows the same batch until you ask for a new
 * one), lets you rate each -5..+5 (which side benefits) with a notes
 * field, and saves every rating permanently to ratings.json -- so you can
 * run this many times over many sessions and build up a real dataset.
 *
 * Run locally with PHP's built-in server:
 *   cd tools/trade_study && php -S localhost:8000
 * then open http://localhost:8000/ in a browser.
 *
 * Ported math (kept in sync by hand, not shared code -- this is a
 * standalone PHP tool, not part of the Flutter app):
 *   - kDraftPickTradeValue, tradeSwing() from trade_value.dart
 *   - skillPoints is approximated as overall*12 (+/- the same small
 *     rounding slack the real overall = round(skillPoints/12) allows),
 *     not simulated stat-by-stat -- close enough for judging trades by
 *     eye, and potential (shown for context) never feeds the value math
 *     here either, exactly like the real game.
 */

// ---------------------------------------------------------------------
// Constants ported from trade_value.dart -- re-synced 2026-08-23
// alongside that file's own re-tune (400/220/50 ladder, the
// potential/age-aware playerTradeValue formula below, and the two new
// wide-tolerance trade shapes -- this file had drifted out of sync with
// the real math since that retune, exactly the gap this README already
// warns about).
// ---------------------------------------------------------------------
const DRAFT_PICK_VALUE = [1 => 400, 2 => 220, 3 => 50];
const MIN_TRADE_SWING = 11;
const ASSUMED_MANAGEMENT = 70; // "assume I have a coach with 70 management"

// playerTradeValue's potential-upside/age-risk terms.
const REPLACEMENT_OVERALL = 60;
const FULL_WEIGHT_OVERALL = 75;
const UPSIDE_WEIGHT = 4;
const AGE_RISK_WEIGHT = 1.5;

// kSellForPicksExtraTolerance / kPickSpendExtraTolerance -- both 250 in
// the real game, same reasoning either direction: real picks and real
// players don't line up within an ordinary swing margin, so a
// desperation sale or a move-up-the-board buy both get a deliberately
// wider discount instead of being nearly unreachable.
const EXTRA_PICK_TOLERANCE = 250;

function trade_swing(int $management): int {
    $raw = (int) round(($management * $management) / 104);
    return max($raw, MIN_TRADE_SWING);
}

function age_risk_factor(int $age): float {
    if ($age <= 26) return 0.0;
    if ($age <= 27) return 0.1;
    if ($age <= 29) return 0.3;
    if ($age <= 32) return 0.6;
    return 1.0;
}

function quality_ramp(int $gate): float {
    if ($gate <= REPLACEMENT_OVERALL) return 0.0;
    if ($gate >= FULL_WEIGHT_OVERALL) return 1.0;
    return ($gate - REPLACEMENT_OVERALL) / (FULL_WEIGHT_OVERALL - REPLACEMENT_OVERALL);
}

/** Mirrors playerTradeValue() exactly -- skillPoints plus a real premium
 * for unrealized potential and a real discount for age-related decline
 * risk, both ramped to zero for anyone who isn't a real prospect or a
 * real current piece either way. */
function player_trade_value(int $overall, int $potential, int $skillPoints, int $age): int {
    $ramp = quality_ramp(max($overall, $potential));
    $upside = UPSIDE_WEIGHT * max(0, $potential - $overall) * $ramp;
    $ageRisk = AGE_RISK_WEIGHT * age_risk_factor($age) * $overall * $ramp;
    return (int) round($skillPoints + $upside - $ageRisk);
}

// ---------------------------------------------------------------------
// Synthetic player generation -- not the real game's generator, just
// realistic enough (position, overall, potential, age) to judge a trade
// package by eye.
// ---------------------------------------------------------------------
const POSITIONS = ['PG', 'SG', 'SF', 'PF', 'C'];

const FIRST_NAMES = [
    'Maya', 'Jordan', 'Alexis', 'Taylor', 'Morgan', 'Riley', 'Casey', 'Dana',
    'Sydney', 'Reese', 'Cameron', 'Avery', 'Skylar', 'Rowan', 'Quinn',
    'Harper', 'Emerson', 'Jamie', 'Peyton', 'Blake', 'Elliot', 'Kendall',
    'Devon', 'Ariel', 'Micah', 'Shay', 'Toni', 'Frankie', 'Robin', 'Sage',
];
const LAST_NAMES = [
    'Okafor', 'Nwosu', 'Rivera', 'Delgado', 'Kovac', 'Jankowski', 'Barron',
    'Reeves', 'Ellis', 'Marsh', 'Whitfield', 'Solano', 'Vance', 'Odom',
    'Castellanos', 'Pruitt', 'Vale', 'Sharma', 'Okonkwo', 'Larkin',
    'Beaumont', 'Isley', 'Marchetti', 'Nakamura', 'Hollis', 'Petrova',
    'Dubois', 'Kwan', 'Osei', 'Farrow',
];

function star_tier(int $overall): string {
    if ($overall >= 90) return '4-star';
    if ($overall >= 80) return '3-star';
    if ($overall >= 70) return '2-star';
    if ($overall >= 60) return '1-star';
    return 'no-star';
}

/** A roughly bell-shaped overall in [35,99], centered near 70 -- summing
 * a few uniform draws (an Irwin-Hall approximation) rather than a true
 * Box-Muller transform, plenty good enough here. */
function random_overall(): int {
    $sum = mt_rand(0, 100) + mt_rand(0, 100) + mt_rand(0, 100) + mt_rand(0, 100);
    $avg = $sum / 4; // roughly centered at 50, spread ~15-85
    $overall = (int) round(40 + $avg * 0.6); // recenter/rescale toward ~70
    return max(35, min(99, $overall));
}

function generate_player(): array {
    $overall = random_overall();
    $age = mt_rand(20, 34);
    if ($age <= 23) {
        $potential = min(99, $overall + mt_rand(5, 30));
    } else {
        $potential = min(99, $overall + mt_rand(0, 3));
    }
    // The real overall = round(skillPoints/12) -- any skillPoints within
    // ~5.5 either side of overall*12 rounds back to the same overall, so
    // this stays consistent with the displayed number.
    $skillPoints = $overall * 12 + mt_rand(-5, 6);

    return [
        'type' => 'player',
        'position' => POSITIONS[mt_rand(0, 4)],
        'name' => FIRST_NAMES[mt_rand(0, count(FIRST_NAMES) - 1)] . ' ' .
            LAST_NAMES[mt_rand(0, count(LAST_NAMES) - 1)],
        'overall' => $overall,
        'potential' => $potential,
        'age' => $age,
        'tier' => star_tier($overall),
        'value' => player_trade_value($overall, $potential, $skillPoints, $age),
    ];
}

function generate_pick(?int $round = null): array {
    $round = $round ?? mt_rand(1, 3);
    $season = 2027 + mt_rand(0, 1);
    return [
        'type' => 'pick',
        'round' => $round,
        'season' => $season,
        'value' => DRAFT_PICK_VALUE[$round],
    ];
}

function asset_value(array $asset): int {
    return $asset['value'];
}

function total_value(array $assets): int {
    $sum = 0;
    foreach ($assets as $a) {
        $sum += asset_value($a);
    }
    return $sum;
}

/** The 1- or 2-player combination from $pool whose combined value lands
 * closest to $target -- same brute-force approach _closestCombo uses in
 * the real generator. */
function closest_combo(array $pool, int $count, int $target): array {
    if ($count === 1) {
        $best = $pool[0];
        $bestDiff = abs($best['value'] - $target);
        foreach ($pool as $p) {
            $diff = abs($p['value'] - $target);
            if ($diff < $bestDiff) {
                $best = $p;
                $bestDiff = $diff;
            }
        }
        return [$best];
    }
    $best = null;
    $bestDiff = PHP_INT_MAX;
    $n = count($pool);
    for ($i = 0; $i < $n; $i++) {
        for ($j = $i + 1; $j < $n; $j++) {
            $sum = $pool[$i]['value'] + $pool[$j]['value'];
            $diff = abs($sum - $target);
            if ($diff < $bestDiff) {
                $bestDiff = $diff;
                $best = [$pool[$i], $pool[$j]];
            }
        }
    }
    return $best ?? [$pool[0], $pool[1]];
}

/** One trade attempt: 1-2 players you'd give up, matched against the
 * closest-value 1-2 players you'd get back, with a pick added to
 * whichever side is short if the raw player values alone don't land
 * within $swing -- same shape trade_offer_generator.dart's own
 * _tryBuildOffer uses. Returns null if nothing legal turns up within a
 * bounded number of tries, same as the real generator (a poorly-matched
 * pairing is a real, expected outcome, not a bug). */
function try_build_trade(int $swing): ?array {
    for ($attempt = 0; $attempt < 8; $attempt++) {
        $giveCount = (mt_rand(1, 100) <= 75) ? 1 : 2;
        $getCount = (mt_rand(1, 100) <= 75) ? 1 : 2;

        $yourRoster = [];
        for ($i = 0; $i < 12; $i++) $yourRoster[] = generate_player();
        $theirRoster = [];
        for ($i = 0; $i < 12; $i++) $theirRoster[] = generate_player();

        shuffle($yourRoster);
        $give = array_slice($yourRoster, 0, $giveCount);
        $giveValue = total_value($give);

        $get = closest_combo($theirRoster, $getCount, $giveValue);

        $gap = total_value($get) - $giveValue;
        if (abs($gap) > $swing) {
            // Sweeten whichever side is short with one pick, same
            // "one pick, whichever side needs it" simplification the
            // real generator uses.
            if ($gap < 0) {
                $pick = generate_pick();
                $get[] = $pick;
                $gap = total_value($get) - $giveValue;
            } else {
                $pick = generate_pick();
                $give[] = $pick;
                $giveValue = total_value($give);
                $gap = total_value($get) - $giveValue;
            }
        }

        if (abs($gap) <= $swing) {
            return [
                'give' => $give,
                'get' => $get,
                'give_value' => $giveValue,
                'get_value' => total_value($get),
                'swing' => $swing,
                'gap' => $gap,
                'forced_pick' => false,
                'shape' => 'ordinary',
            ];
        }
    }
    return null;
}

/** Mirrors trade_offer_generator.dart's _tryBuildGuaranteedTradeBlockPickOffer
 * + _forceAddPick: a real 2-for-2 that gets a pick thrown in *unconditionally*
 * (not just when the raw player values miss swing on their own) -- prefers
 * sweetening the "get" side first (the friendlier "they threw in a pick"
 * framing), falling back to the "give" side only if that doesn't land within
 * swing. In the real game this is the one guaranteed Trade Board slot
 * whenever a trade-block player is set; every other offer stays purely
 * opportunistic (try_build_trade above). This standalone tool has no trade
 * block, so generate_batch below just oversamples this bucket directly --
 * a deliberate choice (2026-08-23, a direct GM ask: "so many garbo trades
 * ... [with picks] ... that's where I see most of the egregious stuff") to
 * give more of exactly the shape worth scrutinizing, not an attempt to
 * match real in-game frequency. */
function try_build_forced_pick_trade(int $swing, ?int $forcedRound = null): ?array {
    for ($attempt = 0; $attempt < 12; $attempt++) {
        $round = $forcedRound ?? mt_rand(1, 3);
        $pickValue = DRAFT_PICK_VALUE[$round];
        $pick = generate_pick($round);

        $yourRoster = [];
        for ($i = 0; $i < 12; $i++) $yourRoster[] = generate_player();
        $theirRoster = [];
        for ($i = 0; $i < 12; $i++) $theirRoster[] = generate_player();

        shuffle($yourRoster);
        $give = array_slice($yourRoster, 0, 2);
        $giveValue = total_value($give);

        // Prefer sweetening "get" (their side) first -- deliberately
        // target their 2 players *short* by the pick's value, so the
        // pick is what actually closes a real gap. A 1st-round pick
        // (worth 290) almost never fits within a ~47-point swing bolted
        // onto an already-balanced trade -- has to be the reason the gap
        // existed in the first place.
        $get = closest_combo($theirRoster, 2, max(0, $giveValue - $pickValue));
        $getWithPick = array_merge($get, [$pick]);
        $gap = total_value($getWithPick) - $giveValue;
        if (abs($gap) <= $swing) {
            return [
                'give' => $give,
                'get' => $getWithPick,
                'give_value' => $giveValue,
                'get_value' => total_value($getWithPick),
                'swing' => $swing,
                'gap' => $gap,
                'forced_pick' => true,
                'shape' => 'forced_pick',
            ];
        }

        // Fall back to sweetening "give" (your side) instead -- target
        // their 2 players *ahead* by the pick's value this time.
        $get2 = closest_combo($theirRoster, 2, $giveValue + $pickValue);
        $giveWithPick = array_merge($give, [$pick]);
        $giveWithPickValue = total_value($giveWithPick);
        $gap = total_value($get2) - $giveWithPickValue;
        if (abs($gap) <= $swing) {
            return [
                'give' => $giveWithPick,
                'get' => $get2,
                'give_value' => $giveWithPickValue,
                'get_value' => total_value($get2),
                'swing' => $swing,
                'gap' => $gap,
                'forced_pick' => true,
                'shape' => 'forced_pick',
            ];
        }
    }
    return null;
}

/** Mirrors trade_offer_generator.dart's _trySellPlayerForPicks /
 * _tryBuildSellForPicksOffer: sell 1 of your own weaker players purely
 * for picks -- no player comes back at all -- widened by
 * EXTRA_PICK_TOLERANCE the same way the real "Gain Picks" toggle's flat
 * sell-off shape is. Tries your weakest few players first (real players
 * are worth more than even 2 real picks combined most of the time, so
 * this is the shape that actually needs the wide tolerance to be
 * reachable at all). A direct GM ask (2026-08-23, after seeing this
 * exact shape live in-game): "put some like those in the trade
 * evaluator." */
function try_build_sell_for_picks(int $swing): ?array {
    $tolerance = $swing + EXTRA_PICK_TOLERANCE;

    $yourRoster = [];
    for ($i = 0; $i < 12; $i++) $yourRoster[] = generate_player();
    usort($yourRoster, fn($a, $b) => $a['value'] <=> $b['value']);
    $candidates = array_slice($yourRoster, 0, 6);

    // The picks a real AI team might actually still hold -- 3 is plenty
    // to give the pair-of-picks fallback below something real to work
    // with, same "up to a small handful" scale the real generator's own
    // picksOwnedBy draws from in practice.
    $theirPicks = [generate_pick(), generate_pick(), generate_pick()];

    foreach ($candidates as $target) {
        $targetValue = $target['value'];

        $shuffled = $theirPicks;
        shuffle($shuffled);
        foreach ($shuffled as $pick) {
            if (abs($pick['value'] - $targetValue) <= $tolerance) {
                return [
                    'give' => [$target],
                    'get' => [$pick],
                    'give_value' => $targetValue,
                    'get_value' => $pick['value'],
                    'swing' => $swing,
                    'gap' => $pick['value'] - $targetValue,
                    'forced_pick' => true,
                    'shape' => 'sell_for_picks',
                ];
            }
        }

        $bestPair = null;
        $bestDiff = PHP_INT_MAX;
        for ($i = 0; $i < count($theirPicks); $i++) {
            for ($j = $i + 1; $j < count($theirPicks); $j++) {
                $sum = $theirPicks[$i]['value'] + $theirPicks[$j]['value'];
                $diff = abs($sum - $targetValue);
                if ($diff < $bestDiff) {
                    $bestDiff = $diff;
                    $bestPair = [$theirPicks[$i], $theirPicks[$j]];
                }
            }
        }
        if ($bestPair !== null && $bestDiff <= $tolerance) {
            $sum = $bestPair[0]['value'] + $bestPair[1]['value'];
            return [
                'give' => [$target],
                'get' => $bestPair,
                'give_value' => $targetValue,
                'get_value' => $sum,
                'swing' => $swing,
                'gap' => $sum - $targetValue,
                'forced_pick' => true,
                'shape' => 'sell_for_picks',
            ];
        }
    }
    return null;
}

/** Mirrors trade_offer_generator.dart's _tryBuildPickUpgradeOffer: spend
 * a worse pick you already own (plus maybe one of your own weaker
 * players) to move up to one specific real *better* pick -- the other
 * new "Gain Picks" shape, same EXTRA_PICK_TOLERANCE discount. Only ever
 * considers a wanted pick if you actually hold a worse-round one to
 * trade up from (trading a 2nd down to a 3rd would be backwards). */
function try_build_pick_upgrade(int $swing): ?array {
    $tolerance = $swing + EXTRA_PICK_TOLERANCE;

    $yourPicks = [generate_pick(), generate_pick()];
    $theirPicks = [generate_pick(), generate_pick()];
    shuffle($theirPicks);

    $roster = [];
    for ($i = 0; $i < 12; $i++) $roster[] = generate_player();
    usort($roster, fn($a, $b) => $a['value'] <=> $b['value']);
    $weakest = array_slice($roster, 0, 2);

    foreach ($theirPicks as $wanted) {
        $worseOwnPicks = array_values(array_filter(
            $yourPicks,
            fn($p) => $p['round'] > $wanted['round']
        ));
        if (empty($worseOwnPicks)) continue;

        $spendPool = array_merge($worseOwnPicks, $weakest);
        $wantedValue = $wanted['value'];

        $shuffled = $spendPool;
        shuffle($shuffled);
        foreach ($shuffled as $spend) {
            if (abs($spend['value'] - $wantedValue) <= $tolerance) {
                return [
                    'give' => [$spend],
                    'get' => [$wanted],
                    'give_value' => $spend['value'],
                    'get_value' => $wantedValue,
                    'swing' => $swing,
                    'gap' => $wantedValue - $spend['value'],
                    'forced_pick' => true,
                    'shape' => 'pick_upgrade',
                ];
            }
        }

        $bestPair = null;
        $bestDiff = PHP_INT_MAX;
        for ($i = 0; $i < count($spendPool); $i++) {
            for ($j = $i + 1; $j < count($spendPool); $j++) {
                $sum = $spendPool[$i]['value'] + $spendPool[$j]['value'];
                $diff = abs($sum - $wantedValue);
                if ($diff < $bestDiff) {
                    $bestDiff = $diff;
                    $bestPair = [$spendPool[$i], $spendPool[$j]];
                }
            }
        }
        if ($bestPair !== null && $bestDiff <= $tolerance) {
            $sum = $bestPair[0]['value'] + $bestPair[1]['value'];
            return [
                'give' => $bestPair,
                'get' => [$wanted],
                'give_value' => $sum,
                'get_value' => $wantedValue,
                'swing' => $swing,
                'gap' => $wantedValue - $sum,
                'forced_pick' => true,
                'shape' => 'pick_upgrade',
            ];
        }
    }
    return null;
}

function generate_batch(int $seed, int $count): array {
    mt_srand($seed);
    $swing = trade_swing(ASSUMED_MANAGEMENT);
    $trades = [];
    $guard = 0;

    // Guarantee a 1st-rounder and a 2nd-rounder actually show up -- with a
    // batch this small, leaving the round to chance (1-in-3 draw per pick)
    // risked never seeing one at all (a direct GM ask, 2026-08-23).
    foreach ([1, 2] as $forcedRound) {
        for ($tries = 0; $tries < 10; $tries++) {
            $trade = try_build_forced_pick_trade($swing, $forcedRound);
            if ($trade !== null) {
                $trades[] = $trade;
                break;
            }
        }
    }

    // Guarantee at least 1 of each new pick-heavy shape too -- both are
    // real, current Trade Board patterns (the "Gain Picks" toggle) that
    // postdate this tool's original 25-trade dataset, so they need their
    // own deliberate coverage the same way the forced-round guarantee
    // above already gets one (2026-08-23, a direct GM ask after seeing
    // these exact shapes live in-game: "put some like those in the
    // trade evaluator").
    foreach (['sell_for_picks', 'pick_upgrade'] as $shape) {
        for ($tries = 0; $tries < 10; $tries++) {
            $trade = $shape === 'sell_for_picks'
                ? try_build_sell_for_picks($swing)
                : try_build_pick_upgrade($swing);
            if ($trade !== null) {
                $trades[] = $trade;
                break;
            }
        }
    }

    // Oversample the guaranteed-pick 2-for-2 pattern beyond that -- about
    // a quarter of the batch, any round -- since picks are the shape
    // worth scrutinizing (see try_build_forced_pick_trade's doc comment).
    $forcedPickTarget = max(count($trades), (int) round($count / 4));
    while (count($trades) < $forcedPickTarget && $guard < $forcedPickTarget * 10) {
        $guard++;
        $trade = try_build_forced_pick_trade($swing);
        if ($trade !== null) {
            $trades[] = $trade;
        }
    }

    // Falls back to the ordinary opportunistic builder for the rest, same
    // "try, don't force it" posture the real generator uses.
    while (count($trades) < $count && $guard < $count * 10) {
        $guard++;
        $trade = try_build_trade($swing);
        if ($trade !== null) {
            $trades[] = $trade;
        }
    }
    shuffle($trades);
    return $trades;
}

// ---------------------------------------------------------------------
// Persistence -- every rated trade, forever, across every run.
// ---------------------------------------------------------------------
define('DATA_FILE', __DIR__ . '/ratings.json');

function load_ratings(): array {
    if (!file_exists(DATA_FILE)) return [];
    $raw = file_get_contents(DATA_FILE);
    if ($raw === false || trim($raw) === '') return [];
    $decoded = json_decode($raw, true);
    return is_array($decoded) ? $decoded : [];
}

function save_ratings(array $ratings): void {
    $fp = fopen(DATA_FILE, 'c+');
    if ($fp === false) return;
    flock($fp, LOCK_EX);
    ftruncate($fp, 0);
    rewind($fp);
    fwrite($fp, json_encode($ratings, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES));
    fflush($fp);
    flock($fp, LOCK_UN);
    fclose($fp);
}

function trade_has_pick(array $give, array $get): bool {
    foreach ($give as $a) if ($a['type'] === 'pick') return true;
    foreach ($get as $a) if ($a['type'] === 'pick') return true;
    return false;
}

/** Human label for a trade's `shape` -- `null` for 'ordinary'/'forced_pick'
 * (the PICK badge already covers those; nothing extra worth calling out). */
function shape_label(string $shape): ?string {
    return match ($shape) {
        'sell_for_picks' => 'SELL FOR PICKS',
        'pick_upgrade' => 'MOVE UP',
        default => null,
    };
}

function asset_label(array $a): string {
    if ($a['type'] === 'player') {
        // Last name only -- full "First Last" names read as more
        // real-roster-specific than this generic study warrants (a direct
        // GM ask, 2026-08-23).
        $nameParts = explode(' ', $a['name']);
        $lastName = end($nameParts);
        return $a['position'] . ' ' . $lastName . ' (' . $a['overall'] . ' OVR, '
            . $a['potential'] . ' POT, age ' . $a['age'] . ', ' . $a['tier'] . ')';
    }
    return $a['season'] . ' Round ' . $a['round'] . ' Pick';
}

// ---------------------------------------------------------------------
// Request handling
// ---------------------------------------------------------------------

// Never let a browser cache this page -- it's dynamic (new trades, new
// ratings) on every request, and a stale cached copy is exactly how a
// CSS change like the forced-dark-mode styling can silently fail to
// show up on a device even after the file on disk is already fixed.
header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
header('Pragma: no-cache');

$count = 5; // was 20 -- too many to rate in one sitting (a direct GM ask, 2026-08-23)
$viewMode = isset($_GET['view']);

// A stable seed per URL -- reloading the page shows the same batch;
// only an explicit "New Batch" (or a fresh visit) rolls a new one.
// Never applies to the saved-data view -- that page has nothing to do
// with any one batch's seed, and used to redirect straight past "view"
// entirely (a real bug caught testing this: the "View Saved Data" link
// always bounced back to a fresh rating batch instead).
if (!$viewMode && !isset($_GET['seed'])) {
    $seed = random_int(1, 1000000000);
    header('Location: ?seed=' . $seed);
    exit;
}
$seed = isset($_GET['seed']) ? (int) $_GET['seed'] : 0;

$flash = null;

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $trades = generate_batch($seed, $count);
    $ratings = load_ratings();
    $savedCount = 0;
    foreach ($trades as $i => $trade) {
        $ratingRaw = $_POST['rating_' . $i] ?? '';
        if ($ratingRaw === '' || $ratingRaw === 'skip') continue; // unrated -- not saved
        $rating = max(-5, min(5, (int) $ratingRaw));
        $notes = trim((string) ($_POST['notes_' . $i] ?? ''));
        $ratings[] = [
            'id' => bin2hex(random_bytes(8)),
            'timestamp' => date('Y-m-d H:i:s'),
            'seed' => $seed,
            'trade_index' => $i,
            'give' => $trade['give'],
            'get' => $trade['get'],
            'give_value' => $trade['give_value'],
            'get_value' => $trade['get_value'],
            'swing' => $trade['swing'],
            'gap' => $trade['gap'],
            'within_tolerance' => abs($trade['gap']) <= $trade['swing'],
            'forced_pick' => $trade['forced_pick'] ?? false,
            'shape' => $trade['shape'] ?? 'ordinary',
            'rating' => $rating,
            'notes' => $notes,
        ];
        $savedCount++;
    }
    save_ratings($ratings);
    $newSeed = random_int(1, 1000000000);
    header('Location: ?seed=' . $newSeed . '&saved=' . $savedCount);
    exit;
}

if (isset($_GET['saved'])) {
    $n = (int) $_GET['saved'];
    $flash = $n === 1 ? 'Saved 1 rating.' : "Saved $n ratings.";
}

$viewMode = isset($_GET['view']);
$trades = generate_batch($seed, $count);
$swing = trade_swing(ASSUMED_MANAGEMENT);

function h(string $s): string {
    return htmlspecialchars($s, ENT_QUOTES, 'UTF-8');
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>WBL Trade Value Study</title>
<style>
  :root {
    --bg: #1b1a17;
    --text: #ede8db;
    --muted: #a39c8a;
    --flash-bg: #1f3320;
    --flash-border: #3f6b41;
    --card-bg: #262420;
    --card-border: #45403a;
    --label: #c2bba9;
    --value-line: #a39c8a;
    --button-bg: #c99b2e;
    --button-bg-hover: #e0b13f;
    --button-text: #1b1a17;
    --th-bg: #33302a;
    --link: #e0b13f;
  }
  html { color-scheme: dark; }
  * { box-sizing: border-box; }
  body { font-family: -apple-system, Segoe UI, Roboto, sans-serif; font-size: 17px; max-width: 900px; margin: 0 auto; padding: 20px 14px 90px; background: var(--bg); color: var(--text); }
  h1 { font-size: 1.4rem; }
  a { color: var(--link); }
  .muted { color: var(--muted); font-size: 0.9rem; }
  .flash { background: var(--flash-bg); border: 1px solid var(--flash-border); padding: 10px 14px; border-radius: 8px; margin-bottom: 16px; }
  .top-nav { margin-bottom: 20px; }
  .top-nav a { margin-right: 16px; display: inline-block; padding: 4px 0; }
  .trade { border: 1px solid var(--card-border); border-radius: 10px; padding: 14px 16px; margin-bottom: 18px; background: var(--card-bg); }
  .trade h3 { margin: 0 0 8px; font-size: 1.05rem; }
  .pick-badge { display: inline-block; font-size: 0.7rem; font-weight: bold; letter-spacing: 0.03em; background: var(--button-bg); color: var(--button-text); border-radius: 4px; padding: 2px 6px; vertical-align: middle; }
  .shape-badge { background: var(--flash-border); color: var(--text); margin-left: 4px; }
  .sides { display: flex; gap: 16px; flex-wrap: wrap; }
  .side { flex: 1; min-width: 220px; }
  .side h4 { margin: 0 0 4px; font-size: 0.85rem; text-transform: uppercase; letter-spacing: 0.03em; color: var(--label); }
  .side ul { margin: 0; padding-left: 18px; }
  .value-line { font-size: 0.85rem; color: var(--value-line); margin-top: 8px; }
  .rate-row { margin-top: 14px; display: flex; flex-direction: column; gap: 10px; }
  .skip-toggle { display: flex; align-items: center; gap: 8px; font-size: 0.9rem; color: var(--muted); cursor: pointer; }
  .skip-toggle input[type=checkbox] { width: 20px; height: 20px; accent-color: var(--button-bg); }
  .slider-wrap { display: flex; align-items: center; gap: 12px; }
  input[type=range] { flex: 1; min-width: 0; height: 32px; accent-color: var(--button-bg); }
  .rating-out { font-weight: bold; min-width: 5em; text-align: right; }
  select, textarea { font-size: 1rem; padding: 8px; background: var(--card-bg); color: var(--text); border: 1px solid var(--card-border); border-radius: 4px; }
  textarea { width: 100%; margin-top: 8px; box-sizing: border-box; min-height: 44px; }
  .submit-bar { position: sticky; bottom: 0; background: var(--bg); padding: 14px 0; border-top: 1px solid var(--card-border); }
  button { font-size: 1.05rem; padding: 14px 18px; width: 100%; border-radius: 8px; border: none; background: var(--button-bg); color: var(--button-text); cursor: pointer; }
  button:hover { background: var(--button-bg-hover); }
  .table-wrap { overflow-x: auto; }
  table { border-collapse: collapse; width: 100%; margin-top: 12px; }
  th, td { border: 1px solid var(--card-border); padding: 6px 8px; font-size: 0.85rem; text-align: left; vertical-align: top; }
  th { background: var(--th-bg); }
  .stat-cards { display: flex; gap: 12px; flex-wrap: wrap; margin: 16px 0; }
  .stat-card { background: var(--card-bg); border: 1px solid var(--card-border); border-radius: 8px; padding: 10px 16px; }
  .stat-card .big { font-size: 1.4rem; font-weight: bold; }
</style>
</head>
<body>

<div class="top-nav">
  <a href="?">Rate Trades</a>
  <a href="?view=1">View Saved Data</a>
</div>

<?php if ($flash): ?>
  <div class="flash"><?= h($flash) ?></div>
<?php endif; ?>

<?php if ($viewMode): ?>

  <h1>Saved Trade Ratings</h1>
  <?php
    $all = load_ratings();
    $total = count($all);
    $avg = $total > 0 ? array_sum(array_column($all, 'rating')) / $total : 0;
    $within = array_filter($all, fn($r) => $r['within_tolerance']);
    $outside = array_filter($all, fn($r) => !$r['within_tolerance']);
    $avgWithin = count($within) > 0 ? array_sum(array_column($within, 'rating')) / count($within) : null;
    $avgOutside = count($outside) > 0 ? array_sum(array_column($outside, 'rating')) / count($outside) : null;
    $withPick = array_filter($all, fn($r) => trade_has_pick($r['give'], $r['get']));
    $withoutPick = array_filter($all, fn($r) => !trade_has_pick($r['give'], $r['get']));
    $avgWithPick = count($withPick) > 0 ? array_sum(array_map(fn($r) => abs($r['rating']), $withPick)) / count($withPick) : null;
    $avgWithoutPick = count($withoutPick) > 0 ? array_sum(array_map(fn($r) => abs($r['rating']), $withoutPick)) / count($withoutPick) : null;
    // The 2 new pick-heavy shapes (2026-08-23) -- a real, current Trade
    // Board pattern this dataset's original 25 trades predate entirely,
    // so a separate breakdown matters here specifically.
    $newShapes = array_filter($all, fn($r) => in_array($r['shape'] ?? 'ordinary', ['sell_for_picks', 'pick_upgrade'], true));
    $avgNewShapes = count($newShapes) > 0 ? array_sum(array_map(fn($r) => abs($r['rating']), $newShapes)) / count($newShapes) : null;
  ?>
  <div class="stat-cards">
    <div class="stat-card"><div class="big"><?= $total ?></div><div class="muted">rated trades</div></div>
    <div class="stat-card"><div class="big"><?= number_format($avg, 2) ?></div><div class="muted">avg rating (-5 = Team A wins big, +5 = Team B wins big)</div></div>
    <div class="stat-card"><div class="big"><?= $avgWithin === null ? '—' : number_format($avgWithin, 2) ?></div><div class="muted">avg rating, within engine tolerance (<?= count($within) ?>)</div></div>
    <div class="stat-card"><div class="big"><?= $avgOutside === null ? '—' : number_format($avgOutside, 2) ?></div><div class="muted">avg rating, outside engine tolerance (<?= count($outside) ?>)</div></div>
    <div class="stat-card"><div class="big"><?= $avgWithPick === null ? '—' : number_format($avgWithPick, 2) ?></div><div class="muted">avg |rating| for trades with a pick (<?= count($withPick) ?>)</div></div>
    <div class="stat-card"><div class="big"><?= $avgWithoutPick === null ? '—' : number_format($avgWithoutPick, 2) ?></div><div class="muted">avg |rating| for trades without one (<?= count($withoutPick) ?>)</div></div>
    <div class="stat-card"><div class="big"><?= $avgNewShapes === null ? '—' : number_format($avgNewShapes, 2) ?></div><div class="muted">avg |rating| for SELL FOR PICKS / MOVE UP trades (<?= count($newShapes) ?>)</div></div>
  </div>
  <p class="muted">"Within engine tolerance" means the trade math (Management <?= ASSUMED_MANAGEMENT ?>, swing ±<?= $swing ?>) would let this trade actually happen in-game. If those two averages read far apart from 0 in opposite directions, or the "outside tolerance" trades aren't reading much worse to you than the "within" ones, that's a sign the swing number itself may need retuning. The pick-vs-no-pick pair compares by <strong>magnitude</strong> (how lopsided, regardless of direction) -- if pick trades run consistently more lopsided, that's a sign the flat pick-value ladder (<?= DRAFT_PICK_VALUE[1] ?>/<?= DRAFT_PICK_VALUE[2] ?>/<?= DRAFT_PICK_VALUE[3] ?> by round) is coarser than it should be. SELL FOR PICKS/MOVE UP trades are <em>expected</em> to run more lopsided than ordinary ones -- they deliberately use a wider <?= EXTRA_PICK_TOLERANCE ?>-point discount tolerance on top of the normal swing -- so judge that number against "does a below-market desperation sale still feel fair," not against 0.</p>

  <?php if ($total === 0): ?>
    <p>No ratings saved yet -- <a href="?">go rate some trades</a>.</p>
  <?php else: ?>
    <div class="table-wrap">
    <table>
      <tr>
        <th>When</th>
        <th>Team A Sends</th>
        <th>Team B Sends</th>
        <th>Pick?</th>
        <th>Shape</th>
        <th>Value Gap</th>
        <th>In Tolerance?</th>
        <th>Rating</th>
        <th>Notes</th>
      </tr>
      <?php foreach (array_reverse($all) as $r): ?>
        <tr>
          <td><?= h($r['timestamp']) ?></td>
          <td><?php foreach ($r['give'] as $a) echo h(asset_label($a)) . '<br>'; ?></td>
          <td><?php foreach ($r['get'] as $a) echo h(asset_label($a)) . '<br>'; ?></td>
          <td><?= trade_has_pick($r['give'], $r['get']) ? 'Yes' : '' ?></td>
          <td><?= h(shape_label($r['shape'] ?? 'ordinary') ?? '') ?></td>
          <td><?= $r['gap'] >= 0 ? '+' : '' ?><?= $r['gap'] ?> (swing ±<?= $r['swing'] ?>)</td>
          <td><?= $r['within_tolerance'] ? 'Yes' : 'No' ?></td>
          <td><strong><?= $r['rating'] >= 0 ? '+' : '' ?><?= $r['rating'] ?></strong></td>
          <td><?= h($r['notes']) ?></td>
        </tr>
      <?php endforeach; ?>
    </table>
    </div>
  <?php endif; ?>

<?php else: ?>

  <h1>WBL Trade Value Study</h1>
  <p class="muted">
    <?= count($trades) ?> generated trades, coach Management <?= ASSUMED_MANAGEMENT ?>
    (swing tolerance ±<?= $swing ?> value points). Team A is the left side of each card,
    Team B the right. Slide left for <strong>Team A</strong> winning the trade, right for
    <strong>Team B</strong>, center for dead even -- every trade is assumed rated at
    whatever the slider shows unless you check "skip this one." This batch is
    deliberately oversampled toward draft picks (marked <span class="pick-badge">PICK</span>)
    since that's the shape most worth scrutinizing -- always at least one 1st-rounder and
    one 2nd-rounder, plus at least one real <span class="pick-badge shape-badge">SELL FOR PICKS</span>
    (a player, no return player, straight for picks) and one
    <span class="pick-badge shape-badge">MOVE UP</span> (spending a worse pick you own,
    maybe with a player thrown in, for one real better pick) -- the 2 shapes behind the
    "Gain Picks" Trade Board toggle. Reloading this page keeps the same batch; submitting
    rolls a brand new one.
  </p>

  <datalist id="ratingTicks">
    <?php for ($v = -5; $v <= 5; $v++): ?><option value="<?= $v ?>"></option><?php endfor; ?>
  </datalist>

  <form method="post" action="?seed=<?= $seed ?>">
    <?php foreach ($trades as $i => $trade): ?>
      <div class="trade">
        <h3>Trade <?= $i + 1 ?><?php if (trade_has_pick($trade['give'], $trade['get'])): ?> <span class="pick-badge">PICK</span><?php endif; ?><?php if ($label = shape_label($trade['shape'] ?? 'ordinary')): ?> <span class="pick-badge shape-badge"><?= h($label) ?></span><?php endif; ?></h3>
        <div class="sides">
          <div class="side">
            <h4>Team A Sends</h4>
            <ul>
              <?php foreach ($trade['give'] as $a): ?>
                <li><?= h(asset_label($a)) ?></li>
              <?php endforeach; ?>
            </ul>
          </div>
          <div class="side">
            <h4>Team B Sends</h4>
            <ul>
              <?php foreach ($trade['get'] as $a): ?>
                <li><?= h(asset_label($a)) ?></li>
              <?php endforeach; ?>
            </ul>
          </div>
        </div>
        <div class="value-line">
          Value: Team A sends <?= $trade['give_value'] ?>, Team B sends <?= $trade['get_value'] ?>
          (gap <?= $trade['gap'] >= 0 ? '+' : '' ?><?= $trade['gap'] ?>, swing ±<?= $trade['swing'] ?>)
        </div>
        <div class="rate-row">
          <div class="slider-wrap" id="wrap_<?= $i ?>">
            <input type="range" name="rating_<?= $i ?>" id="rating_<?= $i ?>"
                   min="-5" max="5" step="1" value="0" list="ratingTicks"
                   oninput="wblUpdateReadout(<?= $i ?>)">
            <span class="rating-out" id="out_<?= $i ?>">even</span>
          </div>
          <label class="skip-toggle">
            <input type="checkbox" onchange="wblToggleSkip(<?= $i ?>, this.checked)">
            Skip this one
          </label>
        </div>
        <textarea name="notes_<?= $i ?>" placeholder="Notes (optional) -- why this rating?"></textarea>
      </div>
    <?php endforeach; ?>

    <div class="submit-bar">
      <button type="submit">Save Ratings &amp; Get New Batch</button>
    </div>
  </form>

<?php endif; ?>

<script>
function wblToggleSkip(i, skipped) {
  var wrap = document.getElementById('wrap_' + i);
  var slider = document.getElementById('rating_' + i);
  wrap.hidden = skipped;
  slider.disabled = skipped;
}
function wblUpdateReadout(i) {
  var v = parseInt(document.getElementById('rating_' + i).value, 10);
  var out = document.getElementById('out_' + i);
  out.textContent = v === 0 ? 'even' : (v > 0 ? '+' + v + ' Team B' : v + ' Team A');
}
</script>

</body>
</html>
