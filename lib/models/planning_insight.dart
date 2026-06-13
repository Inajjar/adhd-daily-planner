import 'task_item.dart';

enum PriorityLevel { high, medium, low }

class PrioritizedTask {
  const PrioritizedTask({
    required this.title,
    required this.priority,
    required this.durationMinutes,
    required this.energy,
    required this.reason,
  });

  final String title;
  final PriorityLevel priority;
  final int durationMinutes;
  final TaskEnergy energy;
  final String reason;
}

class PlanningInsight {
  const PlanningInsight({required this.tasks, required this.suggestion});

  final List<PrioritizedTask> tasks;
  final String suggestion;
}

class OverwhelmRecommendation {
  const OverwhelmRecommendation({
    required this.task,
    required this.estimatedMinutes,
    required this.energy,
    required this.microStep,
    required this.explanation,
  });

  final TaskItem task;
  final int estimatedMinutes;
  final TaskEnergy energy;
  final String microStep;
  final String explanation;
}

class DailyPlanRecommendation {
  const DailyPlanRecommendation({
    required this.tasks,
    required this.hiddenCount,
    required this.why,
  });

  final List<TaskItem> tasks;
  final int hiddenCount;
  final String why;
}

class ReminderSuggestion {
  const ReminderSuggestion({
    required this.title,
    required this.message,
    required this.actionLabel,
  });

  final String title;
  final String message;
  final String actionLabel;
}

class RescheduleItem {
  const RescheduleItem({required this.task, required this.priorityReason});

  final TaskItem task;
  final String priorityReason;
}

class ReschedulePlan {
  const ReschedulePlan({required this.tomorrow, required this.droppedTasks});

  final List<RescheduleItem> tomorrow;
  final List<TaskItem> droppedTasks;
}
