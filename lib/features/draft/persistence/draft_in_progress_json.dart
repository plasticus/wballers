import '../domain/draft_in_progress.dart';
import 'draft_pick_json.dart';

Map<String, dynamic> draftInProgressToJson(DraftInProgress draft) {
  return {
    'order': draft.order,
    'rounds': draft.rounds,
    'picks': draft.picks.map(draftPickToJson).toList(),
  };
}

DraftInProgress draftInProgressFromJson(Map<String, dynamic> json) {
  return DraftInProgress(
    order: (json['order'] as List<dynamic>)
        .map((value) => value as String)
        .toList(),
    rounds: json['rounds'] as int,
    picks: (json['picks'] as List<dynamic>)
        .map((value) => draftPickFromJson(value as Map<String, dynamic>))
        .toList(),
  );
}
