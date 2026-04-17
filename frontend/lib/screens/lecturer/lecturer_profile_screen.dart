import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/theme.dart';
import '../../providers/lecturer_provider.dart';
import '../../services/api_service.dart';
import 'course_attendance_screen.dart';

/// Lecturer Profile — shows NIP, courses, change password, logout
class LecturerProfileScreen extends StatefulWidget {
  const LecturerProfileScreen({super.key});

  @override
  State<LecturerProfileScreen> createState() => _LecturerProfileScreenState();
}

class _LecturerProfileScreenState extends State<LecturerProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<LecturerProvider>();
      provider.fetchProfile();
      provider.fetchCourses();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Consumer<LecturerProvider>(
        builder: (context, provider, _) {
          if (provider.isProfileLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final profile = provider.profile;
          if (profile == null) {
            return const Center(child: Text('Gagal memuat profil'));
          }

          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                // Profile Card
                _buildProfileCard(profile),
                const SizedBox(height: AppSpacing.lg),

                // Courses taught
                const Text(
                  'Mata Kuliah yang Diampu',
                  style: TextStyle(
                    fontSize: AppFonts.h3,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ...provider.courses.map((c) => _buildCourseItem(c)),
                const SizedBox(height: AppSpacing.lg),

                // Actions
                _buildActionTile(
                  icon: Icons.lock_outline,
                  title: 'Ganti Password',
                  onTap: () => _showChangePasswordDialog(),
                ),
                const SizedBox(height: AppSpacing.sm),
                _buildActionTile(
                  icon: Icons.logout,
                  title: 'Keluar',
                  color: AppColors.danger,
                  onTap: () => _handleLogout(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileCard(dynamic profile) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.glow,
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, size: 40, color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            profile.name,
            style: const TextStyle(
              fontSize: AppFonts.h2,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'NIP: ${profile.lecturerId}',
            style: TextStyle(
              fontSize: AppFonts.body,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Info chips
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            alignment: WrapAlignment.center,
            children: [
              _infoChip(Icons.business, profile.department),
              _infoChip(Icons.school, profile.faculty),
              _infoChip(Icons.email_outlined, profile.email),
              if (profile.phone != null) _infoChip(Icons.phone, profile.phone!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(fontSize: AppFonts.caption, color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseItem(Map<String, dynamic> course) {
    final enrollments = course['enrollments'] as List? ?? [];
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.card,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Center(
            child: Text(
              course['code'] ?? '',
              style: const TextStyle(
                fontSize: AppFonts.small,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        title: Text(
          course['name'] ?? '',
          style: const TextStyle(fontSize: AppFonts.body, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${enrollments.length} mahasiswa',
          style: const TextStyle(fontSize: AppFonts.caption, color: AppColors.textMuted),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CourseAttendanceScreen(
                courseId: course['id'],
                courseName: course['name'] ?? '',
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color color = AppColors.textPrimary,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.card,
      ),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        trailing: Icon(Icons.chevron_right, color: color.withValues(alpha: 0.5)),
        onTap: onTap,
      ),
    );
  }

  void _showChangePasswordDialog() {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ganti Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password Lama',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: newCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password Baru',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              Navigator.pop(ctx);
              final result = await ApiService.changeLecturerPassword(oldCtrl.text, newCtrl.text);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result.message),
                    backgroundColor: result.success ? AppColors.success : AppColors.danger,
                  ),
                );
              }
            },
            child: const Text('Simpan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar'),
        content: const Text('Apakah Anda yakin ingin keluar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ApiService.clearToken();
              await ApiService.clearSavedCredentials();
              if (mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
              }
            },
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }
}
