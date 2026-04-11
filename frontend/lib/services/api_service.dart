import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../constants/mock_data.dart';

class DashboardData {
  final Student student;
  final List<ScheduleItem> todaySchedules;

  DashboardData({
    required this.student,
    required this.todaySchedules,
  });
}

class ApiService {
  // Use 10.0.2.2 for Android emulator, localhost for web/desktop
  // Change to your actual IP for physical device testing
  static const String baseUrl = kIsWeb
      ? 'http://localhost:3000/api'
      : 'http://10.0.2.2:3000/api';

  static const String _tokenKey = 'auth_token';

  // ─── Token Management ──────────────────────────────────────────

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  /// Helper: build auth headers
  static Future<Map<String, String>> _authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ─── Authentication ──────────────────────────────────────────────

  static Future<bool> login(String nim, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'studentId': nim, 'password': password}),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await saveToken(data['token']);
        return true;
      } else {
        throw Exception('Kredensial tidak valid');
      }
    } catch (e) {
      if (e.toString().contains('Kredensial tidak valid')) rethrow;

      if (kDebugMode) {
        debugPrint('⚠️ [DEBUG] Backend offline ($e). Mock fallback.');
        if (password == 'mahasiswa' || password.length >= 6) {
          await saveToken('mock_jwt_token_12345');
          return true;
        }
      }
      throw Exception('Server tidak dapat dihubungi. Pastikan backend berjalan.');
    }
  }

  // ─── Dashboard ───────────────────────────────────────────────────

  static Future<DashboardData> getDashboardData() async {
    try {
      final headers = await _authHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/schedules'),
        headers: headers,
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        List<ScheduleItem> liveSchedules = jsonList
            .map((data) => ScheduleItem.fromJson(data))
            .toList();

        return DashboardData(
          student: mockStudent,
          todaySchedules: liveSchedules.isEmpty ? _getMockSchedulesData() : liveSchedules,
        );
      } else {
        debugPrint('Dashboard API Error: ${response.statusCode}');
        return _mockDashboardFallback();
      }
    } catch (e) {
      debugPrint('Dashboard API Failed ($e). Using mock.');
      return _mockDashboardFallback();
    }
  }

  static Future<DashboardData> _mockDashboardFallback() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return DashboardData(student: mockStudent, todaySchedules: _getMockSchedulesData());
  }

  static List<ScheduleItem> _getMockSchedulesData() {
    const dayNames = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    final todayDay = dayNames[DateTime.now().weekday - 1];
    return mockWeeklySchedule[todayDay] ?? [];
  }

  // ─── Schedules (by day) ──────────────────────────────────────────

  static Future<List<ScheduleItem>> getSchedulesByDay(String dayOfWeek) async {
    try {
      final headers = await _authHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/schedules?dayOfWeek=$dayOfWeek'),
        headers: headers,
      ).timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        if (jsonList.isEmpty) return mockWeeklySchedule[dayOfWeek] ?? [];
        return jsonList.map((data) => ScheduleItem.fromJson(data)).toList();
      }
      return mockWeeklySchedule[dayOfWeek] ?? [];
    } catch (e) {
      debugPrint('Schedule API Failed ($e). Using mock.');
      return mockWeeklySchedule[dayOfWeek] ?? [];
    }
  }

  // ─── Attendance ──────────────────────────────────────────────────

  static Future<bool> submitAttendance({
    required String courseId,
    required int meetingCount,
    required String status,
    required double latitude,
    required double longitude,
    String? imagePath,
  }) async {
    try {
      final token = await getToken();
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/attendance'));
      if (token != null) request.headers['Authorization'] = 'Bearer $token';

      request.fields['courseId'] = courseId;
      request.fields['meetingCount'] = meetingCount.toString();
      request.fields['status'] = status;
      request.fields['latitude'] = latitude.toString();
      request.fields['longitude'] = longitude.toString();

      if (imagePath != null) {
        request.files.add(await http.MultipartFile.fromPath('faceImage', imagePath));
      }

      final streamedResponse = await request.send().timeout(const Duration(seconds: 5));
      final response = await http.Response.fromStream(streamedResponse);
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      debugPrint('Attendance submit failed ($e). Using fallback.');
      await Future.delayed(const Duration(milliseconds: 600));
      return true; // mock fallback
    }
  }

  static Future<List<CourseAttendance>> getAttendanceHistory() async {
    try {
      final headers = await _authHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/attendance/history'),
        headers: headers,
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        final Map<String, CourseAttendance> courseMap = {};

        for (var data in jsonList) {
          final courseData = data['course'] ?? {};
          final courseId = data['courseId']?.toString() ?? 'unknown';

          if (!courseMap.containsKey(courseId)) {
            courseMap[courseId] = CourseAttendance(
              subject: courseData['name'] ?? 'Unknown Course',
              lecturer: courseData['lecturer'] ?? 'Unknown Lecturer',
              totalMeetings: 14,
              records: [],
            );
          }
          courseMap[courseId]!.records.add(AttendanceRecord.fromJson(data));
        }

        final result = courseMap.values.toList();
        if (result.isEmpty) return mockAttendanceHistory;
        return result;
      }
      return mockAttendanceHistory;
    } catch (e) {
      debugPrint('History API Failed ($e). Using mock.');
      return mockAttendanceHistory;
    }
  }

  // ─── Leave Requests ──────────────────────────────────────────────

  static Future<bool> submitLeaveRequest({
    required String leaveType,
    required String startDate,
    required String endDate,
    required String reason,
    PlatformFile? document,
  }) async {
    try {
      final token = await getToken();
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/leave-requests'));
      if (token != null) request.headers['Authorization'] = 'Bearer $token';

      request.fields['reason'] = leaveType;
      request.fields['dateFrom'] = startDate;
      request.fields['dateTo'] = endDate;
      request.fields['description'] = reason;

      if (document != null) {
        if (document.path != null) {
          request.files.add(await http.MultipartFile.fromPath('document', document.path!));
        } else if (document.bytes != null) {
          request.files.add(http.MultipartFile.fromBytes('document', document.bytes!, filename: document.name));
        }
      }

      final streamedResponse = await request.send().timeout(const Duration(seconds: 4));
      final response = await http.Response.fromStream(streamedResponse);
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      debugPrint('Leave request failed ($e). Using fallback.');
      await Future.delayed(const Duration(milliseconds: 600));
      return true;
    }
  }

  static Future<List<LeaveRequest>> getLeaveHistory() async {
    try {
      final headers = await _authHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/leave-requests'),
        headers: headers,
      ).timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        return jsonList.map((data) => LeaveRequest.fromJson(data)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Leave history API Failed ($e).');
      return [];
    }
  }

  // ─── Profile ──────────────────────────────────────────────────────

  static Future<Student> getProfile() async {
    try {
      final headers = await _authHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/profile'),
        headers: headers,
      ).timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        return Student.fromJson(json.decode(response.body));
      }
      return mockStudent;
    } catch (e) {
      debugPrint('Profile API Failed ($e). Using mock.');
      return mockStudent;
    }
  }

  static Future<String?> changePassword(String oldPassword, String newPassword) async {
    try {
      final headers = await _authHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/profile/password'),
        headers: headers,
        body: json.encode({'oldPassword': oldPassword, 'newPassword': newPassword}),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) return null;
      final data = json.decode(response.body);
      return data['message'] ?? 'Gagal mengubah password.';
    } catch (e) {
      return 'Server tidak dapat dihubungi.';
    }
  }

  // ─── Tasks ────────────────────────────────────────────────────────

  static Future<List<TaskItem>> getTasks() async {
    try {
      final headers = await _authHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/tasks'),
        headers: headers,
      ).timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        return jsonList.map((data) => TaskItem.fromJson(data)).toList();
      }
      return mockTasks;
    } catch (e) {
      debugPrint('Tasks API Failed ($e). Using mock.');
      return mockTasks;
    }
  }

  static Future<bool> createTask(Map<String, dynamic> taskData) async {
    try {
      final headers = await _authHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/tasks'),
        headers: headers,
        body: json.encode(taskData),
      ).timeout(const Duration(seconds: 3));
      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> updateTask(String taskId, Map<String, dynamic> data) async {
    try {
      final headers = await _authHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/tasks/$taskId'),
        headers: headers,
        body: json.encode(data),
      ).timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> deleteTask(String taskId) async {
    try {
      final headers = await _authHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/tasks/$taskId'),
        headers: headers,
      ).timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
