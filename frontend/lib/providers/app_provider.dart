import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../constants/mock_data.dart';

class AppProvider extends ChangeNotifier {
  // ─── Dashboard ─────────────────────────────────────────────────
  DashboardData? dashboardData;
  bool isLoadingDashboard = false;
  String? dashboardError;

  // ─── Attendance History ────────────────────────────────────────
  List<CourseAttendance>? attendanceHistory;
  bool isLoadingHistory = false;
  String? historyError;

  // ─── Profile ───────────────────────────────────────────────────
  Student? studentProfile;
  bool isLoadingProfile = false;
  String? profileError;

  // ─── Leave Requests ────────────────────────────────────────────
  List<LeaveRequest>? leaveHistory;
  bool isLoadingLeave = false;
  String? leaveError;

  // ════════════════════════════════════════════════════════════════
  // Dashboard
  // ════════════════════════════════════════════════════════════════

  Future<void> fetchDashboardData({bool forceRefresh = false}) async {
    if (dashboardData != null && !forceRefresh) return;

    isLoadingDashboard = true;
    dashboardError = null;
    notifyListeners();

    try {
      dashboardData = await ApiService.getDashboardData();
    } catch (e) {
      dashboardError = e.toString();
    } finally {
      isLoadingDashboard = false;
      notifyListeners();
    }
  }

  // ════════════════════════════════════════════════════════════════
  // Attendance History
  // ════════════════════════════════════════════════════════════════

  Future<void> fetchHistoryData({bool forceRefresh = false}) async {
    if (attendanceHistory != null && !forceRefresh) return;

    isLoadingHistory = true;
    historyError = null;
    notifyListeners();

    try {
      attendanceHistory = await ApiService.getAttendanceHistory();
    } catch (e) {
      historyError = e.toString();
    } finally {
      isLoadingHistory = false;
      notifyListeners();
    }
  }

  // ════════════════════════════════════════════════════════════════
  // Student Profile
  // ════════════════════════════════════════════════════════════════

  Future<void> fetchProfile({bool forceRefresh = false}) async {
    if (studentProfile != null && !forceRefresh) return;

    isLoadingProfile = true;
    profileError = null;
    notifyListeners();

    try {
      studentProfile = await ApiService.getProfile();
    } catch (e) {
      profileError = e.toString();
      studentProfile = mockStudent; // fallback
    } finally {
      isLoadingProfile = false;
      notifyListeners();
    }
  }

  // ════════════════════════════════════════════════════════════════
  // Leave Requests
  // ════════════════════════════════════════════════════════════════

  Future<void> fetchLeaveHistory({bool forceRefresh = false}) async {
    if (leaveHistory != null && !forceRefresh) return;

    isLoadingLeave = true;
    leaveError = null;
    notifyListeners();

    try {
      leaveHistory = await ApiService.getLeaveHistory();
    } catch (e) {
      leaveError = e.toString();
    } finally {
      isLoadingLeave = false;
      notifyListeners();
    }
  }

  // ════════════════════════════════════════════════════════════════
  // Reset
  // ════════════════════════════════════════════════════════════════

  void clearData() {
    dashboardData = null;
    attendanceHistory = null;
    studentProfile = null;
    leaveHistory = null;
    dashboardError = null;
    historyError = null;
    profileError = null;
    leaveError = null;
    notifyListeners();
  }
}
