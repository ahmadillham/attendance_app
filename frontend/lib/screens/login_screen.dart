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

  static const _mahasiswaList = [
    {'name': 'Ahmad Bahrudin', 'id': '241101052'},
    {'name': 'Chamelia Qolbu', 'id': '241101033'},
    {'name': 'Moris Gede', 'id': '241101061'},
  ];

  static const _dosenList = [
    {'name': 'Dr. Mivan Ariful', 'id': '198501012001'},
    {'name': 'M. Jauhar Fikri', 'id': '198501012002'},
    {'name': 'Guruh Putro D', 'id': '198501012003'},
    {'name': 'Zakki Alawi', 'id': '198501012004'},
    {'name': 'Dwi Issadari', 'id': '198501012005'},
    {'name': 'Mula Agung', 'id': '198501012006'},
    {'name': 'Afnil Efan Pajri', 'id': '198501012007'},
  ];

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
            padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.viewInsetsOf(ctx).bottom + 32),
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
        resizeToAvoidBottomInset: false,
        backgroundColor: AppColors.primary,
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
          ),
          child: Column(
            children: [
              // Blue Header Area (1/3 of screen)
              Expanded(
                flex: 1,
                child: RepaintBoundary(
                child: Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.paddingOf(context).top + 16,
                  left: 24,
                  right: 24,
                ),
                width: double.infinity,
                alignment: Alignment.center,
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Text(
                              'Shusseki',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                letterSpacing: 1.0,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.school, color: Colors.white, size: 32),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: _showTimeMockerModal,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.access_time, color: AppColors.white),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => _showQuickLoginSheet(context),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.person, color: AppColors.white),
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

              // White Bottom Sheet Area (2/3 of screen)
              Expanded(
                flex: 2,
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(28, 40, 28, 32),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight - 72, // subtract top and bottom padding
                            ),
                            child: FadeTransition(
                              opacity: _fadeAnim,
                              child: SlideTransition(
                                position: _slideAnim,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                              // Form Area
                              Container(
                                key: _formCardKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 10),
                                    const Text(
                                      'Sign In',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF333333),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 36),
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
                                    Container(
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primary.withValues(alpha: 0.3),
                                            blurRadius: 12,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: ElevatedButton(
                                        onPressed: _isLoading ? null : () => _handleLogin(),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.75),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 18),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
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
                                                'Sign In',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                      ),
                                    ),
                                    const SizedBox(height: 24),



                                    if (_biometricAvailable) ...[
                                      const SizedBox(height: 32),
                                      Center(
                                        child: InkWell(
                                          onTap: _handleBiometricLogin,
                                          borderRadius: BorderRadius.circular(16),
                                          child: Container(
                                            width: 56,
                                            height: 56,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(16),
                                              border: Border.all(color: const Color(0xFFE0E0E0)),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.05),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: Icon(
                                              _getBiometricIcon(),
                                              size: 28,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],

                                    const SizedBox(height: 48),


                                    const KeyboardSpacer(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
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
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF555555),
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
            fontSize: 15,
            color: Color(0xFF333333),
            fontWeight: FontWeight.w400,
          ),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: const TextStyle(color: Color(0xFFBDBDBD), fontWeight: FontWeight.w400),
            filled: false,
            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: hasError ? AppColors.danger : const Color(0xFFE0E0E0), width: hasError ? 2 : 1),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: hasError ? AppColors.danger : AppColors.primary, width: 2),
            ),
            suffixIcon: isPassword
                ? GestureDetector(
                    onTap: () => setState(() => _showPassword = !_showPassword),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Icon(
                        _showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 20,
                        color: const Color(0xFFBDBDBD),
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



  void _showQuickLoginSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDDDDD),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Row(
                  children: [
                    Icon(Icons.flash_on, color: AppColors.primary, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Quick Login',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF333333),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFF0F0F0)),
              // Mahasiswa Section
              _buildQuickLoginSection(
                ctx: ctx,
                icon: Icons.school_outlined,
                title: 'Mahasiswa',
                items: _mahasiswaList,
              ),
              const Divider(height: 1, indent: 20, endIndent: 20, color: Color(0xFFF0F0F0)),
              // Dosen Section
              _buildQuickLoginSection(
                ctx: ctx,
                icon: Icons.person_outline,
                title: 'Dosen',
                items: _dosenList,
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickLoginSection({
    required BuildContext ctx,
    required IconData icon,
    required String title,
    required List<Map<String, String>> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
          child: Row(
            children: [
              Icon(icon, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        ...items.map((item) {
          return InkWell(
            onTap: () {
              Navigator.pop(ctx);
              _nimController.text = item['id']!;
              _passwordController.text = 'Password123';
              _handleLogin();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      item['name']!.substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['name']!,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF333333),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item['id']!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFFCCCCCC)),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class KeyboardSpacer extends StatelessWidget {
  const KeyboardSpacer({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: MediaQuery.viewInsetsOf(context).bottom);
  }
}
