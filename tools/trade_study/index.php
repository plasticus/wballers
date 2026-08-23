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
// Constants ported from trade_value.dart
// ---------------------------------------------------------------------
const DRAFT_PICK_VALUE = [1 => 290, 2 => 150, 3 => 50];
const MIN_TRADE_SWING = 11;
const ASSUMED_MANAGEMENT = 70; // "assume I have a coach with 70 management"

function trade_swing(int $management): int {
    $raw = (int) round(($management * $management) / 104);
    return max($raw, MIN_TRADE_SWING);
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
        'value' => $skillPoints,
    ];
}

function generate_pick(): array {
    $round = mt_rand(1, 3);
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
    while (count($trades) < $count && $guard < $count * 10) {
        $guard++;
        $trade = try_build_trade($swing);
        if ($trade !== null) {
            $trades[] = $trade;
        }
    }
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

function asset_label(array $a): string {
    if ($a['type'] === 'player') {
        return $a['position'] . ' ' . $a['name'] . ' (' . $a['overall'] . ' OVR, '
            . $a['potential'] . ' POT, age ' . $a['age'] . ', ' . $a['tier'] . ')';
    }
    return $a['season'] . ' Round ' . $a['round'] . ' Pick';
}

// ---------------------------------------------------------------------
// Request handling
// ---------------------------------------------------------------------
$count = 20;
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
<title>WBL Trade Value Study</title>
<style>
  body { font-family: -apple-system, Segoe UI, Roboto, sans-serif; max-width: 900px; margin: 0 auto; padding: 24px 16px 80px; background: #fdf9f2; color: #1a1a2e; }
  h1 { font-size: 1.4rem; }
  .muted { color: #666; font-size: 0.9rem; }
  .flash { background: #dff5df; border: 1px solid #8fcf8f; padding: 10px 14px; border-radius: 8px; margin-bottom: 16px; }
  .top-nav { margin-bottom: 20px; }
  .top-nav a { margin-right: 16px; }
  .trade { border: 1px solid #ddd; border-radius: 10px; padding: 14px 16px; margin-bottom: 18px; background: #fff; }
  .trade h3 { margin: 0 0 8px; font-size: 1rem; }
  .sides { display: flex; gap: 16px; flex-wrap: wrap; }
  .side { flex: 1; min-width: 260px; }
  .side h4 { margin: 0 0 4px; font-size: 0.85rem; text-transform: uppercase; letter-spacing: 0.03em; color: #555; }
  .side ul { margin: 0; padding-left: 18px; }
  .value-line { font-size: 0.85rem; color: #777; margin-top: 8px; }
  .rate-row { margin-top: 12px; display: flex; align-items: center; gap: 10px; flex-wrap: wrap; }
  select, textarea { font-size: 0.95rem; padding: 4px 6px; }
  textarea { width: 100%; margin-top: 8px; box-sizing: border-box; min-height: 44px; }
  .submit-bar { position: sticky; bottom: 0; background: #fdf9f2; padding: 14px 0; border-top: 1px solid #ddd; }
  button { font-size: 1rem; padding: 10px 18px; border-radius: 8px; border: none; background: #6b5411; color: white; cursor: pointer; }
  button:hover { background: #55420d; }
  table { border-collapse: collapse; width: 100%; margin-top: 12px; }
  th, td { border: 1px solid #ddd; padding: 6px 8px; font-size: 0.85rem; text-align: left; vertical-align: top; }
  th { background: #f3ead9; }
  .stat-cards { display: flex; gap: 12px; flex-wrap: wrap; margin: 16px 0; }
  .stat-card { background: #fff; border: 1px solid #ddd; border-radius: 8px; padding: 10px 16px; }
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
  ?>
  <div class="stat-cards">
    <div class="stat-card"><div class="big"><?= $total ?></div><div class="muted">rated trades</div></div>
    <div class="stat-card"><div class="big"><?= number_format($avg, 2) ?></div><div class="muted">avg rating (-5 = you win big, +5 = they win big)</div></div>
    <div class="stat-card"><div class="big"><?= $avgWithin === null ? '—' : number_format($avgWithin, 2) ?></div><div class="muted">avg rating, within engine tolerance (<?= count($within) ?>)</div></div>
    <div class="stat-card"><div class="big"><?= $avgOutside === null ? '—' : number_format($avgOutside, 2) ?></div><div class="muted">avg rating, outside engine tolerance (<?= count($outside) ?>)</div></div>
  </div>
  <p class="muted">"Within engine tolerance" means the trade math (Management <?= ASSUMED_MANAGEMENT ?>, swing ±<?= $swing ?>) would let this trade actually happen in-game. If those two averages read far apart from 0 in opposite directions, or the "outside tolerance" trades aren't reading much worse to you than the "within" ones, that's a sign the swing number itself may need retuning.</p>

  <?php if ($total === 0): ?>
    <p>No ratings saved yet -- <a href="?">go rate some trades</a>.</p>
  <?php else: ?>
    <table>
      <tr>
        <th>When</th>
        <th>You Give</th>
        <th>You Get</th>
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
          <td><?= $r['gap'] >= 0 ? '+' : '' ?><?= $r['gap'] ?> (swing ±<?= $r['swing'] ?>)</td>
          <td><?= $r['within_tolerance'] ? 'Yes' : 'No' ?></td>
          <td><strong><?= $r['rating'] >= 0 ? '+' : '' ?><?= $r['rating'] ?></strong></td>
          <td><?= h($r['notes']) ?></td>
        </tr>
      <?php endforeach; ?>
    </table>
  <?php endif; ?>

<?php else: ?>

  <h1>WBL Trade Value Study</h1>
  <p class="muted">
    <?= count($trades) ?> generated trades, coach Management <?= ASSUMED_MANAGEMENT ?>
    (swing tolerance ±<?= $swing ?> value points). Rate each on how lopsided it feels --
    <strong>-5</strong> means your team wins big, <strong>0</strong> is dead even,
    <strong>+5</strong> means the other team wins big. Leave a trade set to "skip" to
    leave it out of what gets saved. Reloading this page keeps the same batch;
    submitting rolls a brand new one.
  </p>

  <form method="post" action="?seed=<?= $seed ?>">
    <?php foreach ($trades as $i => $trade): ?>
      <div class="trade">
        <h3>Trade <?= $i + 1 ?></h3>
        <div class="sides">
          <div class="side">
            <h4>You Give</h4>
            <ul>
              <?php foreach ($trade['give'] as $a): ?>
                <li><?= h(asset_label($a)) ?></li>
              <?php endforeach; ?>
            </ul>
          </div>
          <div class="side">
            <h4>You Get</h4>
            <ul>
              <?php foreach ($trade['get'] as $a): ?>
                <li><?= h(asset_label($a)) ?></li>
              <?php endforeach; ?>
            </ul>
          </div>
        </div>
        <div class="value-line">
          Value: you give <?= $trade['give_value'] ?>, you get <?= $trade['get_value'] ?>
          (gap <?= $trade['gap'] >= 0 ? '+' : '' ?><?= $trade['gap'] ?>, swing ±<?= $trade['swing'] ?>)
        </div>
        <div class="rate-row">
          <label for="rating_<?= $i ?>">Rating:</label>
          <select name="rating_<?= $i ?>" id="rating_<?= $i ?>">
            <option value="skip" selected>skip</option>
            <?php for ($v = -5; $v <= 5; $v++): ?>
              <option value="<?= $v ?>"><?= $v > 0 ? '+' . $v : $v ?></option>
            <?php endfor; ?>
          </select>
        </div>
        <textarea name="notes_<?= $i ?>" placeholder="Notes (optional) -- why this rating?"></textarea>
      </div>
    <?php endforeach; ?>

    <div class="submit-bar">
      <button type="submit">Save Ratings &amp; Get New Batch</button>
    </div>
  </form>

<?php endif; ?>

</body>
</html>
