import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/theme.dart';
import '../../providers/lecturer_provider.dart';

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
      body: SafeArea(
        child: Consumer<LecturerProvider>(
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

            return RefreshIndicator(
              onRefresh: () => provider.fetchDashboard(),
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  // Header
                  _buildHeader(provider),
                  const SizedBox(height: AppSpacing.lg),

                  // Stats Row
                  _buildStatsRow(totalCourses, totalStudents, pendingLeaves),
                  const SizedBox(height: AppSpacing.lg),

                  // Today's Classes
                  Text(
                    'Kelas Hari Ini — $today',
                    style: const TextStyle(
                      fontSize: AppFonts.h3,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  if (todayCourses.isEmpty)
                    _buildEmptyState('Tidak ada kelas hari ini', Icons.free_breakfast_outlined)
                  else
                    ...todayCourses.map((c) => _buildCourseCard(c)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(LecturerProvider provider) {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(Icons.school, color: Colors.white, size: 28),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selamat Datang,',
                      style: TextStyle(
                        fontSize: AppFonts.caption,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    Text(
                      provider.profile?.name ?? 'Dosen',
                      style: const TextStyle(
                        fontSize: AppFonts.h2,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(int courses, int students, int pendingLeaves) {
    return Row(
      children: [
        Expanded(child: _buildStatCard('Mata Kuliah', '$courses', Icons.book_outlined, AppColors.primary)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: _buildStatCard('Mahasiswa', '$students', Icons.people_outline, AppColors.accent)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: _buildStatCard('Izin Pending', '$pendingLeaves', Icons.pending_actions, AppColors.warning)),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: TextStyle(
              fontSize: AppFonts.h2,
              fontWeight: FontWeight.w800,
              color: color,
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
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(Icons.class_outlined, color: AppColors.primary),
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
                    fontWeight: FontWeight.w600,
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
                  fontWeight: FontWeight.w700,
                  color: AppColors.success,
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
          Icon(icon, size: 48, color: AppColors.textMuted),
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
            const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
            const SizedBox(height: AppSpacing.sm),
            Text('Gagal memuat data', style: const TextStyle(fontSize: AppFonts.h3, fontWeight: FontWeight.w600)),
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
