import '../services/app_time.dart';

/// Single attendance record for one meeting
class AttendanceRecord {
  final String date;
  final int meeting;
  final String status;

  const AttendanceRecord({
    required this.date,
    required this.meeting,
    required this.status,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      meeting: int.tryParse(json['meetingCount']?.toString() ?? '1') ?? 1,
      date: json['date'] ?? json['timestamp'] ?? AppTime.now().toIso8601String(),
      status: json['status'] ?? 'present',
    );
  }
}

/// Attendance records grouped by course
class CourseAttendance {
  final String subject;
  final String lecturer;
  final int totalMeetings;
  final List<AttendanceRecord> records;

  CourseAttendance({
    required this.subject,
    required this.lecturer,
    required this.totalMeetings,
    List<AttendanceRecord>? records,
  }) : records = records ?? [];

  int get presentCount => records.where((r) => r.status == 'present').length;
  int get absentCount => records.where((r) => r.status == 'absent').length;
  int get leaveCount => records.where((r) => r.status == 'leave').length;
  int get percentage => records.isEmpty ? 0 : (presentCount / records.length * 100).round();
}
