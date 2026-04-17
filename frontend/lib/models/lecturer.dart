/// Model data Dosen (Lecturer)
class Lecturer {
  final String id;
  final String lecturerId; // NIP
  final String name;
  final String email;
  final String? phone;
  final String department;
  final String faculty;
  final int courseCount;
  final int reviewedLeavesCount;

  const Lecturer({
    required this.id,
    required this.lecturerId,
    required this.name,
    required this.email,
    this.phone,
    required this.department,
    required this.faculty,
    this.courseCount = 0,
    this.reviewedLeavesCount = 0,
  });

  factory Lecturer.fromJson(Map<String, dynamic> json) {
    final count = json['_count'] as Map<String, dynamic>?;
    return Lecturer(
      id: json['id'] ?? '',
      lecturerId: json['lecturerId'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      department: json['department'] ?? '',
      faculty: json['faculty'] ?? '',
      courseCount: count?['courses'] ?? 0,
      reviewedLeavesCount: count?['reviewedLeaves'] ?? 0,
    );
  }
}
