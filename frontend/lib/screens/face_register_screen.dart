import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import '../constants/theme.dart';
import '../services/api_service.dart';
import 'package:permission_handler/permission_handler.dart';

class FaceRegisterScreen extends StatefulWidget {
  const FaceRegisterScreen({super.key});

  @override
  State<FaceRegisterScreen> createState() => _FaceRegisterScreenState();
}

class _FaceRegisterScreenState extends State<FaceRegisterScreen> {
  CameraController? _cameraController;
  bool _isInit = false;
  bool _isRegistering = false;
  bool _permissionDenied = false;
  ApiResult? _result;

  @override
  void initState() {
    super.initState();
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
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    setState(() => _isRegistering = true);

    try {
      final XFile picture = await _cameraController!.takePicture();

      if (!mounted) return;
      final result = await ApiService.registerFace(picture.path);

      if (!mounted) return;
      setState(() {
        _isRegistering = false;
        _result = result;
      });

    } catch (e) {
      setState(() {
        _isRegistering = false;
        _result = ApiResult(success: false, message: 'Gagal mengambil gambar: $e');
      });
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Daftarkan Wajah'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_permissionDenied) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt_outlined, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            const Text('Akses Kamera Ditolak', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _initCamera,
              child: const Text('Coba Lagi'),
            )
          ],
        ),
      );
    }

    if (_result != null) {
      final success = _result!.success;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                success ? Icons.check_circle_outline : Icons.error_outline,
                size: 80,
                color: success ? AppColors.success : AppColors.danger,
              ),
              const SizedBox(height: 24),
              Text(
                success ? 'Berhasil' : 'Gagal',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                _result!.message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  if (success) {
                    Navigator.pop(context);
                  } else {
                    setState(() {
                      _result = null;
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: Text(success ? 'Selesai' : 'Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInit) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        const SizedBox(height: 24),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.0),
          child: Text(
            'Pastikan wajah Anda berada di dalam area lingkaran merah, dengan pencahayaan yang cukup. Lepaskan kacamata dan topi.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Camera preview
              ClipRect(
                child: SizedOverflowBox(
                  size: const Size(300, 300),
                  child: Transform.scale(
                     scale: _cameraController!.value.aspectRatio,
                     child: Center(
                        child: CameraPreview(_cameraController!),
                     ),
                  ),
                ),
              ),
              // Guide circle
              Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.danger, width: 3),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: _isRegistering 
              ? const CircularProgressIndicator()
              : ElevatedButton(
                  onPressed: _takeAndRegisterFace,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                  ),
                  child: const Text('Ambil Foto & Daftarkan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
        ),
      ],
    );
  }
}
