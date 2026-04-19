/// Leave request model
class LeaveRequest {
  final String id;
  final String reason;
  final String? description;
  final String? evidenceUrl;
  final String status; // PENDING, APPROVED, REJECTED
  final String date;
  final String createdAt;
  final String? courseName;
  final String? courseCode;

  const LeaveRequest({
    required this.id,
    required this.reason,
    this.description,
    this.evidenceUrl,
    required this.status,
    required this.date,
    required this.createdAt,
    this.courseName,
    this.courseCode,
  });

  factory LeaveRequest.fromJson(Map<String, dynamic> json) {
    String? cName;
    String? cCode;
    if (json['course'] != null) {
      cName = json['course']['name'];
      cCode = json['course']['code'];
    }

    return LeaveRequest(
      id: json['id']?.toString() ?? '',
      reason: json['reason'] ?? '',
      description: json['description'],
      evidenceUrl: json['evidenceUrl'],
      status: json['status'] ?? 'PENDING',
      date: json['date'] ?? '',
      createdAt: json['createdAt'] ?? '',
      courseName: cName,
      courseCode: cCode,
    );
  }

  /// Human-readable reason label
  String get reasonLabel {
    switch (reason) {
      case 'sick': return 'Sakit';
      case 'family': return 'Urusan Keluarga';
      case 'academic': return 'Kegiatan Akademik';
      case 'emergency': return 'Musibah / Force Majeure';
      case 'other': return 'Lainnya';
      default: return reason;
    }
  }
}
