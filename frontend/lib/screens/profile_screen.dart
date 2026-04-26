import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../constants/theme.dart';
import '../constants/mock_data.dart';
import '../services/api_service.dart';
import '../providers/app_provider.dart';
import '../widgets/section_label.dart';

/// ProfileScreen — Academic info, settings, logout
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().fetchProfile();
    });
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
                  fontWeight: FontWeight.w600,
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
                child: ElevatedButton(
                  onPressed: () async {
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
                    final error = await ApiService.changePassword(
                      oldPwController.text.trim(),
                      newPwController.text,
                    );
                    if (!context.mounted) return;
                    Navigator.pop(ctx);
                    if (error == null) {
                      _showAlert('✅ Berhasil', 'Password berhasil diubah.');
                    } else {
                      _showAlert('❌ Gagal', error);
                    }
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
                    style: TextStyle(fontSize: AppFonts.body, fontWeight: FontWeight.w500),
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
            onPressed: () async {
              Navigator.pop(ctx);
              await ApiService.clearToken();
              if (!context.mounted) return;
              context.read<AppProvider>().clearData();
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
    final provider = context.watch<AppProvider>();
    final student = provider.studentProfile ?? mockStudent;
    final attendancePercent = student.attendanceSummary.percentage;

    if (provider.isLoadingProfile && provider.studentProfile == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
        ),
        child: Column(
          children: [
            // Header + Avatar
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(AppRadius.xl),
                  bottomRight: Radius.circular(AppRadius.xl),
                ),
              ),
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 12,
                bottom: 24,
                left: 20,
                right: 20,
              ),
              child: Center(
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_outline, size: 36, color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      student.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      student.studentId,
                      style: TextStyle(
                        fontSize: AppFonts.caption,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.7),
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
                    const SectionLabel('INFORMASI AKADEMIK'),
                    _infoCard([
                      _InfoRowData(Icons.school_outlined, 'Program Studi', student.department),
                      _InfoRowData(Icons.business_outlined, 'Fakultas', student.faculty),
                      _InfoRowData(Icons.layers_outlined, 'Semester', 'Semester ${student.semester}', isLast: true),
                    ]),

                    // Attendance Ring Card
                    const SectionLabel('REKAP KEHADIRAN'),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        boxShadow: AppShadows.card,
                      ),
                      child: Row(
                        children: [
                          // Circular Progress
                          SizedBox(
                            width: 72,
                            height: 72,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 72,
                                  height: 72,
                                  child: CircularProgressIndicator(
                                    value: attendancePercent / 100.0,
                                    strokeWidth: 6,
                                    backgroundColor: AppColors.borderLight,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      attendancePercent >= 75
                                          ? AppColors.success
                                          : attendancePercent >= 50
                                              ? AppColors.warning
                                              : AppColors.danger,
                                    ),
                                    strokeCap: StrokeCap.round,
                                  ),
                                ),
                                Text(
                                  '$attendancePercent%',
                                  style: const TextStyle(
                                    fontSize: AppFonts.h3,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          // Stats breakdown
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _attendanceStat('Hadir', student.attendanceSummary.present),
                                const SizedBox(height: 8),
                                _attendanceStat('Absen', student.attendanceSummary.absent),
                                const SizedBox(height: 8),
                                _attendanceStat('Izin', student.attendanceSummary.leave),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SectionLabel('INFORMASI KONTAK'),
                    _infoCard([
                      _InfoRowData(Icons.mail_outlined, 'Email', student.email),
                      _InfoRowData(Icons.phone_outlined, 'Telepon', student.phone, isLast: true),
                    ]),

                    const SectionLabel('PENGATURAN'),

                    // Face Registration
                    _actionCard(
                      icon: Icons.face_retouching_natural,
                      label: 'Daftarkan Wajah (FaceID)',
                      onTap: () => Navigator.pushNamed(context, '/face-register'),
                    ),

                    // Change Password
                    _actionCard(
                      icon: Icons.key_outlined,
                      label: 'Ubah Password',
                      onTap: _showChangePassword,
                    ),

                    const SizedBox(height: 4),

                    // Logout
                    _actionCard(
                      icon: Icons.logout,
                      label: 'Keluar',
                      labelColor: AppColors.danger,
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
          Icon(data.icon, size: 18, color: AppColors.textMuted),
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
                    fontWeight: FontWeight.w400,
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
    required String label,
    Color labelColor = AppColors.textPrimary,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(icon, size: 20, color: labelColor == AppColors.danger ? AppColors.danger : AppColors.textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: AppFonts.body,
                      fontWeight: FontWeight.w400,
                      color: labelColor,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, size: 16, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _attendanceStat(String label, int value) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: AppColors.textPrimary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: AppFonts.caption,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          '$value',
          style: const TextStyle(
            fontSize: AppFonts.body,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _inputLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppColors.textMuted,
          letterSpacing: 0.8,
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
