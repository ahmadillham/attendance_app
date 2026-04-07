import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/theme.dart';
import '../constants/mock_data.dart';

/// ProfileScreen — Academic info, settings, logout
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final student = mockStudent;

  void _handleChangePhoto() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ubah Foto'),
        content: const Text(
          'Fitur ini membutuhkan koneksi ke server.\n\nPada versi lengkap, Anda bisa memilih foto dari galeri atau mengambil foto baru.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  void _showChangePassword() {
    final oldPwController = TextEditingController();
    final newPwController = TextEditingController();
    final confirmPwController = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(AppRadius.xl),
              topRight: Radius.circular(AppRadius.xl),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Ubah Password',
                style: TextStyle(
                  fontSize: AppFonts.h3,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              _inputLabel('PASSWORD LAMA'),
              _inputField(oldPwController, 'Masukkan password lama'),
              _inputLabel('PASSWORD BARU'),
              _inputField(newPwController, 'Minimal 6 karakter'),
              _inputLabel('KONFIRMASI PASSWORD'),
              _inputField(confirmPwController, 'Ulangi password baru'),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    boxShadow: AppShadows.glow,
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      if (oldPwController.text.trim().isEmpty) {
                        _showAlert('Peringatan', 'Masukkan password lama.');
                        return;
                      }
                      if (newPwController.text.length < 6) {
                        _showAlert('Peringatan', 'Password baru minimal 6 karakter.');
                        return;
                      }
                      if (newPwController.text != confirmPwController.text) {
                        _showAlert('Peringatan', 'Konfirmasi password tidak cocok.');
                        return;
                      }
                      // 🔌 BACKEND: PUT /api/auth/change-password
                      Navigator.pop(ctx);
                      _showAlert('✅ Berhasil', 'Password berhasil diubah.');
                    },
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
                      'Simpan Password',
                      style: TextStyle(fontSize: AppFonts.body, fontWeight: FontWeight.w700),
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

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar'),
        content: const Text('Apakah Anda yakin ingin keluar dari aplikasi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil('/login', (_) => false);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }

  void _showAlert(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final attendancePercent = (student.attendanceSummary.present / student.attendanceSummary.total * 100).round();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: AppColors.primaryDark,
        ),
        child: Column(
          children: [
            // Header + Avatar
            Container(
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(AppRadius.xl),
                  bottomRight: Radius.circular(AppRadius.xl),
                ),
              ),
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 10,
                bottom: 28,
                left: 20,
                right: 20,
              ),
              child: Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _handleChangePhoto,
                      child: Stack(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(26),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 3,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                student.avatarInitials,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.white,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: -2,
                            right: -2,
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: AppColors.accent,
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(color: AppColors.primary, width: 2),
                              ),
                              child: const Icon(Icons.camera_alt, size: 12, color: AppColors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      student.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        student.studentId,
                        style: const TextStyle(
                          fontSize: AppFonts.small,
                          fontWeight: FontWeight.w700,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Scrollable Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Academic Info
                    _sectionLabel('INFORMASI AKADEMIK'),
                    _infoCard([
                      _InfoRowData(Icons.school_outlined, 'Program Studi', student.department),
                      _InfoRowData(Icons.business_outlined, 'Fakultas', student.faculty),
                      _InfoRowData(Icons.layers_outlined, 'Semester', 'Semester ${student.semester}'),
                      _InfoRowData(Icons.bar_chart_outlined, 'Kehadiran', '$attendancePercent%', isLast: true),
                    ]),

                    _sectionLabel('INFORMASI KONTAK'),
                    _infoCard([
                      _InfoRowData(Icons.mail_outlined, 'Email', student.email),
                      _InfoRowData(Icons.phone_outlined, 'Telepon', student.phone, isLast: true),
                    ]),

                    _sectionLabel('PENGATURAN'),

                    // Change Photo
                    _actionCard(
                      icon: Icons.image_outlined,
                      iconBg: AppColors.primarySurface,
                      iconColor: AppColors.primary,
                      label: 'Ubah Foto Profil',
                      onTap: _handleChangePhoto,
                    ),

                    // Change Password
                    _actionCard(
                      icon: Icons.key_outlined,
                      iconBg: AppColors.warningSurface,
                      iconColor: AppColors.warning,
                      label: 'Ubah Password',
                      onTap: _showChangePassword,
                    ),

                    const SizedBox(height: 4),

                    // Logout
                    _actionCard(
                      icon: Icons.logout,
                      iconBg: AppColors.dangerSurface,
                      iconColor: AppColors.danger,
                      label: 'Keluar',
                      labelColor: AppColors.danger,
                      chevronColor: AppColors.danger,
                      onTap: _handleLogout,
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _infoCard(List<_InfoRowData> rows) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: rows.map((row) => _infoRow(row)).toList(),
      ),
    );
  }

  Widget _infoRow(_InfoRowData data) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: data.isLast
            ? null
            : const Border(bottom: BorderSide(color: AppColors.borderLight, width: 1)),
      ),
      child: Row(
        children: [
          Icon(data.icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.label,
                  style: const TextStyle(
                    fontSize: AppFonts.small,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  data.value,
                  style: const TextStyle(
                    fontSize: AppFonts.body,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    Color labelColor = AppColors.textPrimary,
    Color chevronColor = AppColors.textMuted,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: AppFonts.body,
                  fontWeight: FontWeight.w600,
                  color: labelColor,
                ),
              ),
            ),
            Icon(Icons.chevron_right, size: 16, color: chevronColor),
          ],
        ),
      ),
    );
  }

  Widget _inputLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _inputField(TextEditingController controller, String placeholder) {
    return TextField(
      controller: controller,
      obscureText: true,
      style: const TextStyle(
        fontSize: AppFonts.body,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: placeholder,
        hintStyle: const TextStyle(color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

class _InfoRowData {
  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  const _InfoRowData(this.icon, this.label, this.value, {this.isLast = false});
}
