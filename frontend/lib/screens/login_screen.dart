import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import '../constants/theme.dart';
import '../services/api_service.dart';
import '../services/app_time.dart';

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
          'Silakan masuk dengan NIM dan password terlebih dahulu. Setelah itu, Anda bisa menggunakan ${_getBiometricLabel()} untuk login berikutnya.',
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
          'Gagal masuk otomatis. Silakan masuk dengan NIM dan password.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Terjadi kesalahan saat autentikasi biometrik.')),
        );
      }
    }
  }

  Future<void> _handleLogin() async {
    final nim = _nimController.text.trim();
    final password = _passwordController.text.trim();

    if (nim.isEmpty) {
      _showAlert('Peringatan', 'Masukkan NIM Anda.');
      return;
    }
    if (password.isEmpty) {
      _showAlert('Peringatan', 'Masukkan password Anda.');
      return;
    }

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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(ctx).viewInsets.bottom + 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Sheet bar
              Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.science_outlined, size: 18, color: AppColors.danger),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Time Mocker',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  if (AppTime.isMocked)
                    TextButton(
                      onPressed: () {
                        AppTime.clearMock();
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('⏱ Time mock cleared — using real system time'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      },
                      child: const Text('Reset', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                AppTime.isMocked
                    ? 'Mock aktif: ${_fmtDt(AppTime.mockValue!)}'
                    : 'Waktu sistem asli',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTime.isMocked ? AppColors.danger : AppColors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),

              // Date picker
              GestureDetector(
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
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 18, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Tanggal', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                          Text(
                            '${mockDate.day.toString().padLeft(2, '0')}/${mockDate.month.toString().padLeft(2, '0')}/${mockDate.year}',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Time picker
              GestureDetector(
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
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time, size: 18, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Waktu', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                          Text(
                            '${mockTime.hour.toString().padLeft(2, '0')}:${mockTime.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save, size: 18),
                  label: const Text('Simpan Mock Time', style: TextStyle(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    final finalMock = DateTime(
                      mockDate.year, mockDate.month, mockDate.day,
                      mockTime.hour, mockTime.minute,
                    );
                    AppTime.setMock(finalMock);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('🕐 Mock time set: ${_fmtDt(finalMock)}'),
                        backgroundColor: AppColors.danger,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
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
      onTapDown: _handleBackgroundTap,
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light.copyWith(
            statusBarColor: AppColors.primaryDark,
          ),
          child: Stack(
            children: [
              // Top decoration circles
              Positioned(
                top: -60,
                right: -40,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),
              Positioned(
                top: 60,
                left: -60,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.04),
                  ),
                ),
              ),

              // Content
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo & Title
                      FadeTransition(
                        opacity: _fadeAnim,
                        child: SlideTransition(
                          position: _slideAnim,
                          child: Column(
                            children: [
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
                              const SizedBox(height: 16),
                              const Text(
                                'Absensi Kuliah',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Masuk dengan akun mahasiswa Anda',
                                style: TextStyle(
                                  fontSize: AppFonts.caption,
                                  color: Colors.white.withValues(alpha: 0.65),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Form Card
                      FadeTransition(
                        opacity: _fadeAnim,
                        child: SlideTransition(
                          position: _slideAnim,
                          child: Container(
                            key: _formCardKey,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(AppRadius.xl),
                              boxShadow: AppShadows.medium,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // NIM Input
                                Text(
                                  'NIM',
                                  style: TextStyle(
                                    fontSize: AppFonts.caption,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _buildInputField(
                                  controller: _nimController,
                                  icon: Icons.person_outline,
                                  placeholder: 'Masukkan NIM',
                                  isFocused: _nimFocused,
                                  onFocusChange: (f) => setState(() => _nimFocused = f),
                                  keyboardType: TextInputType.number,
                                  onSubmitted: (_) => _passwordFocus.requestFocus(),
                                ),

                                const SizedBox(height: 18),

                                // Password Input
                                Text(
                                  'Password',
                                  style: TextStyle(
                                    fontSize: AppFonts.caption,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _buildInputField(
                                  controller: _passwordController,
                                  icon: Icons.lock_outline,
                                  placeholder: 'Masukkan password',
                                  isFocused: _pwFocused,
                                  onFocusChange: (f) => setState(() => _pwFocused = f),
                                  isPassword: true,
                                  focusNode: _passwordFocus,
                                  onSubmitted: (_) => _handleLogin(),
                                ),

                                const SizedBox(height: 20),

                                // Login Button
                                SizedBox(
                                  width: double.infinity,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(AppRadius.md),
                                      boxShadow: AppShadows.glow,
                                    ),
                                    child: ElevatedButton(
                                      onPressed: _isLoading ? null : () => _handleLogin(),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.75),
                                        foregroundColor: AppColors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(AppRadius.md),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: _isLoading
                                          ? const Text(
                                              'Memproses…',
                                              style: TextStyle(
                                                fontSize: AppFonts.body,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            )
                                          : const Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  'Masuk',
                                                  style: TextStyle(
                                                    fontSize: AppFonts.body,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                SizedBox(width: 8),
                                                Icon(Icons.arrow_forward, size: 18),
                                              ],
                                            ),
                                    ),
                                  ),
                                ),

                                // Biometric Login
                                if (_biometricAvailable) ...[
                                  const SizedBox(height: 20),
                                  Row(
                                    children: [
                                      const Expanded(child: Divider(color: AppColors.border)),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 14),
                                        child: Text(
                                          'atau',
                                          style: TextStyle(
                                            fontSize: AppFonts.caption,
                                            color: AppColors.textMuted,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      const Expanded(child: Divider(color: AppColors.border)),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton(
                                      onPressed: _handleBiometricLogin,
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor: AppColors.background,
                                        side: const BorderSide(
                                          color: AppColors.border,
                                          width: 1.5,
                                        ),
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(AppRadius.md),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: AppColors.primarySurface,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Icon(
                                              _getBiometricIcon(),
                                              size: 24,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            'Masuk dengan ${_getBiometricLabel()}',
                                            style: const TextStyle(
                                              fontSize: AppFonts.body,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Footer
                      Text(
                        '© 2026 Universitas Nahdlatul Ulama Sunan Giri',
                        style: TextStyle(
                          fontSize: AppFonts.small,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
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
    required IconData icon,
    required String placeholder,
    required bool isFocused,
    required ValueChanged<bool> onFocusChange,
    bool isPassword = false,
    FocusNode? focusNode,
    TextInputType? keyboardType,
    ValueChanged<String>? onSubmitted,
  }) {
    return Focus(
      onFocusChange: onFocusChange,
      child: Container(
        decoration: BoxDecoration(
          color: isFocused ? AppColors.primarySurface : AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isFocused ? AppColors.primaryLight : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              height: 48,
              child: Icon(
                icon,
                size: 18,
                color: isFocused ? AppColors.primary : AppColors.textMuted,
              ),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                keyboardType: keyboardType,
                obscureText: isPassword && !_showPassword,
                onSubmitted: onSubmitted,
                style: const TextStyle(
                  fontSize: AppFonts.body,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: placeholder,
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            if (isPassword)
              GestureDetector(
                onTap: () => setState(() => _showPassword = !_showPassword),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  child: Icon(
                    _showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 20,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
