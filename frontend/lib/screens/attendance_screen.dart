import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as perm;
import 'package:provider/provider.dart';
import '../constants/theme.dart';
import '../constants/mock_data.dart';
import '../services/api_service.dart';
import '../services/app_time.dart';
import '../providers/app_provider.dart';

/// AttendanceScreen — Modern Clean Design
/// ─────────────────────────────────────────────
/// Camera + GPS verification with frosted glass panels,
/// multi-frame liveness detection, and smooth scanning animation.
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> with TickerProviderStateMixin {
  CameraController? _cameraController;
  bool _cameraInitialized = false;
  bool _cameraPermissionDenied = false;
  bool _cameraPermissionPermanent = false;
  bool _locationPermissionDenied = false;
  bool _locationPermissionPermanent = false;
  bool _mockLocationDetected = false;

  double? _currentLat;
  double? _currentLng;
  double? _distance;
  bool _isInRange = false;
  bool _isScanning = false;
  Map<String, dynamic>? _result;
  bool _showResult = false;
  ScheduleItem? _activeSchedule; // dynamically resolved from today's schedule

  // Liveness challenge state
  String? _livenessPrompt;

  late AnimationController _scanAnimController;
  late Animation<double> _scanAnim;
  late AnimationController _pulseAnimController;
  late Animation<double> _pulseAnim;

  // Random liveness prompts (Indonesian)
  static const _livenessPrompts = [
    'Tolehkan kepala ke kanan',
    'Tolehkan kepala ke kiri',
    'Anggukkan kepala',
    'Kedipkan mata 2 kali',
  ];

  @override
  void initState() {
    super.initState();

    _scanAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    _scanAnim = Tween<double>(begin: -110, end: 110).animate(
      CurvedAnimation(parent: _scanAnimController, curve: Curves.easeInOut),
    );

    _pulseAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseAnimController, curve: Curves.easeInOut),
    );
    _pulseAnimController.repeat(reverse: true);

    _initCamera();
    _initLocation();
    _resolveActiveSchedule();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _scanAnimController.dispose();
    _pulseAnimController.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    // Use permission_handler for explicit permission control
    var status = await perm.Permission.camera.status;

    if (status.isDenied) {
      status = await perm.Permission.camera.request();
    }

    if (status.isPermanentlyDenied) {
      if (mounted) {
        setState(() {
          _cameraPermissionDenied = true;
          _cameraPermissionPermanent = true;
        });
      }
      return;
    }

    if (status.isDenied) {
      if (mounted) setState(() => _cameraPermissionDenied = true);
      return;
    }

    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _cameraController = CameraController(front, ResolutionPreset.high);
      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _cameraInitialized = true;
          _cameraPermissionDenied = false;
          _cameraPermissionPermanent = false;
        });
      }
    } catch (e) {
      debugPrint('Camera init error: $e');
      if (mounted) setState(() => _cameraPermissionDenied = true);
    }
  }

  Future<void> _initLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _locationPermissionDenied = true);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) setState(() => _locationPermissionDenied = true);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _locationPermissionDenied = true;
            _locationPermissionPermanent = true;
          });
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      // GPS Spoofing Detection — reject mocked locations
      if (pos.isMocked) {
        if (mounted) {
          setState(() => _mockLocationDetected = true);
        }
        return;
      }

      final dist = _haversineDistance(pos.latitude, pos.longitude, Campus.latitude, Campus.longitude);
      if (mounted) {
        setState(() {
          _currentLat = pos.latitude;
          _currentLng = pos.longitude;
          _distance = dist;
          _isInRange = dist <= Campus.allowedRadiusMeters;
          _mockLocationDetected = false;
        });
      }
    } catch (e) {
      debugPrint('Location error: $e');
    }
  }

  double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371e3;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLon / 2) * sin(dLon / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  void _resolveActiveSchedule() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AppProvider>();
      final todaySchedules = provider.dashboardData?.todaySchedules ?? [];

      // Find the class currently within its attendance window
      // Window: 12 hours before class start → 15 minutes after class start
      final now = AppTime.timeOfDay();
      final nowMinutes = now.hour * 60 + now.minute;
      const earlyOpenMinutes = 12 * 60; // 12 hours
      const lateCloseMinutes = 15;

      for (final item in todaySchedules) {
        final startStr = item.time.split(' – ').first.trim();
        final parts = startStr.split(':');
        if (parts.length == 2) {
          final startMinutes = int.parse(parts[0]) * 60 + int.parse(parts[1]);
          final diff = nowMinutes - startMinutes;
          if (diff >= -earlyOpenMinutes && diff <= lateCloseMinutes) {
            setState(() => _activeSchedule = item);
            return;
          }
        }
      }

      // Fallback: no class in window; still set first if available (UI shows disabled)
      if (todaySchedules.isNotEmpty) {
        setState(() => _activeSchedule = todaySchedules.first);
      }
    });
  }

  /// Check if the active schedule is within the attendance window right now.
  /// Window: 12 hours before class start → 15 minutes after class start.
  bool _isWithinAttendanceWindow() {
    if (_activeSchedule == null) return false;
    final now = AppTime.timeOfDay();
    final nowMinutes = now.hour * 60 + now.minute;
    const earlyOpenMinutes = 12 * 60; // 12 hours
    const lateCloseMinutes = 15;

    final startStr = _activeSchedule!.time.split(' – ').first.trim();
    final parts = startStr.split(':');
    if (parts.length != 2) return false;

    final startMinutes = int.parse(parts[0]) * 60 + int.parse(parts[1]);
    final diff = nowMinutes - startMinutes;
    return diff >= -earlyOpenMinutes && diff <= lateCloseMinutes;
  }

  /// Capture multiple frames for liveness detection.
  /// Takes 3 photos spaced ~800ms apart while showing the liveness prompt.
  Future<List<String>> _captureMultiFrame() async {
    final List<String> paths = [];

    // Select a random liveness prompt
    final prompt = _livenessPrompts[Random().nextInt(_livenessPrompts.length)];
    setState(() => _livenessPrompt = prompt);

    // Frame 1: initial position
    final frame1 = await _cameraController!.takePicture();
    paths.add(frame1.path);

    // Wait for user to perform the action
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return paths;

    // Frame 2: mid-action
    final frame2 = await _cameraController!.takePicture();
    paths.add(frame2.path);

    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return paths;

    // Frame 3: post-action
    final frame3 = await _cameraController!.takePicture();
    paths.add(frame3.path);

    setState(() => _livenessPrompt = null);
    return paths;
  }

  Future<void> _handleCapture() async {
    // Block if mock location detected
    if (_mockLocationDetected) {
      setState(() {
        _result = {
          'success': false,
          'message': 'Lokasi palsu terdeteksi. Nonaktifkan aplikasi "Fake GPS" dan coba lagi.',
        };
        _showResult = true;
      });
      return;
    }

    // Verify time window before proceeding
    if (!_isWithinAttendanceWindow()) {
      setState(() {
        _result = {
          'success': false,
          'message': 'Absensi hanya dapat dilakukan dalam 15 menit pertama setelah kelas dimulai.',
        };
        _showResult = true;
      });
      return;
    }

    // Start scanning animation
    setState(() => _isScanning = true);
    _scanAnimController.repeat(reverse: true);

    try {
      // 1. Multi-frame capture for liveness detection
      final imagePaths = await _captureMultiFrame();
      if (!mounted) return;

      // 2. Submit to backend with all frames
      final activeCourseId = _activeSchedule?.courseId ?? 'cl_logmat';
      final result = await ApiService.submitAttendance(
        courseId: activeCourseId,
        status: "present",
        latitude: _currentLat ?? 0.0,
        longitude: _currentLng ?? 0.0,
        imagePaths: imagePaths,
      );

      _scanAnimController.stop();
      setState(() {
         _isScanning = false;
         _result = {'success': result.success, 'message': result.message};
         _showResult = true;
      });
    } catch (e) {
      _scanAnimController.stop();
      setState(() {
        _isScanning = false;
        _result = {'success': false, 'message': 'Gagal memproses gambar kamera: $e'};
        _showResult = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Camera permission denied
    if (_cameraPermissionDenied) {
      return _buildPermissionScreen(
        icon: Icons.camera_alt_outlined,
        title: 'Izin Kamera Diperlukan',
        desc: _cameraPermissionPermanent
            ? 'Izin kamera ditolak secara permanen. Buka Pengaturan untuk mengaktifkannya.'
            : 'Aplikasi membutuhkan akses kamera untuk verifikasi wajah.',
        buttonText: _cameraPermissionPermanent ? 'Buka Pengaturan' : 'Beri Izin Kamera',
        onPressed: _cameraPermissionPermanent ? () => perm.openAppSettings() : _initCamera,
      );
    }

    // Mock location detected
    if (_mockLocationDetected) {
      return _buildPermissionScreen(
        icon: Icons.gps_off,
        title: 'Lokasi Palsu Terdeteksi',
        desc: 'Aplikasi "Fake GPS" terdeteksi. Nonaktifkan lokasi palsu lalu coba lagi.',
        buttonText: 'Coba Lagi',
        onPressed: _initLocation,
      );
    }

    // Location permission denied
    if (_locationPermissionDenied) {
      return _buildPermissionScreen(
        icon: Icons.location_off_outlined,
        title: 'Izin Lokasi Diperlukan',
        desc: _locationPermissionPermanent
            ? 'Izin lokasi ditolak secara permanen. Buka Pengaturan untuk mengaktifkannya.'
            : 'Aplikasi membutuhkan akses lokasi untuk memvalidasi kehadiran Anda.',
        buttonText: _locationPermissionPermanent ? 'Buka Pengaturan' : 'Beri Izin Lokasi',
        onPressed: _locationPermissionPermanent ? () => perm.openAppSettings() : _initLocation,
      );
    }

    // Camera not initialized yet
    if (!_cameraInitialized || _cameraController == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          children: [
            // Camera preview
            Positioned.fill(child: CameraPreview(controller: _cameraController!)),

            // Overlay
            Positioned.fill(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top bar
                  Container(
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 8,
                      left: 16,
                      right: 16,
                      bottom: 12,
                    ),
                    color: Colors.black.withValues(alpha: 0.25),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.chevron_left, size: 22, color: AppColors.white),
                          ),
                        ),
                        const Text(
                          'Verifikasi Wajah',
                          style: TextStyle(
                            fontSize: AppFonts.h3,
                            fontWeight: FontWeight.w400,
                            color: AppColors.white,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(width: 40),
                      ],
                    ),
                  ),

                  // Face frame
                  Column(
                    children: [
                      SizedBox(
                        width: 250,
                        height: 250,
                        child: Stack(
                          children: [
                            // Corner markers
                            _buildCorner(top: 0, left: 0, topLeft: true),
                            _buildCorner(top: 0, right: 0, topRight: true),
                            _buildCorner(bottom: 0, left: 0, bottomLeft: true),
                            _buildCorner(bottom: 0, right: 0, bottomRight: true),

                            // Scan line
                            if (_isScanning)
                              AnimatedBuilder(
                                animation: _scanAnim,
                                builder: (context2, child2) => Positioned(
                                  top: 125 + _scanAnim.value,
                                  left: 12,
                                  right: 12,
                                  child: Container(
                                    height: 2,
                                    decoration: BoxDecoration(
                                      color: AppColors.accent,
                                      borderRadius: BorderRadius.circular(1),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.accent.withValues(alpha: 0.6),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _livenessPrompt != null
                            ? _livenessPrompt!
                            : _isScanning
                                ? 'Memindai wajah…'
                                : 'Posisikan wajah di dalam bingkai',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: _livenessPrompt != null ? AppFonts.body : AppFonts.caption,
                          fontWeight: _livenessPrompt != null ? FontWeight.w400 : FontWeight.normal,
                          color: _livenessPrompt != null
                              ? AppColors.accent
                              : Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),

                  // Bottom panel
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(AppRadius.xl),
                        topRight: Radius.circular(AppRadius.xl),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Location chip
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                          decoration: BoxDecoration(
                            color: _isInRange
                                ? const Color(0x2614B8A6)
                                : const Color(0x26F59E0B),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _isInRange ? Icons.check_circle : Icons.error,
                                size: 18,
                                color: _isInRange ? const Color(0xFF14B8A6) : const Color(0xFFF59E0B),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _distance != null
                                      ? _isInRange
                                          ? 'Dalam jangkauan (${_distance!.round()}m)'
                                          : 'Di luar jangkauan (${_distance!.round()}m)'
                                      : 'Mengambil lokasi…',
                                  style: const TextStyle(
                                    fontSize: AppFonts.caption,
                                    color: AppColors.white,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Capture button
                        Builder(builder: (context) {
                          final windowOpen = _isWithinAttendanceWindow();
                          final bool buttonEnabled = windowOpen && !_isScanning;

                          return AnimatedBuilder(
                            animation: _pulseAnim,
                            builder: (_, child) => Transform.scale(
                              scale: _isScanning || !windowOpen ? 1.0 : _pulseAnim.value,
                              child: child,
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                  boxShadow: windowOpen ? AppShadows.glow : null,
                                ),
                                child: ElevatedButton(
                                  onPressed: buttonEnabled ? _handleCapture : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: windowOpen ? AppColors.primary : Colors.grey.shade600,
                                    disabledBackgroundColor: windowOpen
                                        ? AppColors.primary.withValues(alpha: 0.7)
                                        : Colors.grey.shade700,
                                    foregroundColor: AppColors.white,
                                    disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(AppRadius.md),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: _isScanning
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            color: AppColors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(windowOpen ? Icons.face : Icons.lock_clock, size: 22),
                                            const SizedBox(width: 10),
                                            Text(
                                              windowOpen
                                                  ? 'Verifikasi Sekarang'
                                                  : 'Di Luar Waktu Absensi',
                                              style: const TextStyle(
                                                fontSize: AppFonts.body,
                                                fontWeight: FontWeight.w400,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Result Modal
            if (_showResult)
              Container(
                color: AppColors.overlay,
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.all(32),
                    constraints: const BoxConstraints(maxWidth: 340),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      boxShadow: AppShadows.medium,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            color: _result?['success'] == true ? AppColors.accentSurface : AppColors.dangerSurface,
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Icon(
                            _result?['success'] == true ? Icons.check_circle : Icons.cancel,
                            size: 52,
                            color: _result?['success'] == true ? AppColors.accent : AppColors.danger,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _result?['success'] == true ? 'Berhasil!' : 'Gagal',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _result?['message'] ?? '',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: AppFonts.body,
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() => _showResult = false);
                              if (_result?['success'] == true) Navigator.of(context).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _result?['success'] == true ? AppColors.accent : AppColors.primary,
                              foregroundColor: AppColors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              _result?['success'] == true ? 'Kembali ke Dashboard' : 'Coba Lagi',
                              style: const TextStyle(fontSize: AppFonts.body, fontWeight: FontWeight.w400),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCorner({
    double? top,
    double? bottom,
    double? left,
    double? right,
    bool topLeft = false,
    bool topRight = false,
    bool bottomLeft = false,
    bool bottomRight = false,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          border: Border(
            top: topLeft || topRight ? const BorderSide(color: AppColors.white, width: 3) : BorderSide.none,
            bottom: bottomLeft || bottomRight ? const BorderSide(color: AppColors.white, width: 3) : BorderSide.none,
            left: topLeft || bottomLeft ? const BorderSide(color: AppColors.white, width: 3) : BorderSide.none,
            right: topRight || bottomRight ? const BorderSide(color: AppColors.white, width: 3) : BorderSide.none,
          ),
          borderRadius: BorderRadius.only(
            topLeft: topLeft ? const Radius.circular(16) : Radius.zero,
            topRight: topRight ? const Radius.circular(16) : Radius.zero,
            bottomLeft: bottomLeft ? const Radius.circular(16) : Radius.zero,
            bottomRight: bottomRight ? const Radius.circular(16) : Radius.zero,
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionScreen({
    required IconData icon,
    required String title,
    required String desc,
    String? buttonText,
    VoidCallback? onPressed,
  }) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(icon, size: 48, color: AppColors.textMuted),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: AppFonts.h2,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  desc,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: AppFonts.body,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                if (buttonText != null && onPressed != null) ...[
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: onPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    child: Text(buttonText, style: const TextStyle(fontWeight: FontWeight.w400)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Camera Preview Widget
class CameraPreview extends StatelessWidget {
  final CameraController controller;

  const CameraPreview({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    return CameraPreview._buildPreview(controller);
  }

  static Widget _buildPreview(CameraController controller) {
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: controller.value.previewSize?.height ?? 1,
        height: controller.value.previewSize?.width ?? 1,
        child: controller.buildPreview(),
      ),
    );
  }
}
