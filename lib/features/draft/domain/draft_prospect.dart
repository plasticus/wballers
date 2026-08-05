import '../../player/domain/player.dart';
import 'college.dart';

/// A draft-eligible player paired with the fictional college they came
/// from. [college] is flavor/display only -- per `colleges.md`'s own
/// draft-pool guidelines, prestige affects which college a prospect gets
/// assigned to, never [player]'s ratings.
class DraftProspect {
  const DraftProspect({required this.player, required this.college});

  final Player player;
  final College college;
}
