/// Schedule item model
class ScheduleItem {
  final String id;
  final String subject;
  final String time;
  final String room;
  final String lecturer;
  final String status;
  final String? courseId;
  final bool hasLeaveRequest;

  const ScheduleItem({
    required this.id,
    required this.subject,
    required this.time,
    required this.room,
    required this.lecturer,
    this.status = 'upcoming',
    this.courseId,
    this.hasLeaveRequest = false,
  });

  factory ScheduleItem.fromJson(Map<String, dynamic> json) {
    final course = json['course'] ?? {};
    return ScheduleItem(
      id: json['id']?.toString() ?? '',
      subject: course['name'] ?? json['subject'] ?? 'Unknown',
      time: '${json['startTime'] ?? '??:??'} – ${json['endTime'] ?? '??:??'}',
      room: json['room'] ?? 'Unknown',
      lecturer: (course['lecturer'] is Map)
          ? (course['lecturer']['name'] ?? 'Unknown')
          : (course['lecturer'] ?? json['lecturer'] ?? 'Unknown'),
      status: json['hasAttended'] == true ? 'attended' : 'upcoming',
      courseId: json['courseId']?.toString() ?? course['id']?.toString(),
      hasLeaveRequest: json['hasLeaveRequest'] == true,
    );
  }
}
