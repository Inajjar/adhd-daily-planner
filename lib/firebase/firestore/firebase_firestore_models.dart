import '../../models/focus_session_item.dart';
import '../../models/routine_item.dart';
import '../../models/task_item.dart';

class FirebasePlannerSnapshot {
  const FirebasePlannerSnapshot({
    required this.onboardingComplete,
    required this.selectedIntent,
    required this.brainDumpText,
    required this.streak,
    required this.notificationTime,
    required this.notificationMode,
    required this.tasks,
    required this.routines,
    required this.focusSessions,
  });

  final bool onboardingComplete;
  final String selectedIntent;
  final String brainDumpText;
  final int streak;
  final String notificationTime;
  final String notificationMode;
  final List<TaskItem> tasks;
  final List<RoutineItem> routines;
  final List<FocusSessionItem> focusSessions;
}
