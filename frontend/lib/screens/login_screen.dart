import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import '../constants/theme.dart';
import '../services/api_service.dart';
import '../services/app_time.dart';
import '../widgets/app_alert.dart';

/// LoginScreen — Modern Clean Design
/// ─────────────────────────────────────────────
/// NIM + Password login with biometric (fingerprint/face) auth.
///
/// 🔌 BACKEND INTEGRATION POINT:
///    Replace the mock validation below with a real API call:
///      POST /api/auth/login { nim, password }
///    Store the JWT token in SharedPreferences / FlutterSecureStorage.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _nimController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _showPassword = false;
  bool _isLoading = false;
  bool _nimFocused = false;
  String? _nimError;
  String? _pwError;
  bool _pwFocused = false;
  bool _biometricAvailable = false;
  String? _biometricType; // 'fingerprint' | 'face' | 'iris'

  // Time Mocker trigger: 5 rapid background taps
  int _bgTapCount = 0;
  DateTime? _lastBgTap;
  final GlobalKey _formCardKey = GlobalKey();

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _animController.forward();
    _checkBiometric();
  }

  @override
  void dispose() {
    _animController.dispose();
    _nimController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _checkBiometric() async {
    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      if (isAvailable && isDeviceSupported) {
        final types = await _localAuth.getAvailableBiometrics();
        setState(() {
          _biometricAvailable = true;
          if (types.contains(BiometricType.fingerprint)) {
            _biometricType = 'fingerprint';
          } else if (types.contains(BiometricType.face)) {
            _biometricType = 'face';
          } else if (types.contains(BiometricType.iris)) {
            _biometricType = 'iris';
          } else if (types.isNotEmpty) {
            _biometricType = 'fingerprint';
          }
        });
      }
    } catch (e) {
      debugPrint('Biometric check error: $e');
    }
  }

  IconData _getBiometricIcon() {
    switch (_biometricType) {
      case 'face':
        return Icons.face;
      case 'iris':
        return Icons.visibility_outlined;
      default:
        return Icons.fingerprint;
    }
  }

  String _getBiometricLabel() {
    switch (_biometricType) {
      case 'face':
        return 'Face ID';
      case 'iris':
        return 'Iris';
      default:
        return 'Sidik Jari';
    }
  }

  Future<void> _handleBiometricLogin() async {
    // Check if saved credentials exist from a previous NIM+password login
    final hasCredentials = await ApiService.hasSavedCredentials();
    if (!hasCredentials) {
      if (mounted) {
        _showAlert(
          'Login Diperlukan',
          'Silakan masuk dengan NIM/NIDN dan password terlebih dahulu. Setelah itu, Anda bisa menggunakan ${_getBiometricLabel()} untuk login berikutnya.',
        );
      }
      return;
    }

    try {
      final result = await _localAuth.authenticate(
        localizedReason: 'Masuk dengan ${_getBiometricLabel()}',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
      if (!result || !mounted) return;

      // Re-authenticate with the backend using saved credentials
      setState(() => _isLoading = true);
      final role = await ApiService.loginWithSavedCredentials();
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (role != null) {
        final route = role == 'LECTURER' ? '/lecturer-main' : '/main';
        Navigator.of(context).pushReplacementNamed(route);
      } else {
        _showAlert(
          'Sesi Habis',
          'Gagal masuk otomatis. Silakan masuk dengan NIM/NIDN dan password.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).clearSnackBars();
        AppAlert.toast(
          context,
          message: 'Terjadi kesalahan saat autentikasi biometrik.',
          type: AlertType.error,
        );
      }
    }
  }

  Future<void> _handleLogin() async {
    final nim = _nimController.text.trim();
    final password = _passwordController.text.trim();

    // Inline validation
    bool hasError = false;
    setState(() {
      _nimError = null;
      _pwError = null;
    });

    if (nim.isEmpty) {
      setState(() => _nimError = 'NIM / NIDN tidak boleh kosong');
      hasError = true;
    }
    if (password.isEmpty) {
      setState(() => _pwError = 'Password tidak boleh kosong');
      hasError = true;
    }
    if (hasError) return;

    setState(() => _isLoading = true);

    try {
      final role = await ApiService.login(nim, password);
      if (!mounted) return;
      setState(() => _isLoading = false);

      final route = role == 'LECTURER' ? '/lecturer-main' : '/main';
      Navigator.of(context).pushReplacementNamed(route);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showAlert('Login Gagal', e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _showAlert(String title, String message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppShadows.medium,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.dangerSurface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 32,
                color: AppColors.danger,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: AppFonts.h3,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: AppFonts.body,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Mengerti',
                  style: TextStyle(fontSize: AppFonts.body, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Handle background taps for hidden Time Mocker trigger.
  /// Only taps on the empty background count — not on the form card.
  void _handleBackgroundTap(TapDownDetails details) {
    // Check if tap landed inside the form card
    final formBox = _formCardKey.currentContext?.findRenderObject() as RenderBox?;
    if (formBox != null && formBox.hasSize) {
      final formPos = formBox.localToGlobal(Offset.zero);
      final formRect = formPos & formBox.size;
      if (formRect.contains(details.globalPosition)) {
        return; // Tap was on the form card — ignore
      }
    }

    final now = DateTime.now(); // real system time for tap timing
    if (_lastBgTap != null && now.difference(_lastBgTap!).inMilliseconds > 800) {
      _bgTapCount = 0; // Reset if too slow
    }
    _lastBgTap = now;
    _bgTapCount++;

    if (_bgTapCount >= 5) {
      _bgTapCount = 0;
      _showTimeMockerModal();
    }
  }

  /// Show the Time Mocker configuration modal.
  void _showTimeMockerModal() {
    DateTime mockDate = AppTime.isMocked ? AppTime.mockValue! : DateTime.now();
    TimeOfDay mockTime = TimeOfDay(hour: mockDate.hour, minute: mockDate.minute);
    const dayLabels = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
    const monthLabels = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final dateLabel = '${dayLabels[mockDate.weekday % 7]}, ${mockDate.day} ${monthLabels[mockDate.month - 1]} ${mockDate.year}';
          final timeLabel = '${mockTime.hour.toString().padLeft(2, '0')}:${mockTime.minute.toString().padLeft(2, '0')}';

          return Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(ctx).viewInsets.bottom + 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 32, height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Title row
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 20, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    const Text(
                      'Time Mocker',
                      style: TextStyle(
                        fontSize: AppFonts.h3,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    if (AppTime.isMocked)
                      GestureDetector(
                        onTap: () {
                          AppTime.clearMock();
                          Navigator.pop(ctx);
                          AppAlert.toast(
                            context,
                            message: 'Waktu dikembalikan ke sistem',
                            type: AlertType.info,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Reset',
                            style: TextStyle(
                              fontSize: AppFonts.small,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                // Status indicator
                if (AppTime.isMocked) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Mock aktif: ${_fmtDt(AppTime.mockValue!)}',
                      style: const TextStyle(
                        fontSize: AppFonts.small,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Date & Time in a single row
                Row(
                  children: [
                    // Date
                    Expanded(
                      flex: 3,
                      child: GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: mockDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setSheetState(() => mockDate = DateTime(
                              picked.year, picked.month, picked.day,
                              mockTime.hour, mockTime.minute,
                            ));
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.borderLight),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Tanggal', style: TextStyle(fontSize: AppFonts.small, color: AppColors.textMuted)),
                              const SizedBox(height: 4),
                              Text(
                                dateLabel,
                                style: const TextStyle(fontSize: AppFonts.caption, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    // Time
                    Expanded(
                      flex: 2,
                      child: GestureDetector(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: ctx,
                            initialTime: mockTime,
                          );
                          if (picked != null) {
                            setSheetState(() {
                              mockTime = picked;
                              mockDate = DateTime(
                                mockDate.year, mockDate.month, mockDate.day,
                                picked.hour, picked.minute,
                              );
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.borderLight),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Waktu', style: TextStyle(fontSize: AppFonts.small, color: AppColors.textMuted)),
                              const SizedBox(height: 4),
                              Text(
                                timeLabel,
                                style: const TextStyle(fontSize: AppFonts.caption, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Apply button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final finalMock = DateTime(
                        mockDate.year, mockDate.month, mockDate.day,
                        mockTime.hour, mockTime.minute,
                      );
                      AppTime.setMock(finalMock);
                      Navigator.pop(ctx);
                      AppAlert.toast(
                        context,
                        message: 'Mock time: ${_fmtDt(finalMock)}',
                        type: AlertType.success,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: const Text('Terapkan', style: TextStyle(fontSize: AppFonts.body, fontWeight: FontWeight.w500)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _fmtDt(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        FocusScope.of(context).unfocus();
        _handleBackgroundTap(details);
      },
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
          ),
          child: Column(
            children: [
              // Blue Header Area
              Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 40,
                  bottom: 30,
                  left: 24,
                  right: 24,
                ),
                width: double.infinity,
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Column(
                      children: [
                        // Logo
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          child: const Icon(
                            Icons.school,
                            size: 32,
                            color: AppColors.white,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Absensi Kuliah',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: AppColors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sistem Presensi Pintar',
                          style: TextStyle(
                            fontSize: AppFonts.caption,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withValues(alpha: 0.8),
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // White Bottom Sheet Area
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(36),
                      topRight: Radius.circular(36),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(36),
                      topRight: Radius.circular(36),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(28, 40, 28, 32),
                      child: FadeTransition(
                        opacity: _fadeAnim,
                        child: SlideTransition(
                          position: _slideAnim,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Form Area
                              Container(
                                key: _formCardKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // NIM / NIDN Input
                                    _buildInputField(
                                      controller: _nimController,
                                      label: 'NIM / NIDN',
                                      placeholder: 'Masukkan NIM atau NIDN',
                                      isFocused: _nimFocused,
                                      onFocusChange: (f) {
                                        setState(() => _nimFocused = f);
                                        if (f) setState(() => _nimError = null);
                                      },
                                      keyboardType: TextInputType.number,
                                      onSubmitted: (_) => _passwordFocus.requestFocus(),
                                      errorText: _nimError,
                                    ),
                                    const SizedBox(height: 20),

                                    // Password Input
                                    _buildInputField(
                                      controller: _passwordController,
                                      label: 'Password',
                                      placeholder: '••••••••',
                                      isFocused: _pwFocused,
                                      onFocusChange: (f) {
                                        setState(() => _pwFocused = f);
                                        if (f) setState(() => _pwError = null);
                                      },
                                      isPassword: true,
                                      focusNode: _passwordFocus,
                                      onSubmitted: (_) => _handleLogin(),
                                      errorText: _pwError,
                                    ),
                                    const SizedBox(height: 32),

                                    // Login Button
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: _isLoading ? null : () => _handleLogin(),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.75),
                                          foregroundColor: AppColors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 18),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                          elevation: 0,
                                        ),
                                        child: _isLoading
                                            ? const SizedBox(
                                                height: 20,
                                                width: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : const Text(
                                                'Masuk',
                                                style: TextStyle(
                                                  fontSize: AppFonts.body,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                      ),
                                    ),
                                    const SizedBox(height: 24),

                                    // Biometric OR line
                                    if (_biometricAvailable) ...[
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          Expanded(child: Divider(color: AppColors.borderLight)),
                                          const Padding(
                                            padding: EdgeInsets.symmetric(horizontal: 16),
                                            child: Text(
                                              'Atau masuk dengan',
                                              style: TextStyle(
                                                fontSize: AppFonts.caption,
                                                color: AppColors.textMuted,
                                              ),
                                            ),
                                          ),
                                          Expanded(child: Divider(color: AppColors.borderLight)),
                                        ],
                                      ),
                                      const SizedBox(height: 24),

                                      // Biometric Button
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          InkWell(
                                            onTap: _handleBiometricLogin,
                                            borderRadius: BorderRadius.circular(16),
                                            child: Container(
                                              width: 64,
                                              height: 64,
                                              decoration: BoxDecoration(
                                                color: AppColors.background,
                                                borderRadius: BorderRadius.circular(16),
                                                border: Border.all(color: AppColors.borderLight),
                                              ),
                                              child: Icon(
                                                _getBiometricIcon(),
                                                size: 32,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],

                                    const SizedBox(height: 48),

                                    // Dev Mode: Quick Login
                                    Center(
                                      child: Column(
                                        children: [
                                          const Text(
                                            'Dev Mode: Quick Login',
                                            style: TextStyle(
                                              fontSize: AppFonts.caption,
                                              color: AppColors.textMuted,
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              _buildRoleDropdown(
                                                title: 'Mahasiswa',
                                                items: [
                                                  {'name': 'Ahmad Bahrudin', 'id': '241101052'},
                                                ],
                                              ),
                                              const SizedBox(width: 12),
                                              _buildRoleDropdown(
                                                title: 'Dosen',
                                                items: [
                                                  {'name': 'Dr. Mivan Ariful', 'id': '198501012001'},
                                                  {'name': 'M. Jauhar Fikri', 'id': '198501012002'},
                                                  {'name': 'Guruh Putro D', 'id': '198501012003'},
                                                  {'name': 'Zakki Alawi', 'id': '198501012004'},
                                                  {'name': 'Dwi Issadari', 'id': '198501012005'},
                                                  {'name': 'Mula Agung', 'id': '198501012006'},
                                                  {'name': 'Afnil Efan Pajri', 'id': '198501012007'},
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String placeholder,
    required bool isFocused,
    required ValueChanged<bool> onFocusChange,
    bool isPassword = false,
    FocusNode? focusNode,
    TextInputType? keyboardType,
    ValueChanged<String>? onSubmitted,
    String? errorText,
  }) {
    final bool hasError = errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: AppFonts.caption,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          obscureText: isPassword && !_showPassword,
          onSubmitted: onSubmitted,
          style: const TextStyle(
            fontSize: AppFonts.body,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w400),
            filled: true,
            fillColor: AppColors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: hasError ? AppColors.danger : AppColors.borderLight, width: hasError ? 2 : 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: hasError ? AppColors.danger : AppColors.primary, width: 2),
            ),
            suffixIcon: isPassword
                ? GestureDetector(
                    onTap: () => setState(() => _showPassword = !_showPassword),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Icon(
                        _showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 22,
                        color: AppColors.textMuted,
                      ),
                    ),
                  )
                : null,
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 6),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 14, color: AppColors.danger),
                const SizedBox(width: 4),
                Text(
                  errorText,
                  style: const TextStyle(
                    fontSize: AppFonts.small,
                    color: AppColors.danger,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildRoleDropdown({required String title, required List<Map<String, String>> items}) {
    return PopupMenuButton<String>(
      onSelected: (String id) {
        _nimController.text = id;
        _passwordController.text = 'Password123';
        _handleLogin();
      },
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (BuildContext context) {
        return items.map((item) {
          return PopupMenuItem<String>(
            value: item['id'],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name']!,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  item['id']!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }).toList();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }
}
