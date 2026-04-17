import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/lecturer.dart';

/// State management for Lecturer role
class LecturerProvider extends ChangeNotifier {
  // ─── Dashboard ───────────────────────────────────────────
  Map<String, dynamic>? dashboardData;
  bool isDashboardLoading = false;
  String? dashboardError;

  // ─── Courses ─────────────────────────────────────────────
  List<Map<String, dynamic>> courses = [];
  bool isCoursesLoading = false;

  // ─── Attendance ──────────────────────────────────────────
  Map<String, dynamic>? courseAttendance;
  bool isAttendanceLoading = false;

  // ─── Leave Requests ──────────────────────────────────────
  List<Map<String, dynamic>> leaveRequests = [];
  bool isLeaveLoading = false;

  // ─── Profile ─────────────────────────────────────────────
  Lecturer? profile;
  bool isProfileLoading = false;

  // ─── Fetch Dashboard ─────────────────────────────────────
  Future<void> fetchDashboard() async {
    isDashboardLoading = true;
    dashboardError = null;
    notifyListeners();
    try {
      dashboardData = await ApiService.getLecturerDashboard();
    } catch (e) {
      dashboardError = e.toString();
    }
    isDashboardLoading = false;
    notifyListeners();
  }

  // ─── Fetch Courses ───────────────────────────────────────
  Future<void> fetchCourses() async {
    isCoursesLoading = true;
    notifyListeners();
    try {
      courses = await ApiService.getLecturerCourses();
    } catch (e) {
      debugPrint('Error fetching courses: $e');
    }
    isCoursesLoading = false;
    notifyListeners();
  }

  // ─── Fetch Course Attendance ─────────────────────────────
  Future<void> fetchCourseAttendance(String courseId) async {
    isAttendanceLoading = true;
    notifyListeners();
    try {
      courseAttendance = await ApiService.getCourseAttendance(courseId);
    } catch (e) {
      debugPrint('Error fetching attendance: $e');
    }
    isAttendanceLoading = false;
    notifyListeners();
  }

  // ─── Edit Attendance ─────────────────────────────────────
  Future<bool> editAttendance(String attendanceId, String newStatus) async {
    final success = await ApiService.editAttendanceStatus(attendanceId, newStatus);
    return success;
  }

  // ─── Fetch Leave Requests ────────────────────────────────
  Future<void> fetchLeaveRequests() async {
    isLeaveLoading = true;
    notifyListeners();
    try {
      leaveRequests = await ApiService.getLecturerLeaveRequests();
    } catch (e) {
      debugPrint('Error fetching leave requests: $e');
    }
    isLeaveLoading = false;
    notifyListeners();
  }

  // ─── Review Leave Request ────────────────────────────────
  Future<bool> reviewLeave(String id, String status, String? note) async {
    final success = await ApiService.reviewLeaveRequest(id, status, note);
    if (success) await fetchLeaveRequests();
    return success;
  }

  // ─── Fetch Profile ───────────────────────────────────────
  Future<void> fetchProfile() async {
    isProfileLoading = true;
    notifyListeners();
    try {
      final data = await ApiService.getLecturerProfile();
      profile = Lecturer.fromJson(data);
    } catch (e) {
      debugPrint('Error fetching profile: $e');
    }
    isProfileLoading = false;
    notifyListeners();
  }
}
