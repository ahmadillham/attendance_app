import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../../constants/theme.dart';
import '../../providers/lecturer_provider.dart';
import '../../services/app_time.dart';
import '../../widgets/dashboard_header.dart';

/// Lecturer Dashboard — shows today's classes, quick stats, pending leaves
class LecturerDashboardScreen extends StatefulWidget {
  const LecturerDashboardScreen({super.key});

  @override
  State<LecturerDashboardScreen> createState() => _LecturerDashboardScreenState();
}

class _LecturerDashboardScreenState extends State<LecturerDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LecturerProvider>().fetchDashboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Consumer<LecturerProvider>(
        builder: (context, provider, _) {
          if (provider.isDashboardLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.dashboardError != null) {
            return _buildError(provider.dashboardError!);
          }
          final data = provider.dashboardData;
          if (data == null) return const SizedBox.shrink();

          final today = data['today'] ?? '';
          final todayCourses = data['todayCourses'] as List? ?? [];
          final totalCourses = data['totalCourses'] ?? 0;
          final totalStudents = data['totalStudents'] ?? 0;
          final pendingLeaves = data['pendingLeaveCount'] ?? 0;

          final profile = provider.profile;
          final name = profile?.name ?? 'Dosen';
          final nip = profile?.lecturerId ?? '-';
          final faculty = profile?.faculty ?? '-';

          final hour = AppTime.now().hour;
          String greeting;
          if (hour < 11) {
            greeting = 'SELAMAT PAGI';
          } else if (hour < 15) {
            greeting = 'SELAMAT SIANG';
          } else if (hour < 18) {
            greeting = 'SELAMAT SORE';
          } else {
            greeting = 'SELAMAT MALAM';
          }

          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
            ),
            child: Column(
              children: [
                DashboardHeader(
                  greeting: greeting,
                  name: name,
                  identifier: nip,
                  subtitle: faculty,
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => provider.fetchDashboard(),
                    child: ListView(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      children: [
                        // Stats Row
                        _buildStatsRow(totalCourses, totalStudents, pendingLeaves),
                        const SizedBox(height: AppSpacing.lg),

                        // Today's Classes
                        Text(
                          'Kelas Hari Ini — $today',
                          style: const TextStyle(
                            fontSize: AppFonts.h3,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),

                        if (todayCourses.isEmpty)
                          _buildEmptyState('Tidak ada kelas hari ini', Icons.free_breakfast_outlined)
                        else
                          ...todayCourses.map((c) => _buildCourseCard(c)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatsRow(int courses, int students, int pendingLeaves) {
    return Row(
      children: [
        Expanded(child: _buildStatCard('Mata Kuliah', '$courses', Icons.book_outlined)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: _buildStatCard('Mahasiswa', '$students', Icons.people_outline)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: _buildStatCard('Izin Pending', '$pendingLeaves', Icons.pending_actions)),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 22),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: const TextStyle(
              fontSize: AppFonts.h2,
              fontWeight: FontWeight.w400,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: AppFonts.small, color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCourseCard(dynamic course) {
    final schedule = course['schedule'] as Map<String, dynamic>?;
    final enrolled = course['enrolledCount'] ?? 0;
    final attendance = course['attendance'] as Map<String, dynamic>? ?? {};
    final present = attendance['present'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.borderLight,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(Icons.class_outlined, color: AppColors.textSecondary, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course['name'] ?? '',
                  style: const TextStyle(
                    fontSize: AppFonts.body,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  schedule != null
                      ? '${schedule['startTime']} - ${schedule['endTime']} • ${schedule['room']}'
                      : '-',
                  style: const TextStyle(fontSize: AppFonts.caption, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$present/$enrolled',
                style: const TextStyle(
                  fontSize: AppFonts.h3,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Text('Hadir', style: TextStyle(fontSize: AppFonts.small, color: AppColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppColors.textMuted),
          const SizedBox(height: AppSpacing.sm),
          Text(message, style: const TextStyle(color: AppColors.textMuted, fontSize: AppFonts.body)),
        ],
      ),
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.sm),
            const Text('Gagal memuat data', style: TextStyle(fontSize: AppFonts.h3, fontWeight: FontWeight.w500)),
            const SizedBox(height: AppSpacing.xs),
            Text(error, style: const TextStyle(color: AppColors.textMuted, fontSize: AppFonts.caption), textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(
              onPressed: () => context.read<LecturerProvider>().fetchDashboard(),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
