import '../models/models.dart';

// Re-export models so existing imports from mock_data.dart still work
export '../models/models.dart';

// Mock Data — mirrors the campus database seed data
// All data here is for UI demonstration; replace with API calls for production.

// ─── Campus Geolocation ──────────────────────────────────────────
class Campus {
  static const double latitude = -7.160460;
  static const double longitude = 111.853767;
  static const double allowedRadiusMeters = 200;
  static const String name = 'Universitas Nahdlatul Ulama Sunan Giri';
}

// ─── Mock Student Instance ───────────────────────────────────────
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
    present: 61,
    absent: 9,
    leave: 0,
    total: 70,
  ),
);

// ─── Mock Weekly Schedule ────────────────────────────────────────
const Map<String, List<ScheduleItem>> mockWeeklySchedule = {
  'Senin': [
    ScheduleItem(id: 'w1', subject: 'Logika Matematika', time: '09:45 – 11:00', room: 'FST H3', lecturer: 'Dr. Mivan Ariful Fathoni, M.Si', courseId: 'cl_logmat'),
    ScheduleItem(id: 'w2', subject: 'Analisis Dan Desain Perangkat Lunak', time: '11:30 – 14:00', room: 'FST H6', lecturer: 'Muhammad Jauhar Fikri, S.Kom., M.Kom', courseId: 'cl_adpl'),
    ScheduleItem(id: 'w3', subject: 'Pemrograman Mikrokontroller', time: '14:00 – 15:30', room: 'FST H5', lecturer: 'Guruh Putro Digantoro, S.Kom., M.Kom', courseId: 'cl_mikrokontroller'),
  ],
  'Selasa': [
    ScheduleItem(id: 'w4', subject: 'Pemrograman Berbasis Mobile', time: '10:00 – 11:30', room: 'FST H8', lecturer: 'Zakki Alawi, S.Kom., MM', courseId: 'cl_mobile'),
    ScheduleItem(id: 'w5', subject: 'Interaksi Manusia & Komputer', time: '11:30 – 14:00', room: 'FST H6', lecturer: 'Dwi Issadari Hastuti, S.Pd., S.Kom., M.Kom', courseId: 'cl_imk'),
  ],
  'Rabu': [],
  'Kamis': [
    ScheduleItem(id: 'w6', subject: 'Internet Of Things', time: '08:30 – 10:00', room: 'FST H8', lecturer: 'Mula Agung Barata, S.ST., M.Kom', courseId: 'cl_iot'),
    ScheduleItem(id: 'w7', subject: 'Komputasi Paralel Dan Terdistribusi', time: '10:00 – 11:30', room: 'FST H8', lecturer: 'Afnil Efan Pajri, S.Kom., M.I.Kom', courseId: 'cl_komparsis'),
  ],
  'Jumat': [],
  'Sabtu': [],
};

// ─── Mock Attendance History ─────────────────────────────────────
// Tanggal dimulai dari Senin 2 Februari 2026, setiap mata kuliah
// mengikuti hari jadwalnya dan berlangsung selama 10 pertemuan.
final List<CourseAttendance> mockAttendanceHistory = [
  // Senin - Logika Matematika (mulai 2 Feb 2026, Senin)
  CourseAttendance(
    subject: 'Logika Matematika',
    lecturer: 'Dr. Mivan Ariful Fathoni, M.Si',
    totalMeetings: 10,
    records: List.generate(10, (i) => AttendanceRecord(
      date: _generateDate(2026, 2, 2, i), meeting: i + 1, status: 'present',
    )),
  ),
  // Senin - ADPL (mulai 2 Feb 2026, Senin)
  CourseAttendance(
    subject: 'Analisis Dan Desain Perangkat Lunak',
    lecturer: 'Muhammad Jauhar Fikri, S.Kom., M.Kom',
    totalMeetings: 10,
    records: List.generate(10, (i) => AttendanceRecord(
      date: _generateDate(2026, 2, 2, i), meeting: i + 1, status: 'present',
    )),
  ),
  // Senin - Pemrograman Mikrokontroller (mulai 2 Feb 2026, Senin)
  CourseAttendance(
    subject: 'Pemrograman Mikrokontroller',
    lecturer: 'Guruh Putro Digantoro, S.Kom., M.Kom',
    totalMeetings: 10,
    records: List.generate(10, (i) => AttendanceRecord(
      date: _generateDate(2026, 2, 2, i), meeting: i + 1, status: 'present',
    )),
  ),
  // Selasa - Pemrograman Berbasis Mobile (mulai 3 Feb 2026, Selasa)
  CourseAttendance(
    subject: 'Pemrograman Berbasis Mobile',
    lecturer: 'Zakki Alawi, S.Kom., MM',
    totalMeetings: 10,
    records: List.generate(10, (i) => AttendanceRecord(
      date: _generateDate(2026, 2, 3, i), meeting: i + 1, status: 'present',
    )),
  ),
  // Selasa - IMK (mulai 3 Feb 2026, Selasa)
  CourseAttendance(
    subject: 'Interaksi Manusia & Komputer',
    lecturer: 'Dwi Issadari Hastuti, S.Pd., S.Kom., M.Kom',
    totalMeetings: 10,
    records: List.generate(10, (i) => AttendanceRecord(
      date: _generateDate(2026, 2, 3, i), meeting: i + 1, status: 'present',
    )),
  ),
  // Kamis - IoT (mulai 5 Feb 2026, Kamis)
  CourseAttendance(
    subject: 'Internet Of Things',
    lecturer: 'Mula Agung Barata, S.ST., M.Kom',
    totalMeetings: 10,
    records: List.generate(10, (i) => AttendanceRecord(
      date: _generateDate(2026, 2, 5, i), meeting: i + 1, status: 'present',
    )),
  ),
  // Kamis - Komparsis (mulai 5 Feb 2026, Kamis)
  CourseAttendance(
    subject: 'Komputasi Paralel Dan Terdistribusi',
    lecturer: 'Afnil Efan Pajri, S.Kom., M.I.Kom',
    totalMeetings: 10,
    records: List.generate(10, (i) => AttendanceRecord(
      date: _generateDate(2026, 2, 5, i), meeting: i + 1, status: 'present',
    )),
  ),
];

String _generateDate(int year, int month, int day, int weekIndex) {
  final base = DateTime(year, month, day);
  final date = base.add(Duration(days: weekIndex * 7));
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
