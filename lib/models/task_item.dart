enum TaskEnergy { low, medium, high }

class TaskItem {
  TaskItem({
    required this.id,
    required this.title,
    required this.durationMinutes,
    DateTime? createdAt,
    this.completedAt,
    DateTime? scheduledDate,
    this.energy = TaskEnergy.medium,
    this.isCompleted = false,
    this.isFocus = false,
  }) : createdAt = createdAt ?? DateTime.now(),
       scheduledDate = scheduledDate ?? DateTime.now();

  final String id;
  final String title;
  final int durationMinutes;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime scheduledDate;
  final TaskEnergy energy;
  final bool isCompleted;
  final bool isFocus;

  TaskItem copyWith({
    String? id,
    String? title,
    int? durationMinutes,
    DateTime? createdAt,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    DateTime? scheduledDate,
    TaskEnergy? energy,
    bool? isCompleted,
    bool? isFocus,
  }) {
    return TaskItem(
      id: id ?? this.id,
      title: title ?? this.title,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      createdAt: createdAt ?? this.createdAt,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      scheduledDate: scheduledDate ?? this.scheduledDate,
      energy: energy ?? this.energy,
      isCompleted: isCompleted ?? this.isCompleted,
      isFocus: isFocus ?? this.isFocus,
    );
  }
}
