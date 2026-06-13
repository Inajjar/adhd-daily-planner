class FocusSessionItem {
  const FocusSessionItem({
    required this.id,
    required this.taskId,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
  });

  final String id;
  final String taskId;
  final DateTime startTime;
  final DateTime endTime;
  final int durationMinutes;
}
