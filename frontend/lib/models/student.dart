/// Student model with JSON deserialization
class Student {
  final String name;
  final String studentId;
  final String department;
  final String faculty;
  final int semester;
  final String email;
  final String phone;
  final String avatarInitials;
  final AttendanceSummary attendanceSummary;

  const Student({
    required this.name,
    required this.studentId,
    required this.department,
    required this.faculty,
    required this.semester,
    required this.email,
    required this.phone,
    required this.avatarInitials,
    required this.attendanceSummary,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    final summary = json['attendanceSummary'] ?? {};
    final name = json['name'] ?? '';
    return Student(
      name: name,
      studentId: json['studentId'] ?? '',
      department: json['department'] ?? '',
      faculty: json['faculty'] ?? '',
      semester: json['semester'] ?? 1,
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      avatarInitials: _getInitials(name),
      attendanceSummary: AttendanceSummary.fromJson(summary),
    );
  }

  static String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty && parts[0].isNotEmpty) return parts[0][0].toUpperCase();
    return '?';
  }
}

class AttendanceSummary {
  final int present;
  final int absent;
  final int leave;
  final int total;

  const AttendanceSummary({
    required this.present,
    required this.absent,
    required this.leave,
    required this.total,
  });

  factory AttendanceSummary.fromJson(Map<String, dynamic> json) {
    return AttendanceSummary(
      present: json['present'] ?? 0,
      absent: json['absent'] ?? 0,
      leave: json['leave'] ?? 0,
      total: json['total'] ?? 1,
    );
  }

  int get percentage => (present / total * 100).round();
}
