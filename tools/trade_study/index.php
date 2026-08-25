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
const DRAFT_PICK_VALUE = [1 => 420, 2 => 130, 3 => 70]; // synced w/ trade_value.dart 2026-08-25 retune
const MIN_TRADE_SWING = 11;
const ASSUMED_MANAGEMENT = 70; // "assume I have a coach with 70 management"

// playerTradeValue's potential-upside/age-risk terms.
const REPLACEMENT_OVERALL = 60;
const FULL_WEIGHT_OVERALL = 75;
const UPSIDE_WEIGHT = 4;
const AGE_RISK_WEIGHT = 1.5;
// kTradeValueReplacementFloorFraction -- how much of raw skillPoints
// still counts below replacement quality. 0.1 -> 0.04 the same day,
// re-synced alongside that constant's own real-game update; see its doc
// comment in trade_value.dart for the full story/evidence.
const REPLACEMENT_FLOOR_FRACTION = 0.04;

// kTradeValueNoUpsideRunwayGap / kTradeValueEliteOverallStart /
// kTradeValueEliteOverallFull -- 2026-08-24, re-synced alongside that
// same-day real-game addition; see _tradeValueNoUpsideEscapeRamp's own
// doc comment in trade_value.dart for the full story/evidence.
const NO_UPSIDE_RUNWAY_GAP = 15;
const ELITE_OVERALL_START = 82; // synced w/ trade_value.dart 2026-08-24 evening retune
const ELITE_OVERALL_FULL = 90;

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

/** How much of quality_ramp()'s own skillPoints credit actually survives
 * -- the higher of "real runway left" (potential well above overall) or
 * "already unambiguously elite" (overall alone at/above
 * ELITE_OVERALL_FULL). A merely-good, already-capped veteran gets
 * neither escape hatch, on purpose -- see trade_value.dart's
 * _tradeValueNoUpsideEscapeRamp for the full story. */
function no_upside_escape_ramp(int $overall, int $potential): float {
    $gap = max(0, $potential - $overall);
    // Squared, not linear -- same day, re-synced; see
    // _tradeValueUpsideRunwayRamp's own doc comment in trade_value.dart.
    $runwayRatio = min(1.0, $gap / NO_UPSIDE_RUNWAY_GAP);
    $runway = $runwayRatio * $runwayRatio;
    if ($overall <= ELITE_OVERALL_START) {
        $elite = 0.0;
    } elseif ($overall >= ELITE_OVERALL_FULL) {
        $elite = 1.0;
    } else {
        $elite = ($overall - ELITE_OVERALL_START) / (ELITE_OVERALL_FULL - ELITE_OVERALL_START);
    }
    return max($runway, $elite);
}

/** Mirrors playerTradeValue() exactly -- skillPoints (discounted toward
 * REPLACEMENT_FLOOR_FRACTION below replacement quality, or without real
 * upside/elite status above it -- no_upside_escape_ramp()) plus a real
 * premium for unrealized potential and a real discount for age-related
 * decline risk, both ramped to zero for anyone who isn't a real
 * prospect or a real current piece either way. */
function player_trade_value(int $overall, int $potential, int $skillPoints, int $age): int {
    $ramp = quality_ramp(max($overall, $potential));
    $escapeRamp = no_upside_escape_ramp($overall, $potential);
    $skillPointsMultiplier = REPLACEMENT_FLOOR_FRACTION + (1 - REPLACEMENT_FLOOR_FRACTION) * $ramp * $escapeRamp;
    $upside = UPSIDE_WEIGHT * max(0, $potential - $overall) * $ramp;
    $ageRisk = AGE_RISK_WEIGHT * age_risk_factor($age) * $overall * $ramp;
    $raw = $skillPoints * $skillPointsMultiplier + $upside - $ageRisk;
    return (int) round(max(0, $raw));
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

/** Shared player-record builder -- every generator below (ordinary,
 * young prospect, star target) funnels through this so the
 * name/skillPoints/tier/value fields never drift out of sync between
 * them. `$overall`/`$potential`/`$age` are whatever the specific
 * generator already decided; skillPoints is derived the same
 * overall*12-plus-jitter way `generate_player`'s own comment explains. */
function make_player(int $overall, int $potential, int $age): array {
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

function generate_player(): array {
    $overall = random_overall();
    $age = mt_rand(20, 34);
    if ($age <= 23) {
        $potential = min(99, $overall + mt_rand(5, 30));
    } else {
        $potential = min(99, $overall + mt_rand(0, 3));
    }
    return make_player($overall, $potential, $age);
}

/** A real young riser -- age 19-23, overall 55-78, potential well
 * beyond it (+12 to +30). What try_build_going_big spends alongside
 * picks: "usually requires more draft picks or youngs w/ big
 * potential" (2026-08-24, a direct GM ask). */
function generate_young_prospect(): array {
    $overall = mt_rand(55, 78);
    $potential = min(99, $overall + mt_rand(12, 30));
    $age = mt_rand(19, 23);
    return make_player($overall, $potential, $age);
}

/** A real star-caliber target -- overall 88-99, what try_build_going_big
 * goes after. Mostly an established star (potential close to overall),
 * but under-90 sometimes rolls as a real riser instead -- "upper 80s
 * with age/potential to get [into] the 90s" (2026-08-24, same GM ask). */
function generate_star_player(): array {
    $overall = mt_rand(88, 99);
    $age = mt_rand(21, 33);
    $potential = ($overall < 90 && mt_rand(1, 100) <= 60)
        ? min(99, $overall + mt_rand(3, 9))
        : min(99, $overall + mt_rand(0, 3));
    return make_player($overall, $potential, $age);
}

/** What the *real* Dart draft generator's own pick 10/11 of round
 * $round actually looks like on average -- empirically measured (3000
 * simulated draft classes via generateDraftClass()/draftProspectValue(),
 * sorted, averaged at slots 10-11 within each round), not eyeballed.
 * The Value Check mode's own anchor question (2026-08-24, a direct GM
 * ask: "each round-pick should be worth what you'd get at around pick
 * 10/11 in a given round... i wonder if we also need another test.
 * like you tell me a player, i tell you what kind of pick/player
 * they're worth"). */
const PICK_ANCHOR_PROFILES = [
    1 => ['overall' => 74, 'potential' => 87, 'age' => 21],
    2 => ['overall' => 67, 'potential' => 81, 'age' => 21],
    3 => ['overall' => 63, 'potential' => 76, 'age' => 21],
];

/** [round]'s own anchor profile, jittered a little (+/-3 overall/
 * potential, +/-1 age) so asking about "round 1" more than once doesn't
 * always show the exact same player. */
function generate_pick_anchor_player(int $round): array {
    $base = PICK_ANCHOR_PROFILES[$round];
    $overall = max(35, min(99, $base['overall'] + mt_rand(-3, 3)));
    $potential = max($overall, min(99, $base['potential'] + mt_rand(-3, 3)));
    $age = max(19, min(23, $base['age'] + mt_rand(-1, 1)));
    return make_player($overall, $potential, $age);
}

/** Pick Check mode's fixed multiple-choice ladder (2026-08-24) -- a
 * direct GM ask, replacing "name a player for this pick" (Value Check's
 * pick-anchor question) with the reverse: "here's a pick or a pick
 * combo, which of these *fixed* players is closest?" ("it's hard for
 * me, with my human brain, to just type out a player that's worth a
 * particular pick... give me a multiple choice option (plus notes) to
 * choose the closest thing"). Deliberately the same profiles every
 * time (not jittered like PICK_ANCHOR_PROFILES) -- every answer across
 * every batch needs to be directly comparable against the same ladder,
 * not just internally consistent within one batch.
 *
 * 'strong_starter'/'borderline_star' added the same evening, right
 * after the first 2 real batches: the original 5-rung ladder's engine
 * values (28/72/117/436/1096) had two huge gaps -- 117->436 and
 * 436->1096 -- and real combo answers landed exactly in that dead
 * zone: "R1 + a 2nd" and "R2 + a 3rd" both got voted the *same* rung
 * as the bigger pick alone, which could genuinely mean "the smaller
 * pick added nothing," or could just be 2 answers rounding down to the
 * nearest rung because there was nothing in between to pick instead.
 * These 2 new rungs (~208, ~676) sit right in those gaps so the next
 * batches can actually tell the two apart. Existing saved answers keep
 * their original keys/labels -- this only affects future batches. */
const PICK_CHECK_COMPARISON_PROFILES = [
    'scrub' => ['label' => 'A scrub -- replacement level, no real upside', 'overall' => 58, 'potential' => 60, 'age' => 29],
    'rotation' => ['label' => 'A decent rotation piece', 'overall' => 70, 'potential' => 73, 'age' => 25],
    'starter' => ['label' => 'A quality starter', 'overall' => 78, 'potential' => 82, 'age' => 23],
    'strong_starter' => ['label' => 'A really good starter, close to more', 'overall' => 79, 'potential' => 85, 'age' => 22],
    'near_star' => ['label' => 'A near-star, or a real riser prospect', 'overall' => 85, 'potential' => 92, 'age' => 21],
    'borderline_star' => ['label' => 'A borderline star -- not quite elite yet', 'overall' => 87, 'potential' => 89, 'age' => 23],
    'star' => ['label' => 'A true star', 'overall' => 91, 'potential' => 92, 'age' => 25],
];

/** The 6 pick packages a Pick Check batch always asks about -- one bare
 * pick per round plus 3 blended combos, so both single-round values and
 * whether the current (plain-sum) combo math itself feels right can be
 * read from the same batch. Always this exact set (shuffled for display
 * order only) for the same "every answer is directly comparable" reason
 * PICK_CHECK_COMPARISON_PROFILES is fixed. */
const PICK_CHECK_COMBOS = [
    [1 => 1],
    [2 => 1],
    [3 => 1],
    [1 => 2],
    [1 => 1, 2 => 1],
    [2 => 1, 3 => 1],
];

function generate_pick_check_batch(int $seed): array {
    mt_srand($seed);
    $items = [];
    foreach (PICK_CHECK_COMBOS as $combo) {
        $picks = [];
        $season = 2027;
        foreach ($combo as $round => $count) {
            for ($n = 0; $n < $count; $n++) {
                $picks[] = ['type' => 'pick', 'round' => $round, 'season' => $season, 'value' => DRAFT_PICK_VALUE[$round]];
                $season++; // same-round picks still need distinct display seasons
            }
        }
        $items[] = ['picks' => $picks];
    }
    shuffle($items);
    return $items;
}

function pick_combo_label(array $picks): string {
    return implode(' + ', array_map('asset_label', $picks));
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

/** Mirrors trade_offer_generator.dart's _tryBuildPickForTalentOffer --
 * the Shed Picks toggle's own dedicated shape: spend only picks you own
 * (1, or the closest-value pair of 2) to buy back one real player,
 * aiming for the strongest one your picks can actually reach. The exact
 * reverse of try_build_sell_for_picks -- widened by the same
 * EXTRA_PICK_TOLERANCE. */
function try_build_pick_for_talent(int $swing): ?array {
    $tolerance = $swing + EXTRA_PICK_TOLERANCE;
    $yourPicks = [generate_pick(), generate_pick(), generate_pick()];

    $theirRoster = [];
    for ($i = 0; $i < 12; $i++) $theirRoster[] = generate_player();
    usort($theirRoster, fn($a, $b) => $b['value'] <=> $a['value']); // strongest first
    $candidates = array_slice($theirRoster, 0, 6);

    foreach ($candidates as $target) {
        $targetValue = $target['value'];

        $shuffled = $yourPicks;
        shuffle($shuffled);
        foreach ($shuffled as $pick) {
            if (abs($targetValue - $pick['value']) <= $tolerance) {
                return [
                    'give' => [$pick],
                    'get' => [$target],
                    'give_value' => $pick['value'],
                    'get_value' => $targetValue,
                    'swing' => $swing,
                    'gap' => $targetValue - $pick['value'],
                    'forced_pick' => true,
                    'shape' => 'pick_for_talent',
                ];
            }
        }

        $bestPair = null;
        $bestDiff = PHP_INT_MAX;
        for ($i = 0; $i < count($yourPicks); $i++) {
            for ($j = $i + 1; $j < count($yourPicks); $j++) {
                $sum = $yourPicks[$i]['value'] + $yourPicks[$j]['value'];
                $diff = abs($sum - $targetValue);
                if ($diff < $bestDiff) {
                    $bestDiff = $diff;
                    $bestPair = [$yourPicks[$i], $yourPicks[$j]];
                }
            }
        }
        if ($bestPair !== null && $bestDiff <= $tolerance) {
            $sum = $bestPair[0]['value'] + $bestPair[1]['value'];
            return [
                'give' => $bestPair,
                'get' => [$target],
                'give_value' => $sum,
                'get_value' => $targetValue,
                'swing' => $swing,
                'gap' => $targetValue - $sum,
                'forced_pick' => true,
                'shape' => 'pick_for_talent',
            ];
        }
    }
    return null;
}

/** Mirrors trade_offer_generator.dart's _tryBuildConsolidationOffer --
 * the Offload Depth toggle's own dedicated shape: your own weakest 2
 * active players (always the bottom of the roster, never a random 2)
 * for whichever 1 of their players lands closest in combined value.
 * Ordinary swing tolerance, with the same opportunistic one-pick
 * balancing every plain trade already gets -- no wide discount here,
 * unlike the pick-only shapes above. */
function try_build_consolidation(int $swing): ?array {
    $yourRoster = [];
    for ($i = 0; $i < 12; $i++) $yourRoster[] = generate_player();
    usort($yourRoster, fn($a, $b) => $a['value'] <=> $b['value']);
    $give = array_slice($yourRoster, 0, 2);
    $giveValue = total_value($give);

    $theirRoster = [];
    for ($i = 0; $i < 12; $i++) $theirRoster[] = generate_player();
    $get = closest_combo($theirRoster, 1, $giveValue);
    $gap = total_value($get) - $giveValue;

    if (abs($gap) > $swing) {
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
            'shape' => 'consolidation',
        ];
    }
    return null;
}

/** The Get Younger toggle's own shape isn't a distinct trade structure
 * in the real game -- it reuses the ordinary builder and just keeps
 * whichever real draws happen to send someone older than they receive
 * (`_sendsOlderThanItReceives`, a 4+ year average-age gap). Mirrors that
 * here: draw ordinary trades and keep the first one that clears the
 * same gap, rather than inventing a shape that doesn't exist. */
function try_build_get_younger(int $swing): ?array {
    for ($attempt = 0; $attempt < 30; $attempt++) {
        $trade = try_build_trade($swing);
        if ($trade === null) continue;
        $giveAges = array_map(fn($a) => $a['age'], array_filter($trade['give'], fn($a) => $a['type'] === 'player'));
        $getAges = array_map(fn($a) => $a['age'], array_filter($trade['get'], fn($a) => $a['type'] === 'player'));
        if (empty($giveAges) || empty($getAges)) continue;
        $giveAvg = array_sum($giveAges) / count($giveAges);
        $getAvg = array_sum($getAges) / count($getAges);
        if ($giveAvg - $getAvg >= 4) {
            $trade['shape'] = 'get_younger';
            return $trade;
        }
    }
    return null;
}

/** The $size-asset subset of $pool (distinct indices, brute-force -- pool
 * sizes used here are always small enough for that to stay cheap)
 * landing closest in combined value to $target. Empty if $pool is
 * smaller than $size. */
function closest_subset(array $pool, int $size, int $target): array {
    $n = count($pool);
    if ($size > $n) return [];
    $combos = [];
    $build = function (int $start, array $chosen) use (&$build, &$combos, $n, $size) {
        if (count($chosen) === $size) {
            $combos[] = $chosen;
            return;
        }
        for ($k = $start; $k < $n; $k++) {
            $build($k + 1, [...$chosen, $k]);
        }
    };
    $build(0, []);

    $best = [];
    $bestDiff = PHP_INT_MAX;
    foreach ($combos as $combo) {
        $assets = array_map(fn($idx) => $pool[$idx], $combo);
        $diff = abs(total_value($assets) - $target);
        if ($diff < $bestDiff) {
            $bestDiff = $diff;
            $best = $assets;
        }
    }
    return $best;
}

/** Not a real shipped Trade Board toggle (yet) -- a study-only category
 * a direct GM ask (2026-08-24) called for: "there should probably also
 * be a tag for like... going big, or big splash, where you try to go
 * after 90+ ovr players, or players who are upper 80s with age/potential
 * to get [into] the 90s. tough to do, usually requires more draft picks
 * or youngs w/ big potential." Targets one real [generate_star_player],
 * then hunts a real 2-or-3-asset package (real picks skewed toward
 * rounds 1-2, plus a real chance of one of [generate_young_prospect])
 * that lands within ordinary [swing] of her value -- same "closest real
 * combination, not an invented one" posture every other builder here
 * already uses. */
function try_build_going_big(int $swing): ?array {
    for ($attempt = 0; $attempt < 20; $attempt++) {
        $target = generate_star_player();
        $targetValue = $target['value'];

        $pool = [
            generate_pick(1), generate_pick(1),
            generate_pick(2), generate_pick(2),
            generate_pick(3),
            generate_young_prospect(), generate_young_prospect(),
        ];

        foreach ([2, 3] as $size) {
            $give = closest_subset($pool, $size, $targetValue);
            if (empty($give)) continue;
            $giveValue = total_value($give);
            $gap = $targetValue - $giveValue;
            if (abs($gap) <= $swing) {
                return [
                    'give' => $give,
                    'get' => [$target],
                    'give_value' => $giveValue,
                    'get_value' => $targetValue,
                    'swing' => $swing,
                    'gap' => $gap,
                    'forced_pick' => true,
                    'shape' => 'going_big',
                ];
            }
        }
    }
    return null;
}

function generate_batch(int $seed, int $count): array {
    mt_srand($seed);
    $swing = trade_swing(ASSUMED_MANAGEMENT);
    $trades = [];
    $guard = 0;

    // One trade per real Trade Board toggle, plus one study-only "Going
    // Big" slot -- exactly $count (6) slots (2026-08-24, direct GM asks:
    // "I want to see some that represent trying the different toggles
    // we added. tag them, too, with like 'gain picks' etc."; same day,
    // "there should probably also be a tag for like... going big").
    // Replaces the old "guarantee round 1 and round 2" scheme -- that
    // older goal (make sure *some* pick trade shows up) is now covered
    // more specifically by the Gain Picks/Shed Picks slots below, which
    // are picks-only trades by construction.
    //
    // Anything alternates between the plain opportunistic shape and the
    // guaranteed-pick 2-for-2 shape, same mix the real unfiltered board
    // actually has. Gain Picks alternates seed-to-seed between its own
    // 2 real shapes (sell_for_picks/pick_upgrade) rather than showing
    // both every batch -- see toggle_label()'s own doc comment for how
    // they're tagged the same either way.
    $builders = [
        fn() => mt_rand(0, 1) === 0
            ? try_build_trade($swing)
            : try_build_forced_pick_trade($swing),
        mt_rand(0, 1) === 0
            ? fn() => try_build_sell_for_picks($swing)
            : fn() => try_build_pick_upgrade($swing),
        fn() => try_build_pick_for_talent($swing),
        fn() => try_build_consolidation($swing),
        fn() => try_build_get_younger($swing),
        fn() => try_build_going_big($swing),
    ];
    foreach ($builders as $build) {
        for ($tries = 0; $tries < 15; $tries++) {
            $trade = $build();
            if ($trade !== null) {
                $trades[] = $trade;
                break;
            }
        }
    }

    // Tops up with the ordinary opportunistic builder if a slot above
    // never landed within its own tries (a real, expected outcome for a
    // poorly-matched draw, not a bug) or $count ever asks for more than
    // the 6 toggle slots.
    while (count($trades) < $count && $guard < $count * 20) {
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
// Value Check mode -- a direct reverse-elicitation test, the other real
// half of the same GM ask above: instead of judging an already-built
// trade, name a fair return for one real player, in your own words.
// Cleanest possible signal for exactly what should anchor
// kDraftPickTradeValue -- rating generated trades can only ever say
// "trade X feels wrong," never directly "pick 10/11 of round 2 is worth
// a Y."
// ---------------------------------------------------------------------

/** One Value Check batch: the 3 pick-anchor profiles (always, one per
 * round) plus 3 ordinary roster-quality profiles for broader
 * calibration -- 6 total, same batch size as the trade-rating mode.
 * Deterministic per $seed, same "reload keeps the batch, submit rolls a
 * new one" posture generate_batch() already has. */
function generate_value_check_batch(int $seed): array {
    mt_srand($seed);
    $items = [];
    foreach ([1, 2, 3] as $round) {
        $items[] = ['kind' => 'anchor', 'round' => $round, 'player' => generate_pick_anchor_player($round)];
    }
    for ($i = 0; $i < 3; $i++) {
        $items[] = ['kind' => 'ordinary', 'round' => null, 'player' => generate_player()];
    }
    shuffle($items);
    return $items;
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

define('VALUE_CHECK_DATA_FILE', __DIR__ . '/value_checks.json');

function load_value_checks(): array {
    if (!file_exists(VALUE_CHECK_DATA_FILE)) return [];
    $raw = file_get_contents(VALUE_CHECK_DATA_FILE);
    if ($raw === false || trim($raw) === '') return [];
    $decoded = json_decode($raw, true);
    return is_array($decoded) ? $decoded : [];
}

function save_value_checks(array $checks): void {
    $fp = fopen(VALUE_CHECK_DATA_FILE, 'c+');
    if ($fp === false) return;
    flock($fp, LOCK_EX);
    ftruncate($fp, 0);
    rewind($fp);
    fwrite($fp, json_encode($checks, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES));
    fflush($fp);
    flock($fp, LOCK_UN);
    fclose($fp);
}

define('PICK_CHECK_DATA_FILE', __DIR__ . '/pick_checks.json');

function load_pick_checks(): array {
    if (!file_exists(PICK_CHECK_DATA_FILE)) return [];
    $raw = file_get_contents(PICK_CHECK_DATA_FILE);
    if ($raw === false || trim($raw) === '') return [];
    $decoded = json_decode($raw, true);
    return is_array($decoded) ? $decoded : [];
}

function save_pick_checks(array $checks): void {
    $fp = fopen(PICK_CHECK_DATA_FILE, 'c+');
    if ($fp === false) return;
    flock($fp, LOCK_EX);
    ftruncate($fp, 0);
    rewind($fp);
    fwrite($fp, json_encode($checks, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES));
    fflush($fp);
    flock($fp, LOCK_UN);
    fclose($fp);
}

function trade_has_pick(array $give, array $get): bool {
    foreach ($give as $a) if ($a['type'] === 'pick') return true;
    foreach ($get as $a) if ($a['type'] === 'pick') return true;
    return false;
}

/** Every trade's real category, for tagging -- the exact real Trade
 * Board toggle it represents (`tradeBoardIntentLabel()` in
 * trade_offer.dart), plus the study-only "Going Big" category
 * (2026-08-24, a direct GM ask: "tag them, too, with like 'gain picks'
 * etc." -- then, same day, "there should probably also be a tag for
 * like... going big"). `sell_for_picks`/`pick_upgrade` both tag as
 * "Gain Picks" -- they're 2 real shapes behind the same one toggle, not
 * 2 different toggles, so they share the one tag on purpose. */
function toggle_label(string $shape): string {
    return match ($shape) {
        'sell_for_picks', 'pick_upgrade' => 'Gain Picks',
        'pick_for_talent' => 'Shed Picks',
        'consolidation' => 'Offload Depth',
        'get_younger' => 'Get Younger',
        'going_big' => 'Going Big',
        default => 'Anything', // 'ordinary', 'forced_pick'
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

// was 20 (a direct GM ask, 2026-08-23: "too many to rate in one
// sitting"), bumped from 5 to 6 the next day to fit the new dedicated
// Going Big slot alongside the 5 toggle slots (2026-08-24) -- one trade
// per real category, not an arbitrary round number.
$count = 6;
$viewMode = isset($_GET['view']);

// 'rate' (default, the original mode), 'value_check' (2026-08-24), or
// 'pick_check' (2026-08-24 evening) -- 3 genuinely separate tools
// sharing one page/nav/persistence pattern, not branches of one form.
$mode = in_array($_GET['mode'] ?? 'rate', ['value_check', 'pick_check'], true)
    ? $_GET['mode'] : 'rate';
function mode_url(string $mode, array $extra = []): string {
    $params = $mode !== 'rate' ? array_merge(['mode' => $mode], $extra) : $extra;
    return '?' . http_build_query($params);
}

// A stable seed per URL -- reloading the page shows the same batch;
// only an explicit "New Batch" (or a fresh visit) rolls a new one.
// Never applies to the saved-data view -- that page has nothing to do
// with any one batch's seed, and used to redirect straight past "view"
// entirely (a real bug caught testing this: the "View Saved Data" link
// always bounced back to a fresh rating batch instead).
if (!$viewMode && !isset($_GET['seed'])) {
    $seed = random_int(1, 1000000000);
    header('Location: ' . mode_url($mode, ['seed' => $seed]));
    exit;
}
$seed = isset($_GET['seed']) ? (int) $_GET['seed'] : 0;

$flash = null;

if ($_SERVER['REQUEST_METHOD'] === 'POST' && $mode === 'value_check') {
    $items = generate_value_check_batch($seed);
    $checks = load_value_checks();
    $savedCount = 0;
    foreach ($items as $i => $item) {
        $answer = trim((string) ($_POST['answer_' . $i] ?? ''));
        if ($answer === '') continue; // no answer given -- not saved
        $checks[] = [
            'id' => bin2hex(random_bytes(8)),
            'timestamp' => date('Y-m-d H:i:s'),
            'seed' => $seed,
            'item_index' => $i,
            'kind' => $item['kind'],
            'round' => $item['round'],
            'player' => $item['player'],
            'answer' => $answer,
        ];
        $savedCount++;
    }
    save_value_checks($checks);
    $newSeed = random_int(1, 1000000000);
    header('Location: ' . mode_url($mode, ['seed' => $newSeed, 'saved' => $savedCount]));
    exit;
}

if ($_SERVER['REQUEST_METHOD'] === 'POST' && $mode === 'pick_check') {
    $items = generate_pick_check_batch($seed);
    $checks = load_pick_checks();
    $savedCount = 0;
    foreach ($items as $i => $item) {
        $choice = (string) ($_POST['choice_' . $i] ?? '');
        $validChoices = array_merge(array_keys(PICK_CHECK_COMPARISON_PROFILES), ['nothing', 'more']);
        if (!in_array($choice, $validChoices, true)) {
            continue; // no choice made -- not saved (notes alone don't count)
        }
        $notes = trim((string) ($_POST['notes_' . $i] ?? ''));
        $checks[] = [
            'id' => bin2hex(random_bytes(8)),
            'timestamp' => date('Y-m-d H:i:s'),
            'seed' => $seed,
            'item_index' => $i,
            'picks' => $item['picks'],
            'choice' => $choice,
            'notes' => $notes,
        ];
        $savedCount++;
    }
    save_pick_checks($checks);
    $newSeed = random_int(1, 1000000000);
    header('Location: ' . mode_url($mode, ['seed' => $newSeed, 'saved' => $savedCount]));
    exit;
}

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
    $noun = $mode === 'rate' ? 'rating' : 'answer';
    $flash = $n === 1 ? "Saved 1 $noun." : "Saved $n {$noun}s.";
}

$viewMode = isset($_GET['view']);
$trades = $mode === 'rate' ? generate_batch($seed, $count) : [];
$valueCheckItems = $mode === 'value_check' ? generate_value_check_batch($seed) : [];
$pickCheckItems = $mode === 'pick_check' ? generate_pick_check_batch($seed) : [];
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
  .value-check-quickfill { display: flex; flex-wrap: wrap; gap: 8px; margin-top: 8px; }
  .pick-check-options { display: flex; flex-direction: column; gap: 10px; margin: 10px 0; }
  .pick-check-option { display: block; padding: 10px 12px; border: 1px solid var(--card-border); border-radius: 8px; background: var(--th-bg); }
  .pick-check-option input { margin-right: 8px; }
  .quickfill-btn { width: auto; font-size: 0.85rem; padding: 8px 12px; border-radius: 20px; background: var(--th-bg); color: var(--text); border: 1px solid var(--card-border); }
  .quickfill-btn:hover { background: var(--card-border); }
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
  <a href="<?= mode_url('value_check') ?>">Name Your Price</a>
  <a href="<?= mode_url('value_check', ['view' => 1]) ?>">View Saved Value Checks</a>
  <a href="<?= mode_url('pick_check') ?>">What's This Pick Worth</a>
  <a href="<?= mode_url('pick_check', ['view' => 1]) ?>">View Saved Pick Checks</a>
</div>

<?php if ($flash): ?>
  <div class="flash"><?= h($flash) ?></div>
<?php endif; ?>

<?php if ($mode === 'value_check'): ?>

<?php if ($viewMode): ?>

  <h1>Saved Value Checks</h1>
  <?php
    $allChecks = load_value_checks();
    $totalChecks = count($allChecks);
  ?>
  <p class="muted">Every player you've named a price for, newest first, alongside what
    <code>playerTradeValue()</code> currently computes for that exact profile -- read your
    own answer first, then compare.</p>

  <?php if ($totalChecks === 0): ?>
    <p>No value checks saved yet -- <a href="<?= mode_url('value_check') ?>">go name some prices</a>.</p>
  <?php else: ?>
    <div class="table-wrap">
    <table>
      <tr>
        <th>When</th>
        <th>Kind</th>
        <th>Player</th>
        <th>Current Engine Value</th>
        <th>Your Answer</th>
      </tr>
      <?php foreach (array_reverse($allChecks) as $c): ?>
        <?php $p = $c['player']; ?>
        <tr>
          <td><?= h($c['timestamp']) ?></td>
          <td><?= $c['kind'] === 'anchor' ? 'Pick ' . h((string) $c['round']) . ' anchor' : 'Ordinary' ?></td>
          <td><?= h(asset_label($p)) ?></td>
          <td><?= $p['value'] ?></td>
          <td><?= h($c['answer']) ?></td>
        </tr>
      <?php endforeach; ?>
    </table>
    </div>
  <?php endif; ?>

<?php else: ?>

  <h1>Name Your Price</h1>
  <p class="muted">
    For each player below, what would you actually take (or give) to trade for her --
    a pick, a player, a combo, whatever feels real? Type your own answer, or tap a quick
    fill to start from a common one. 3 of the 6 are anchored to a real measurement: what
    the actual Dart draft generator's pick 10/11 of round 1/2/3 looks like on average
    (not a round-wide average -- the specific middle-of-the-round slot). <strong>For
    those 3 specifically</strong>, answer in terms of an ordinary <em>player</em> (e.g.
    "about as good as a 72 OVR/72 POT bench piece"), not another pick -- "a 2nd + a
    sweetener" can't actually tell us what a 2nd is worth, since that's the very thing
    being measured (a real gap the first round of these caught). Skip any you're not
    sure about -- an empty answer isn't saved.
  </p>

  <form method="post" action="<?= mode_url('value_check', ['seed' => $seed]) ?>">
    <?php foreach ($valueCheckItems as $i => $item): ?>
      <?php $p = $item['player']; ?>
      <?php $isAnchor = $item['kind'] === 'anchor'; ?>
      <div class="trade">
        <h3>
          <?= h(asset_label($p)) ?>
          <?php if ($isAnchor): ?>
            <span class="pick-badge shape-badge">PICK <?= h((string) $item['round']) ?> ANCHOR</span>
          <?php endif; ?>
        </h3>
        <?php if ($isAnchor): ?>
          <p class="muted" style="margin: 4px 0 0;">Answer with a comparable <em>player</em>'s quality, not another pick (see the note above).</p>
        <?php endif; ?>
        <div class="value-check-quickfill">
          <?php
            $quickfills = $isAnchor
                ? ['Worth nothing much', 'A weak rotation player', 'A decent rotation player', 'A real starter', 'A similar player']
                : ['Nothing real', 'A 3rd', 'A 2nd', 'A 1st', 'Two 1sts', 'A similar player'];
          ?>
          <?php foreach ($quickfills as $quick): ?>
            <button type="button" class="quickfill-btn" onclick="wblQuickFill(<?= $i ?>, <?= h(json_encode($quick)) ?>)"><?= h($quick) ?></button>
          <?php endforeach; ?>
        </div>
        <textarea name="answer_<?= $i ?>" id="answer_<?= $i ?>" placeholder="<?= $isAnchor ? 'About how good a real player would she need to be?' : 'What would you take/give for her?' ?>"></textarea>
      </div>
    <?php endforeach; ?>

    <div class="submit-bar">
      <button type="submit">Save Answers &amp; Get New Batch</button>
    </div>
  </form>

<?php endif; ?>

<?php elseif ($mode === 'pick_check'): ?>

<?php if ($viewMode): ?>

  <h1>Saved Pick Checks</h1>
  <?php
    $allPickChecks = load_pick_checks();
    $totalPickChecks = count($allPickChecks);
    $pickChoiceLabel = function (string $choice): string {
        if ($choice === 'nothing') return 'Not much of anything real';
        if ($choice === 'more') return 'More than any of these';
        return PICK_CHECK_COMPARISON_PROFILES[$choice]['label'] ?? $choice;
    };
  ?>
  <p class="muted">Every pick (or pick combo) you've weighed in on, newest first, next to
    what you picked from the fixed ladder. The ladder itself never changes, so these are
    directly comparable across every batch you've ever answered.</p>

  <?php if ($totalPickChecks === 0): ?>
    <p>No pick checks saved yet -- <a href="<?= mode_url('pick_check') ?>">go weigh in on some</a>.</p>
  <?php else: ?>
    <div class="table-wrap">
    <table>
      <tr>
        <th>When</th>
        <th>Pick(s)</th>
        <th>Current Combined Engine Value</th>
        <th>Your Choice</th>
        <th>Notes</th>
      </tr>
      <?php foreach (array_reverse($allPickChecks) as $c): ?>
        <tr>
          <td><?= h($c['timestamp']) ?></td>
          <td><?= h(pick_combo_label($c['picks'])) ?></td>
          <td><?= array_sum(array_column($c['picks'], 'value')) ?></td>
          <td><?= h($pickChoiceLabel($c['choice'])) ?></td>
          <td><?= h($c['notes']) ?></td>
        </tr>
      <?php endforeach; ?>
    </table>
    </div>
  <?php endif; ?>

<?php else: ?>

  <h1>What's This Pick Worth</h1>
  <p class="muted">
    For each pick (or pick combo) below, which of the 5 fixed players would you actually
    take instead, straight up -- or give up to acquire it? Pick the closest one; add notes
    if you're between two, or want to say by how much. The same 5 profiles show up every
    time on purpose, so answers stay comparable across batches -- this is the flip side of
    Name Your Price's pick-anchor question (naming a player for a pick, instead of naming
    a pick for a player), for whenever a direct player comparison is easier to eyeball than
    to type from scratch.
  </p>

  <form method="post" action="<?= mode_url('pick_check', ['seed' => $seed]) ?>">
    <?php foreach ($pickCheckItems as $i => $item): ?>
      <div class="trade">
        <h3><?= h(pick_combo_label($item['picks'])) ?></h3>
        <div class="pick-check-options">
          <?php foreach (PICK_CHECK_COMPARISON_PROFILES as $key => $profile): ?>
            <label class="pick-check-option">
              <input type="radio" name="choice_<?= $i ?>" value="<?= h($key) ?>">
              <?= h($profile['label']) ?> (<?= $profile['overall'] ?> OVR / <?= $profile['potential'] ?> POT / age <?= $profile['age'] ?>)
            </label>
          <?php endforeach; ?>
          <label class="pick-check-option">
            <input type="radio" name="choice_<?= $i ?>" value="nothing">
            Not much of anything real
          </label>
          <label class="pick-check-option">
            <input type="radio" name="choice_<?= $i ?>" value="more">
            More than any of these
          </label>
        </div>
        <textarea name="notes_<?= $i ?>" id="notes_<?= $i ?>" placeholder="Notes -- e.g. 'between rotation and starter' or 'about 2 of these'"></textarea>
      </div>
    <?php endforeach; ?>

    <div class="submit-bar">
      <button type="submit">Save Answers &amp; Get New Batch</button>
    </div>
  </form>

<?php endif; ?>

<?php else: ?>

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
    // Per-toggle breakdown (2026-08-24) -- Gain Picks/Shed Picks/Offload
    // Depth/Get Younger/Going Big are all real, current Trade Board
    // categories (Going Big study-only for now) this dataset's original
    // 25 trades predate entirely, so a separate |rating| average per
    // toggle matters here specifically.
    $byToggle = [];
    foreach (['Anything', 'Gain Picks', 'Shed Picks', 'Offload Depth', 'Get Younger', 'Going Big'] as $toggle) {
        $rows = array_filter($all, fn($r) => toggle_label($r['shape'] ?? 'ordinary') === $toggle);
        $byToggle[$toggle] = [
            'count' => count($rows),
            'avg' => count($rows) > 0 ? array_sum(array_map(fn($r) => abs($r['rating']), $rows)) / count($rows) : null,
        ];
    }
  ?>
  <div class="stat-cards">
    <div class="stat-card"><div class="big"><?= $total ?></div><div class="muted">rated trades</div></div>
    <div class="stat-card"><div class="big"><?= number_format($avg, 2) ?></div><div class="muted">avg rating (-5 = Team A wins big, +5 = Team B wins big)</div></div>
    <div class="stat-card"><div class="big"><?= $avgWithin === null ? '—' : number_format($avgWithin, 2) ?></div><div class="muted">avg rating, within engine tolerance (<?= count($within) ?>)</div></div>
    <div class="stat-card"><div class="big"><?= $avgOutside === null ? '—' : number_format($avgOutside, 2) ?></div><div class="muted">avg rating, outside engine tolerance (<?= count($outside) ?>)</div></div>
    <div class="stat-card"><div class="big"><?= $avgWithPick === null ? '—' : number_format($avgWithPick, 2) ?></div><div class="muted">avg |rating| for trades with a pick (<?= count($withPick) ?>)</div></div>
    <div class="stat-card"><div class="big"><?= $avgWithoutPick === null ? '—' : number_format($avgWithoutPick, 2) ?></div><div class="muted">avg |rating| for trades without one (<?= count($withoutPick) ?>)</div></div>
    <?php foreach ($byToggle as $toggle => $stat): ?>
      <div class="stat-card"><div class="big"><?= $stat['avg'] === null ? '—' : number_format($stat['avg'], 2) ?></div><div class="muted">avg |rating|, <?= h($toggle) ?> (<?= $stat['count'] ?>)</div></div>
    <?php endforeach; ?>
  </div>
  <p class="muted">"Within engine tolerance" means the trade math (Management <?= ASSUMED_MANAGEMENT ?>, swing ±<?= $swing ?>) would let this trade actually happen in-game. If those two averages read far apart from 0 in opposite directions, or the "outside tolerance" trades aren't reading much worse to you than the "within" ones, that's a sign the swing number itself may need retuning. The pick-vs-no-pick pair compares by <strong>magnitude</strong> (how lopsided, regardless of direction) -- if pick trades run consistently more lopsided, that's a sign the flat pick-value ladder (<?= DRAFT_PICK_VALUE[1] ?>/<?= DRAFT_PICK_VALUE[2] ?>/<?= DRAFT_PICK_VALUE[3] ?> by round) is coarser than it should be. Gain Picks/Shed Picks trades are <em>expected</em> to run more lopsided than ordinary ones -- they deliberately use a wider <?= EXTRA_PICK_TOLERANCE ?>-point discount tolerance on top of the normal swing -- so judge that number against "does a below-market desperation sale still feel fair," not against 0. Offload Depth/Get Younger both stay on the ordinary swing tolerance, same as Anything -- no built-in discount either direction. Going Big is study-only (not a real toggle yet, and not discounted either) -- its own number is really asking "does the real cost of landing a real star feel about right."</p>

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
          <td><?= h(toggle_label($r['shape'] ?? 'ordinary')) ?></td>
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
    whatever the slider shows unless you check "skip this one." Every trade is tagged
    with which real Trade Board toggle it represents (<span class="pick-badge shape-badge">ANYTHING</span>,
    <span class="pick-badge shape-badge">GAIN PICKS</span>,
    <span class="pick-badge shape-badge">SHED PICKS</span>,
    <span class="pick-badge shape-badge">OFFLOAD DEPTH</span>,
    <span class="pick-badge shape-badge">GET YOUNGER</span>) -- one trade per toggle,
    guaranteed, every batch -- plus one <span class="pick-badge shape-badge">GOING BIG</span>
    trade, a study-only category (not a real toggle yet): a real package of picks and/or a
    young high-potential prospect, chasing one real 88+ overall star. Reloading this page
    keeps the same batch; submitting rolls a brand new one.
  </p>

  <datalist id="ratingTicks">
    <?php for ($v = -5; $v <= 5; $v++): ?><option value="<?= $v ?>"></option><?php endfor; ?>
  </datalist>

  <form method="post" action="?seed=<?= $seed ?>">
    <?php foreach ($trades as $i => $trade): ?>
      <div class="trade">
        <h3>Trade <?= $i + 1 ?> <span class="pick-badge shape-badge"><?= h(strtoupper(toggle_label($trade['shape'] ?? 'ordinary'))) ?></span><?php if (trade_has_pick($trade['give'], $trade['get'])): ?> <span class="pick-badge">PICK</span><?php endif; ?></h3>
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
function wblQuickFill(i, text) {
  document.getElementById('answer_' + i).value = text;
}
</script>

</body>
</html>
