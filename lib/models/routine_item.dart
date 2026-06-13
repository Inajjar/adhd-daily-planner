class RoutineItem {
  const RoutineItem({
    required this.id,
    required this.title,
    required this.tasks,
    required this.createdAt,
  });

  final String id;
  final String title;
  final List<String> tasks;
  final DateTime createdAt;

  RoutineItem copyWith({
    String? id,
    String? title,
    List<String>? tasks,
    DateTime? createdAt,
  }) {
    return RoutineItem(
      id: id ?? this.id,
      title: title ?? this.title,
      tasks: tasks ?? this.tasks,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
