import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../constants/theme.dart';
import '../constants/mock_data.dart';
import '../providers/app_provider.dart';

/// HistoryScreen — Attendance history per course
const _statusMap = {
  'present': {'label': 'Hadir', 'color': Color(0xFF4CAF7D), 'bg': Color(0xFFEDF7F1), 'icon': Icons.check_circle_outline},
  'absent': {'label': 'Absen', 'color': Color(0xFFE5574F), 'bg': Color(0xFFFDEDEC), 'icon': Icons.cancel_outlined},
  'leave': {'label': 'Izin', 'color': Color(0xFFE5A84B), 'bg': Color(0xFFFDF5E9), 'icon': Icons.description_outlined},
};

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().fetchHistoryData();
    });
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
      const days = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];
      return '${days[date.weekday % 7]}, ${date.day} ${months[date.month - 1]}';
    } catch (_) {
      return dateStr;
    }
  }


  void _showCourseDetail(BuildContext context, CourseAttendance course) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.9,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(AppRadius.xl),
              topRight: Radius.circular(AppRadius.xl),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sheet bar
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
              Text(
                course.subject,
                style: const TextStyle(
                  fontSize: AppFonts.h3,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                course.lecturer,
                style: const TextStyle(
                  fontSize: AppFonts.caption,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 16),

              // Records list
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: course.records.length,
                  itemBuilder: (_, i) {
                    final record = course.records[i];
                    final st = _statusMap[record.status]!;
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: AppColors.borderLight, width: 1),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: AppColors.borderLight,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    'P${record.meeting}',
                                    style: const TextStyle(
                                      fontSize: AppFonts.small,
                                      fontWeight: FontWeight.w400,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _formatDate(record.date),
                                style: const TextStyle(
                                  fontSize: AppFonts.caption,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: st['bg'] as Color,
                              borderRadius: BorderRadius.circular(AppRadius.full),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(st['icon'] as IconData, size: 14, color: st['color'] as Color),
                                const SizedBox(width: 4),
                                Text(
                                  st['label'] as String,
                                  style: TextStyle(
                                    fontSize: AppFonts.small,
                                    fontWeight: FontWeight.w400,
                                    color: st['color'] as Color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Close button
              const SizedBox(height: 16),
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
                    'Tutup',
                    style: TextStyle(fontSize: AppFonts.body, fontWeight: FontWeight.w400),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Builder(
        builder: (context) {
          if (provider.isLoadingHistory && provider.attendanceHistory == null) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          } else if (provider.historyError != null && provider.attendanceHistory == null) {
             return Center(child: Text('Error: ${provider.historyError}'));
          } else if (provider.attendanceHistory == null || provider.attendanceHistory!.isEmpty) {
             return const Center(child: Text('Tidak ada riwayat kehadiran'));
          }

          final historyList = provider.attendanceHistory!;

          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
            ),
            child: Column(
          children: [
            // Header
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
                top: MediaQuery.of(context).padding.top + 10,
                bottom: 20,
                left: 20,
                right: 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Riwayat Absensi',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w400,
                      color: AppColors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${historyList.length} mata kuliah',
                    style: TextStyle(
                      fontSize: AppFonts.caption,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),

            // Course list
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () => provider.fetchHistoryData(forceRefresh: true),
                child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  children: [
                    ...historyList.map((course) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          boxShadow: AppShadows.card,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _showCourseDetail(context, course),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Course name & lecturer
                              Text(
                                course.subject,
                                style: const TextStyle(
                                  fontSize: AppFonts.body,
                                  fontWeight: FontWeight.w400,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                course.lecturer,
                                style: const TextStyle(
                                  fontSize: AppFonts.small,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Stacked Progress Bar
                              Container(
                                height: 6,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: AppColors.border,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Row(
                                children: [
                                  if (course.presentCount > 0)
                                    Expanded(
                                      flex: course.presentCount,
                                      child: Container(color: AppColors.success),
                                    ),
                                  if (course.leaveCount > 0)
                                    Expanded(
                                      flex: course.leaveCount,
                                      child: Container(color: AppColors.warning),
                                    ),
                                  if (course.absentCount > 0)
                                    Expanded(
                                      flex: course.absentCount,
                                      child: Container(color: AppColors.danger),
                                    ),
                                ],
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Mini stats
                              Row(
                                children: [
                                  _miniStat(AppColors.success, 'Hadir ${course.presentCount}'),
                                  const SizedBox(width: 12),
                                  _miniStat(AppColors.danger, 'Absen ${course.absentCount}'),
                                  const SizedBox(width: 12),
                                  _miniStat(AppColors.warning, 'Izin ${course.leaveCount}'),
                                  const Spacer(),
                                  const Icon(Icons.chevron_right, size: 16, color: AppColors.textMuted),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                    const SizedBox(height: 20),
                  ],
                ),
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

  Widget _miniStat(Color dotColor, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: AppFonts.small,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}
