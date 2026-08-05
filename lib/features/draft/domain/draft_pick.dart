import 'draft_prospect.dart';

/// One selection in the draft: who picked, at what slot, and who they
/// took. [pickNumber] is the overall pick across the whole draft (1-based,
/// continuing across rounds), not reset each round.
class DraftPick {
  const DraftPick({
    required this.round,
    required this.pickNumber,
    required this.teamAbbreviation,
    required this.prospect,
  });

  final int round;
  final int pickNumber;
  final String teamAbbreviation;
  final DraftProspect prospect;
}
