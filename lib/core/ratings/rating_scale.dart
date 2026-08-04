/// Shared bounds for every coach and player numeric rating (see
/// `question.md` decision 16). 0 and 100 are deliberately excluded so a
/// rating is never "nothing" or "perfect."
const kMinRating = 1;
const kMaxRating = 99;

bool isValidRating(int value) => value >= kMinRating && value <= kMaxRating;
