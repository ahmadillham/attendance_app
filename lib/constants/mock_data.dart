import 'package:flutter/widgets.dart';

// Mock Data — mirrors the React Native theme.js data constants
// All data here is for UI demonstration; replace with API calls for production.

// ─── Campus Geolocation ──────────────────────────────────────────
class Campus {
  static const double latitude = -7.167311;
  static const double longitude = 111.892951;
  static const double allowedRadiusMeters = 200;
  static const String name = 'Universitas Nahdlatul Ulama Sunan Giri';
}

// ─── Student Model ───────────────────────────────────────────────
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
}

const mockStudent = Student(
  name: 'Ahmad Bahrudin Ilham',
  studentId: '241101052',
  department: 'Teknik Informatika',
  faculty: 'Fakultas Sains dan Teknologi',
  semester: 4,
  email: 'ahmadbhdilham@gmail.com',
  phone: '0812-2001-2661',
  avatarInitials: 'AB',
  attendanceSummary: AttendanceSummary(
    present: 98,
    absent: 0,
    leave: 0,
    total: 98,
  ),
);

// ─── Schedule Item ───────────────────────────────────────────────
class ScheduleItem {
  final String id;
  final String subject;
  final String time;
  final String room;
  final String lecturer;
  final String status;

  const ScheduleItem({
    required this.id,
    required this.subject,
    required this.time,
    required this.room,
    required this.lecturer,
    this.status = 'upcoming',
  });
}

// ─── Mock Weekly Schedule ────────────────────────────────────────
const Map<String, List<ScheduleItem>> mockWeeklySchedule = {
  'Senin': [
    ScheduleItem(id: 'w1', subject: 'Logika Matematika', time: '09:45 – 11:00', room: 'FST H3', lecturer: 'Dr. Mivan Ariful Fathoni, M.Si'),
    ScheduleItem(id: 'w2', subject: 'Analisis Dan Desain Perangkat Lunak', time: '11:30 – 14:00', room: 'FST H6', lecturer: 'Muhammad Jauhar Fikri, S.Kom., M.Kom'),
    ScheduleItem(id: 'w3', subject: 'Pemrograman Mikrokontroller', time: '14:00 – 15:30', room: 'FST H5', lecturer: 'Guruh Putro Digantoro, S.Kom., M.Kom'),
  ],
  'Selasa': [
    ScheduleItem(id: 'w4', subject: 'Pemrograman Berbasis Mobile', time: '10:00 – 11:30', room: 'FST H8', lecturer: 'Zakki Alawi, S.Kom., MM'),
    ScheduleItem(id: 'w5', subject: 'Interaksi Manusia & Komputer', time: '11:30 – 14:00', room: 'FST H6', lecturer: 'Dwi Issadari Hastuti, S.Pd., S.Kom., M.Kom'),
  ],
  'Rabu': [],
  'Kamis': [
    ScheduleItem(id: 'w6', subject: 'Internet Of Things', time: '08:30 – 10:00', room: 'FST H8', lecturer: 'Mula Agung Barata, S.ST., M.Kom'),
    ScheduleItem(id: 'w7', subject: 'Komputasi Paralel Dan Terdistribusi', time: '10:00 – 11:30', room: 'FST H8', lecturer: 'Afnil Efan Pajri, S.Kom., M.I.Kom'),
  ],
  'Jumat': [],
  'Sabtu': [],
};

// ─── Mock Tasks / Tugas ──────────────────────────────────────────
class TaskItem {
  final String id;
  final String subject;
  final String title;
  final String description;
  final String deadline;
  final String priority;
  final bool completed;

  const TaskItem({
    required this.id,
    required this.subject,
    required this.title,
    required this.description,
    required this.deadline,
    required this.priority,
    required this.completed,
  });
}

const List<TaskItem> mockTasks = [
  TaskItem(id: 't1', subject: 'Pemrograman Berbasis Mobile', title: 'Membuat Aplikasi To-Do List', description: 'Buat aplikasi To-Do List sederhana menggunakan React Native.', deadline: '2026-03-10', priority: 'high', completed: false),
  TaskItem(id: 't2', subject: 'Analisis Dan Desain Perangkat Lunak', title: 'Dokumen SRS', description: 'Membuat Software Requirements Specification untuk projek akhir.', deadline: '2026-03-08', priority: 'high', completed: false),
  TaskItem(id: 't3', subject: 'Internet Of Things', title: 'Rangkaian Sensor DHT11', description: 'Merangkai dan memprogram sensor DHT11 dengan Arduino untuk monitoring suhu.', deadline: '2026-03-15', priority: 'medium', completed: false),
  TaskItem(id: 't4', subject: 'Komputasi Paralel Dan Terdistribusi', title: 'Implementasi MPI', description: 'Implementasikan program paralel sederhana menggunakan MPI.', deadline: '2026-03-12', priority: 'medium', completed: false),
  TaskItem(id: 't5', subject: 'Logika Matematika', title: 'Latihan Soal Logika Proposisi', description: 'Kerjakan soal latihan bab logika proposisi dan predikat.', deadline: '2026-03-05', priority: 'high', completed: true),
  TaskItem(id: 't6', subject: 'Interaksi Manusia & Komputer', title: 'Desain Wireframe Aplikasi', description: 'Buat wireframe untuk aplikasi mobile menggunakan Figma.', deadline: '2026-03-06', priority: 'low', completed: true),
];

// ─── Attendance Record ───────────────────────────────────────────
class AttendanceRecord {
  final String date;
  final int meeting;
  final String status;

  const AttendanceRecord({
    required this.date,
    required this.meeting,
    required this.status,
  });
}

class CourseAttendance {
  final String subject;
  final String lecturer;
  final int totalMeetings;
  final List<AttendanceRecord> records;

  const CourseAttendance({
    required this.subject,
    required this.lecturer,
    required this.totalMeetings,
    required this.records,
  });
}

final List<CourseAttendance> mockAttendanceHistory = [
  CourseAttendance(
    subject: 'Logika Matematika',
    lecturer: 'Dr. Mivan Ariful Fathoni, M.Si',
    totalMeetings: 14,
    records: List.generate(14, (i) => AttendanceRecord(
      date: _generateDate(2026, 2, 2, i, 0), meeting: i + 1, status: 'present',
    )),
  ),
  CourseAttendance(
    subject: 'Analisis Dan Desain Perangkat Lunak',
    lecturer: 'Muhammad Jauhar Fikri, S.Kom., M.Kom',
    totalMeetings: 14,
    records: List.generate(14, (i) => AttendanceRecord(
      date: _generateDate(2026, 2, 2, i, 0), meeting: i + 1, status: 'present',
    )),
  ),
  CourseAttendance(
    subject: 'Pemrograman Mikrokontroller',
    lecturer: 'Guruh Putro Digantoro, S.Kom., M.Kom',
    totalMeetings: 14,
    records: List.generate(14, (i) => AttendanceRecord(
      date: _generateDate(2026, 2, 2, i, 0), meeting: i + 1, status: 'present',
    )),
  ),
  CourseAttendance(
    subject: 'Pemrograman Berbasis Mobile',
    lecturer: 'Zakki Alawi, S.Kom., MM',
    totalMeetings: 14,
    records: List.generate(14, (i) => AttendanceRecord(
      date: _generateDate(2026, 2, 3, i, 1), meeting: i + 1, status: 'present',
    )),
  ),
  CourseAttendance(
    subject: 'Interaksi Manusia & Komputer',
    lecturer: 'Dwi Issadari Hastuti, S.Pd., S.Kom., M.Kom',
    totalMeetings: 14,
    records: List.generate(14, (i) => AttendanceRecord(
      date: _generateDate(2026, 2, 3, i, 1), meeting: i + 1, status: 'present',
    )),
  ),
  CourseAttendance(
    subject: 'Internet Of Things',
    lecturer: 'Mula Agung Barata, S.ST., M.Kom',
    totalMeetings: 14,
    records: List.generate(14, (i) => AttendanceRecord(
      date: _generateDate(2026, 2, 5, i, 3), meeting: i + 1, status: 'present',
    )),
  ),
  CourseAttendance(
    subject: 'Komputasi Paralel Dan Terdistribusi',
    lecturer: 'Afnil Efan Pajri, S.Kom., M.I.Kom',
    totalMeetings: 14,
    records: List.generate(14, (i) => AttendanceRecord(
      date: _generateDate(2026, 2, 5, i, 3), meeting: i + 1, status: 'present',
    )),
  ),
];

String _generateDate(int year, int month, int day, int weekIndex, int dayOfWeek) {
  final base = DateTime(year, month, day);
  final date = base.add(Duration(days: weekIndex * 7));
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

// ─── Leave Reason Options ────────────────────────────────────────
class LeaveReason {
  final String label;
  final String value;
  final IconData icon;

  const LeaveReason({
    required this.label,
    required this.value,
    required this.icon,
  });
}
