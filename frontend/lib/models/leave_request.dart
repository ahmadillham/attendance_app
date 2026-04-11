/// Leave request model
class LeaveRequest {
  final String id;
  final String reason;
  final String? description;
  final String? evidenceUrl;
  final String status; // PENDING, APPROVED, REJECTED
  final String dateFrom;
  final String dateTo;
  final String createdAt;

  const LeaveRequest({
    required this.id,
    required this.reason,
    this.description,
    this.evidenceUrl,
    required this.status,
    required this.dateFrom,
    required this.dateTo,
    required this.createdAt,
  });

  factory LeaveRequest.fromJson(Map<String, dynamic> json) {
    return LeaveRequest(
      id: json['id']?.toString() ?? '',
      reason: json['reason'] ?? '',
      description: json['description'],
      evidenceUrl: json['evidenceUrl'],
      status: json['status'] ?? 'PENDING',
      dateFrom: json['dateFrom'] ?? '',
      dateTo: json['dateTo'] ?? '',
      createdAt: json['createdAt'] ?? '',
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
