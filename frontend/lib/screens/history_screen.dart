import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../constants/theme.dart';
import '../constants/mock_data.dart';
import '../services/api_service.dart';
import '../providers/app_provider.dart';

/// HistoryScreen — Attendance history per course
const _statusMap = {
  'present': {'label': 'Hadir', 'color': Color(0xFF14B8A6), 'bg': Color(0xFFCCFBF1), 'icon': Icons.check_circle},
  'absent': {'label': 'Absen', 'color': Color(0xFFEF4444), 'bg': Color(0xFFFEE2E2), 'icon': Icons.cancel},
  'leave': {'label': 'Izin', 'color': Color(0xFFF59E0B), 'bg': Color(0xFFFEF3C7), 'icon': Icons.description},
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

  Map<String, int> _getCourseSummary(CourseAttendance course) {
    final present = course.records.where((r) => r.status == 'present').length;
    final absent = course.records.where((r) => r.status == 'absent').length;
    final leave = course.records.where((r) => r.status == 'leave').length;
    final percent = (present / course.records.length * 100).round();
    return {'present': present, 'absent': absent, 'leave': leave, 'percent': percent};
  }

  String _formatDate(String dateStr) {
    final date = DateTime.parse(dateStr);
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    const days = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];
    return '${days[date.weekday % 7]}, ${date.day} ${months[date.month - 1]}';
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
                  fontWeight: FontWeight.w700,
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
                                      fontWeight: FontWeight.w700,
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
                                    fontWeight: FontWeight.w600,
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
                    style: TextStyle(fontSize: AppFonts.body, fontWeight: FontWeight.w700),
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
          } else if (provider.errorMessage != null && provider.attendanceHistory == null) {
             return Center(child: Text('Error: ${provider.errorMessage}'));
          } else if (provider.attendanceHistory == null || provider.attendanceHistory!.isEmpty) {
             return const Center(child: Text('Tidak ada riwayat kehadiran'));
          }

          final historyList = provider.attendanceHistory!;

          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.light.copyWith(
              statusBarColor: AppColors.primaryDark,
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
                      fontWeight: FontWeight.w700,
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
                      final summary = _getCourseSummary(course);
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
                                  fontWeight: FontWeight.w600,
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
                                    if ((summary['present'] as int) > 0)
                                      Expanded(
                                        flex: summary['present'] as int,
                                        child: Container(color: const Color(0xFF14B8A6)),
                                      ),
                                    if ((summary['leave'] as int) > 0)
                                      Expanded(
                                        flex: summary['leave'] as int,
                                        child: Container(color: const Color(0xFFF59E0B)),
                                      ),
                                    if ((summary['absent'] as int) > 0)
                                      Expanded(
                                        flex: summary['absent'] as int,
                                        child: Container(color: const Color(0xFFEF4444)),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Mini stats
                              Row(
                                children: [
                                  _miniStat(const Color(0xFF14B8A6), 'Hadir ${summary['present']}'),
                                  const SizedBox(width: 12),
                                  _miniStat(const Color(0xFFEF4444), 'Absen ${summary['absent']}'),
                                  const SizedBox(width: 12),
                                  _miniStat(const Color(0xFFF59E0B), 'Izin ${summary['leave']}'),
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
