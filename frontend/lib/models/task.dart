/// Task model with JSON deserialization
class TaskItem {
  final String id;
  final String title;
  final String description;
  final String deadline;
  final String priority;
  final bool completed;
  final String? subject; // optional — for display only

  const TaskItem({
    required this.id,
    required this.title,
    required this.description,
    required this.deadline,
    required this.priority,
    required this.completed,
    this.subject,
  });

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    return TaskItem(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      deadline: json['deadline'] ?? '',
      priority: json['priority'] ?? 'medium',
      completed: json['completed'] ?? false,
      subject: json['subject'],
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'deadline': deadline,
    'priority': priority,
    'completed': completed,
  };

  /// Check if task is overdue
  bool get isOverdue {
    try {
      return !completed && DateTime.parse(deadline).isBefore(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  /// Days remaining until deadline (negative = overdue)
  int get daysRemaining {
    try {
      return DateTime.parse(deadline).difference(DateTime.now()).inDays;
    } catch (_) {
      return 0;
    }
  }
}
