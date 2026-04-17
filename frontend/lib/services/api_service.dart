import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/mock_data.dart';

// ─── Typed Result Classes ────────────────────────────────────────

class DashboardData {
  final Student student;
  final List<ScheduleItem> todaySchedules;

  DashboardData({
    required this.student,
    required this.todaySchedules,
  });
}

/// Generic result for API calls that return success/message pairs.
class ApiResult {
  final bool success;
  final String message;

  const ApiResult({required this.success, required this.message});
}

// ─── API Exception ──────────────────────────────────────────────

class ApiException implements Exception {
  final int statusCode;
  final String body;

  const ApiException(this.statusCode, this.body);

  @override
  String toString() => 'ApiException($statusCode): $body';
}

// ─── API Service ────────────────────────────────────────────────

class ApiService {
  // URL dapat diubah tanpa edit kode via:
  //   flutter run --dart-define=API_URL=http://192.168.1.x:3000/api
  //   flutter build apk --dart-define=API_URL=https://api.production.com/api
  // Default: localhost untuk web, 192.168.1.21 untuk mobile (HP fisik)
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: kIsWeb
        ? 'http://localhost:3000/api'
        : 'http://192.168.1.21:3000/api',
  );

  static const String _tokenKey = 'auth_token';
  static const Duration _defaultTimeout = Duration(seconds: 8);
  static const _secureStorage = FlutterSecureStorage();

  /// Mock data fallback hanya aktif di debug mode.
  /// Di release build, API error akan di-propagate ke UI.
  static const bool kUseMockFallback = kDebugMode;

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
    // NOTE: Saved credentials are NOT cleared here.
    // They persist so biometric login can re-authenticate.
  }

  // ─── Credential Storage (for biometric re-auth) ────────────────

  /// Save credentials securely after successful NIM+password login.
  static Future<void> _saveCredentials(String nim, String password) async {
    await _secureStorage.write(key: 'saved_nim', value: nim);
    await _secureStorage.write(key: 'saved_password', value: password);
  }

  /// Check if saved credentials exist (for biometric login eligibility).
  static Future<bool> hasSavedCredentials() async {
    final nim = await _secureStorage.read(key: 'saved_nim');
    return nim != null && nim.isNotEmpty;
  }

  /// Re-authenticate using saved credentials. Returns true if a new token was obtained.
  static Future<bool> loginWithSavedCredentials() async {
    final nim = await _secureStorage.read(key: 'saved_nim');
    final password = await _secureStorage.read(key: 'saved_password');
    if (nim == null || password == null) return false;
    try {
      return await login(nim, password);
    } catch (e) {
      debugPrint('Biometric re-auth failed: $e');
      return false;
    }
  }

  /// Clear saved credentials (e.g., when user wants to fully sign out).
  static Future<void> clearSavedCredentials() async {
    await _secureStorage.delete(key: 'saved_nim');
    await _secureStorage.delete(key: 'saved_password');
  }

  /// Helper: build auth headers
  static Future<Map<String, String>> _authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ─── Generic API Helpers ─────────────────────────────────────────

  /// Generic GET request with JSON parsing.
  static Future<T> _get<T>(
    String path, {
    required T Function(dynamic json) parser,
    Duration timeout = _defaultTimeout,
  }) async {
    final headers = await _authHeaders();
    final response = await http
        .get(Uri.parse('$baseUrl$path'), headers: headers)
        .timeout(timeout);

    if (response.statusCode == 200) {
      return parser(json.decode(response.body));
    }
    throw ApiException(response.statusCode, response.body);
  }

  // ─── Authentication ──────────────────────────────────────────────

  static Future<bool> login(String nim, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'studentId': nim, 'password': password}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await saveToken(data['token']);
        await _saveCredentials(nim, password);
        return true;
      } else {
        throw Exception('Kredensial tidak valid');
      }
    } catch (e) {
      if (e.toString().contains('Kredensial tidak valid')) rethrow;
      throw Exception('Server tidak dapat dihubungi. Pastikan backend berjalan: $e');
    }
  }

  // ─── Dashboard ───────────────────────────────────────────────────

  static Future<DashboardData> getDashboardData() async {
    try {
      // Fetch both schedules and profile in parallel
      final results = await Future.wait([
        _get<List<ScheduleItem>>(
          '/schedules',
          parser: (json) => (json as List)
              .map((data) => ScheduleItem.fromJson(data))
              .toList(),
        ).catchError((_) => <ScheduleItem>[]),
        getProfile(),
      ]);

      final liveSchedules = results[0] as List<ScheduleItem>;
      final student = results[1] as Student;

      return DashboardData(
        student: student,
        todaySchedules: liveSchedules.isEmpty && kUseMockFallback
            ? _getMockSchedulesData()
            : liveSchedules,
      );
    } catch (e) {
      if (kUseMockFallback) {
        return DashboardData(
          student: mockStudent,
          todaySchedules: _getMockSchedulesData(),
        );
      }
      rethrow;
    }
  }

  static List<ScheduleItem> _getMockSchedulesData() {
    const dayNames = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    final todayDay = dayNames[DateTime.now().weekday - 1];
    return mockWeeklySchedule[todayDay] ?? [];
  }

  // ─── Schedules (by day) ──────────────────────────────────────────

  static Future<List<ScheduleItem>> getSchedulesByDay(String dayOfWeek) async {
    try {
      return await _get<List<ScheduleItem>>(
        '/schedules?dayOfWeek=$dayOfWeek',
        parser: (json) {
          final list = json as List;
          if (list.isEmpty) return mockWeeklySchedule[dayOfWeek] ?? [];
          return list.map((data) => ScheduleItem.fromJson(data)).toList();
        },
      );
    } catch (e) {
      if (kUseMockFallback) {
        debugPrint('Schedule API Failed ($e). Using mock (debug only).');
        return mockWeeklySchedule[dayOfWeek] ?? [];
      }
      rethrow;
    }
  }

  // ─── Attendance ──────────────────────────────────────────────────

  static Future<bool> submitAttendance({
    required String courseId,
    int? meetingCount,
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
      if (meetingCount != null) {
        request.fields['meetingCount'] = meetingCount.toString();
      }
      request.fields['status'] = status;
      request.fields['latitude'] = latitude.toString();
      request.fields['longitude'] = longitude.toString();

      if (imagePath != null) {
        request.files.add(await http.MultipartFile.fromPath('faceImage', imagePath));
      }

      final streamedResponse = await request.send().timeout(const Duration(seconds: 10));
      final response = await http.Response.fromStream(streamedResponse);
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      debugPrint('Attendance submit failed: $e');
      return false;
    }
  }

  static Future<List<CourseAttendance>> getAttendanceHistory() async {
    try {
      return await _get<List<CourseAttendance>>(
        '/attendance/history',
        parser: (json) {
          final jsonList = json as List;
          final Map<String, CourseAttendance> courseMap = {};

          for (var data in jsonList) {
            final courseData = data['course'] ?? {};
            final courseId = data['courseId']?.toString() ?? 'unknown';

            if (!courseMap.containsKey(courseId)) {
              courseMap[courseId] = CourseAttendance(
                subject: courseData['name'] ?? 'Unknown Course',
                lecturer: courseData['lecturer'] ?? 'Unknown Lecturer',
                totalMeetings: courseData['totalMeetings'] ?? 14,
                records: [],
              );
            }
            courseMap[courseId]!.records.add(AttendanceRecord.fromJson(data));
          }

          return courseMap.values.toList();
        },
      );
    } catch (e) {
      throw Exception('History API Failed: $e');
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

      final streamedResponse = await request.send().timeout(_defaultTimeout);
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 201 || response.statusCode == 200) {
        return true;
      } else {
        throw ApiException(response.statusCode, response.body);
      }
    } catch (e) {
      debugPrint('Leave request failed: $e');
      rethrow;
    }
  }

  static Future<List<LeaveRequest>> getLeaveHistory() async {
    try {
      return await _get<List<LeaveRequest>>(
        '/leave-requests',
        parser: (json) => (json as List)
            .map((data) => LeaveRequest.fromJson(data))
            .toList(),
      );
    } catch (e) {
      debugPrint('Leave history API Failed ($e).');
      return [];
    }
  }

  // ─── Profile ──────────────────────────────────────────────────────

  static Future<Student> getProfile() async {
    try {
      return await _get<Student>(
        '/profile',
        parser: (json) => Student.fromJson(json),
      );
    } catch (e) {
      if (kUseMockFallback) {
        debugPrint('Profile API Failed ($e). Using mock (debug only).');
        return mockStudent;
      }
      rethrow;
    }
  }

  static Future<String?> changePassword(String oldPassword, String newPassword) async {
    try {
      final headers = await _authHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/profile/password'),
        headers: headers,
        body: json.encode({'oldPassword': oldPassword, 'newPassword': newPassword}),
      ).timeout(_defaultTimeout);

      if (response.statusCode == 200) return null;
      final data = json.decode(response.body);
      return data['message'] ?? 'Gagal mengubah password.';
    } catch (e) {
      return 'Server tidak dapat dihubungi.';
    }
  }

  // ─── Face Registration ─────────────────────────────────────────────

  /// Register face descriptor by uploading a photo
  static Future<ApiResult> registerFace(String imagePath) async {
    try {
      final token = await getToken();
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/face/register'));
      if (token != null) request.headers['Authorization'] = 'Bearer $token';

      request.files.add(await http.MultipartFile.fromPath('faceImage', imagePath));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 10));
      final response = await http.Response.fromStream(streamedResponse);
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return ApiResult(success: true, message: data['message'] ?? 'Wajah berhasil didaftarkan!');
      } else {
        return ApiResult(success: false, message: data['message'] ?? 'Gagal mendaftarkan wajah.');
      }
    } catch (e) {
      return ApiResult(success: false, message: 'Server tidak dapat dihubungi: $e');
    }
  }

  /// Check if face is registered and model is available on server
  static Future<ApiResult> getFaceStatus() async {
    try {
      return await _get<ApiResult>(
        '/face/status',
        parser: (json) => ApiResult(
          success: json['registered'] == true,
          message: json['modelAvailable'] == true ? 'Model tersedia' : 'Model belum tersedia',
        ),
      );
    } catch (e) {
      return const ApiResult(success: false, message: 'Tidak dapat menghubungi server');
    }
  }
}
