import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import '../constants/theme.dart';
import '../services/api_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:screen_brightness/screen_brightness.dart';

class FaceRegisterScreen extends StatefulWidget {
  const FaceRegisterScreen({super.key});

  @override
  State<FaceRegisterScreen> createState() => _FaceRegisterScreenState();
}

class _FaceRegisterScreenState extends State<FaceRegisterScreen>
    with TickerProviderStateMixin {
  CameraController? _cameraController;
  bool _isInit = false;
  bool _isRegistering = false;
  bool _permissionDenied = false;
  ApiResult? _result;

  // Screen flash state
  bool _isFlashOn = false;
  double? _originalBrightness;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;
  late AnimationController _scanController;
  late Animation<double> _scanAnim;
  late AnimationController _rotateController;

  @override
  void initState() {
    super.initState();

    // Subtle breathing pulse on the frame
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _pulseAnim = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);

    // Scan line animation (used during registration)
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _scanAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanController, curve: Curves.easeInOut),
    );

    // Rotating dashed border controller
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    _rotateController.repeat();

    _initCamera();
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      if (mounted) setState(() => _permissionDenied = true);
      return;
    }

    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _isInit = true;
          _permissionDenied = false;
        });
      }
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  Future<void> _takeAndRegisterFace() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    setState(() => _isRegistering = true);
    _scanController.repeat(reverse: true);

    try {
      final XFile picture = await _cameraController!.takePicture();

      if (!mounted) return;
      final result = await ApiService.registerFace(picture.path);

      if (!mounted) return;
      _scanController.stop();
      setState(() {
        _isRegistering = false;
        _result = result;
      });
    } catch (e) {
      _scanController.stop();
      setState(() {
        _isRegistering = false;
        _result =
            ApiResult(success: false, message: 'Gagal mengambil gambar: $e');
      });
    }
  }

  @override
  void dispose() {
    _restoreBrightness();
    _cameraController?.dispose();
    _pulseController.dispose();
    _scanController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  Future<void> _toggleFlash() async {
    if (_isFlashOn) {
      await _restoreBrightness();
      setState(() => _isFlashOn = false);
    } else {
      await _enableFlash();
      setState(() => _isFlashOn = true);
    }
  }

  Future<void> _enableFlash() async {
    try {
      _originalBrightness ??= await ScreenBrightness.instance.application;
      await ScreenBrightness.instance.setApplicationScreenBrightness(1.0);
    } catch (_) {}
  }

  Future<void> _restoreBrightness() async {
    try {
      if (_originalBrightness != null) {
        await ScreenBrightness.instance.setApplicationScreenBrightness(_originalBrightness!);
        _originalBrightness = null;
      } else {
        await ScreenBrightness.instance.resetApplicationScreenBrightness();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_permissionDenied) {
      return _buildPermissionDenied();
    }

    if (_result != null) {
      return _buildResult();
    }

    if (!_isInit) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.white));
    }

    return Stack(
      children: [
        // Full-screen camera preview (aspect-ratio-correct)
        Positioned.fill(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _cameraController!.value.previewSize?.height ?? 1,
              height: _cameraController!.value.previewSize?.width ?? 1,
              child: CameraPreview(_cameraController!),
            ),
          ),
        ),

        // Dark vignette overlay with face cutout (only when flash is OFF)
        if (!_isFlashOn)
          Positioned.fill(
            child: CustomPaint(
              painter: _FaceOverlayPainter(),
            ),
          ),

        // Screen flash overlay
        if (_isFlashOn)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _FlashOverlayPainter(),
                child: const SizedBox.expand(),
              ),
            ),
          ),

        // Top bar
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              bottom: 12,
            ),
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
                    child: const Icon(Icons.chevron_left,
                        size: 22, color: AppColors.white),
                  ),
                ),
                const Text(
                  'Daftarkan Wajah',
                  style: TextStyle(
                    fontSize: AppFonts.h3,
                    fontWeight: FontWeight.w600,
                    color: AppColors.white,
                    letterSpacing: -0.2,
                  ),
                ),
                GestureDetector(
                  onTap: _toggleFlash,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _isFlashOn
                          ? Colors.amber.withValues(alpha: 0.3)
                          : Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _isFlashOn ? Icons.flashlight_on : Icons.flashlight_off,
                      size: 20,
                      color: _isFlashOn ? Colors.amber : AppColors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Face frame area (center)
        Center(
          child: AnimatedBuilder(
            animation: _pulseAnim,
            builder: (context, child) => Transform.scale(
              scale: _pulseAnim.value,
              child: child,
            ),
            child: SizedBox(
              width: 260,
              height: 320,
              child: Stack(
                children: [
                  // Corner brackets
                  _buildCorner(top: 0, left: 0, topLeft: true),
                  _buildCorner(top: 0, right: 0, topRight: true),
                  _buildCorner(bottom: 0, left: 0, bottomLeft: true),
                  _buildCorner(bottom: 0, right: 0, bottomRight: true),

                  // Rotating arc indicators
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _rotateController,
                      builder: (context, child) => CustomPaint(
                        painter: _RotatingArcPainter(
                          progress: _rotateController.value,
                          isScanning: _isRegistering,
                        ),
                      ),
                    ),
                  ),

                  // Scan line (visible during registration)
                  if (_isRegistering)
                    AnimatedBuilder(
                      animation: _scanAnim,
                      builder: (context, child) => Positioned(
                        top: 20 + (_scanAnim.value * 280),
                        left: 20,
                        right: 20,
                        child: Container(
                          height: 2,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                AppColors.primary.withValues(alpha: 0.8),
                                AppColors.primary,
                                AppColors.primary.withValues(alpha: 0.8),
                                Colors.transparent,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(1),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.4),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        // Instruction text
        Positioned(
          left: 24,
          right: 24,
          bottom: 180,
          child: Column(
            children: [
              Text(
                _isRegistering
                    ? 'Memindai wajah…'
                    : 'Posisikan wajah di dalam bingkai',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppFonts.body,
                  fontWeight: FontWeight.w500,
                  color: _isRegistering
                      ? AppColors.primary
                      : Colors.white.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Pastikan pencahayaan cukup. Lepaskan kacamata dan topi.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppFonts.caption,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),

        // Bottom capture button
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.7),
                ],
              ),
            ),
            child: _isRegistering
                ? Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 3),
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: AppColors.white,
                            strokeWidth: 2.5,
                          ),
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: GestureDetector(
                      onTap: _takeAndRegisterFace,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.5),
                              width: 4),
                        ),
                        child: Container(
                          margin: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ],
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
    final color = _isRegistering
        ? AppColors.primary
        : Colors.white.withValues(alpha: 0.8);

    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          border: Border(
            top: topLeft || topRight
                ? BorderSide(color: color, width: 3)
                : BorderSide.none,
            bottom: bottomLeft || bottomRight
                ? BorderSide(color: color, width: 3)
                : BorderSide.none,
            left: topLeft || bottomLeft
                ? BorderSide(color: color, width: 3)
                : BorderSide.none,
            right: topRight || bottomRight
                ? BorderSide(color: color, width: 3)
                : BorderSide.none,
          ),
          borderRadius: BorderRadius.only(
            topLeft: topLeft ? const Radius.circular(14) : Radius.zero,
            topRight: topRight ? const Radius.circular(14) : Radius.zero,
            bottomLeft: bottomLeft ? const Radius.circular(14) : Radius.zero,
            bottomRight:
                bottomRight ? const Radius.circular(14) : Radius.zero,
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionDenied() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
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
                child: const Icon(Icons.camera_alt_outlined,
                    size: 40, color: AppColors.textMuted),
              ),
              const SizedBox(height: 20),
              const Text(
                'Akses Kamera Ditolak',
                style: TextStyle(
                    fontSize: AppFonts.h2,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              const Text(
                'Aplikasi membutuhkan akses kamera untuk pendaftaran wajah.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: AppFonts.body, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _initCamera,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResult() {
    final success = _result!.success;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: success
                      ? AppColors.successSurface
                      : AppColors.dangerSurface,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Icon(
                  success ? Icons.check_circle_outline : Icons.error_outline,
                  size: 48,
                  color: success ? AppColors.success : AppColors.danger,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                success ? 'Berhasil!' : 'Gagal',
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                _result!.message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: AppFonts.body, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (success) {
                      Navigator.pop(context);
                    } else {
                      setState(() => _result = null);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md)),
                    elevation: 0,
                  ),
                  child: Text(success ? 'Selesai' : 'Coba Lagi',
                      style: const TextStyle(
                          fontSize: AppFonts.body, fontWeight: FontWeight.w500)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Paints a dark overlay with a rounded-rect cutout for the face area
class _FaceOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.55);

    // Full overlay
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Face cutout (rounded rect, vertically elongated for face shape)
    final cutoutRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2 - 20),
        width: 260,
        height: 320,
      ),
      const Radius.circular(130),
    );

    // Create path with hole
    final path = Path()
      ..addRect(fullRect)
      ..addRRect(cutoutRect);
    path.fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Paints rotating arc segments around the face frame
class _RotatingArcPainter extends CustomPainter {
  final double progress;
  final bool isScanning;

  _RotatingArcPainter({required this.progress, required this.isScanning});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rx = size.width / 2 - 2;
    final ry = size.height / 2 - 2;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..color = isScanning
          ? AppColors.primary.withValues(alpha: 0.6)
          : Colors.white.withValues(alpha: 0.2);

    // Draw 4 rotating arc segments
    final baseAngle = progress * 2 * 3.14159265;
    const sweepAngle = 0.4; // ~23 degrees each
    const gap = 3.14159265 / 2; // 90 degrees apart

    for (int i = 0; i < 4; i++) {
      final startAngle = baseAngle + (i * gap);
      final rect = Rect.fromCenter(
          center: center, width: rx * 2, height: ry * 2);
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RotatingArcPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.isScanning != isScanning;
}

class _FlashOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    final path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final cutoutRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.45),
        width: size.width - 40,
        height: size.height * 0.55,
      ),
      const Radius.circular(80),
    );

    final cutoutPath = Path()..addRRect(cutoutRect);
    final combinedPath = Path.combine(PathOperation.difference, path, cutoutPath);
    
    canvas.drawPath(combinedPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
