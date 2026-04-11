import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import '../constants/mock_data.dart';

class AppProvider extends ChangeNotifier {
  // ─── Dashboard ─────────────────────────────────────────────────
  DashboardData? dashboardData;
  bool isLoadingDashboard = false;

  // ─── Attendance History ────────────────────────────────────────
  List<CourseAttendance>? attendanceHistory;
  bool isLoadingHistory = false;

  // ─── Profile ───────────────────────────────────────────────────
  Student? studentProfile;
  bool isLoadingProfile = false;

  // ─── Tasks ─────────────────────────────────────────────────────
  List<TaskItem>? tasks;
  bool isLoadingTasks = false;

  // ─── Leave Requests ────────────────────────────────────────────
  List<LeaveRequest>? leaveHistory;
  bool isLoadingLeave = false;

  // ─── Global ────────────────────────────────────────────────────
  String? errorMessage;

  // ════════════════════════════════════════════════════════════════
  // Dashboard
  // ════════════════════════════════════════════════════════════════

  Future<void> fetchDashboardData({bool forceRefresh = false}) async {
    if (dashboardData != null && !forceRefresh) return;

    isLoadingDashboard = true;
    errorMessage = null;
    notifyListeners();

    try {
      dashboardData = await ApiService.getDashboardData();
    } catch (e) {
      errorMessage = e.toString();
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
    errorMessage = null;
    notifyListeners();

    try {
      attendanceHistory = await ApiService.getAttendanceHistory();
    } catch (e) {
      errorMessage = e.toString();
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
    errorMessage = null;
    notifyListeners();

    try {
      studentProfile = await ApiService.getProfile();
    } catch (e) {
      errorMessage = e.toString();
      studentProfile = mockStudent; // fallback
    } finally {
      isLoadingProfile = false;
      notifyListeners();
    }
  }

  // ════════════════════════════════════════════════════════════════
  // Tasks
  // ════════════════════════════════════════════════════════════════

  Future<void> fetchTasks({bool forceRefresh = false}) async {
    if (tasks != null && !forceRefresh) return;

    isLoadingTasks = true;
    errorMessage = null;
    notifyListeners();

    try {
      tasks = await ApiService.getTasks();
    } catch (e) {
      errorMessage = e.toString();
      tasks = mockTasks; // fallback
    } finally {
      isLoadingTasks = false;
      notifyListeners();
    }
  }

  Future<void> toggleTaskComplete(String taskId, bool completed) async {
    final success = await ApiService.updateTask(taskId, {'completed': completed});
    if (success) {
      // Update local state
      final index = tasks?.indexWhere((t) => t.id == taskId) ?? -1;
      if (index >= 0 && tasks != null) {
        final old = tasks![index];
        tasks![index] = TaskItem(
          id: old.id,
          title: old.title,
          description: old.description,
          deadline: old.deadline,
          priority: old.priority,
          completed: completed,
          subject: old.subject,
        );
        notifyListeners();
      }
    }
  }

  // ════════════════════════════════════════════════════════════════
  // Leave Requests
  // ════════════════════════════════════════════════════════════════

  Future<void> fetchLeaveHistory({bool forceRefresh = false}) async {
    if (leaveHistory != null && !forceRefresh) return;

    isLoadingLeave = true;
    errorMessage = null;
    notifyListeners();

    try {
      leaveHistory = await ApiService.getLeaveHistory();
    } catch (e) {
      errorMessage = e.toString();
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
    tasks = null;
    leaveHistory = null;
    errorMessage = null;
    notifyListeners();
  }
}
