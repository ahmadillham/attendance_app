import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/theme.dart';
import '../../providers/lecturer_provider.dart';
import '../../widgets/app_alert.dart';

/// Course Attendance Recap — table view of students × meetings
class CourseAttendanceScreen extends StatefulWidget {
  final String courseId;
  final String courseName;

  const CourseAttendanceScreen({
    super.key,
    required this.courseId,
    required this.courseName,
  });

  @override
  State<CourseAttendanceScreen> createState() => _CourseAttendanceScreenState();
}

class _CourseAttendanceScreenState extends State<CourseAttendanceScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LecturerProvider>().fetchCourseAttendance(widget.courseId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.courseName,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.borderLight, height: 1),
        ),
      ),
      body: Consumer<LecturerProvider>(
        builder: (context, provider, _) {
          if (provider.isAttendanceLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = provider.courseAttendance;
          if (data == null) {
             return const Center(
               child: Column(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   Icon(Icons.inbox_outlined, size: 48, color: AppColors.textMuted),
                   SizedBox(height: 12),
                   Text('Tidak ada data', style: TextStyle(fontSize: AppFonts.body, fontWeight: FontWeight.w400, color: AppColors.textSecondary)),
                   SizedBox(height: 4),
                   Text('Data absensi kelas belum tersedia', style: TextStyle(fontSize: AppFonts.caption, color: AppColors.textMuted)),
                 ],
               ),
             );
          }

          final enrollments = data['enrollments'] as List? ?? [];
          final attendances = data['attendances'] as List? ?? [];
          final maxMeeting = data['maxMeeting'] ?? 0;

          if (enrollments.isEmpty) {
            return _buildEmptyState();
          }

          return _buildAttendanceTable(enrollments, attendances, maxMeeting);
        },
      ),
    );
  }

  Widget _buildAttendanceTable(List enrollments, List attendances, int maxMeeting) {
    final Map<String, Map<int, Map<String, dynamic>>> attendanceMap = {};
    for (final a in attendances) {
      final sid = a['studentId'] ?? a['student']?['id'] ?? '';
      final meeting = a['meetingCount'] ?? 0;
      attendanceMap.putIfAbsent(sid, () => {});
      attendanceMap[sid]![meeting] = Map<String, dynamic>.from(a);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(AppColors.background),
            headingTextStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              fontSize: 12,
            ),
            dataRowMinHeight: 52,
            dataRowMaxHeight: 52,
            columnSpacing: 20,
            horizontalMargin: 16,
            columns: [
              const DataColumn(label: Text('NIM')),
              const DataColumn(label: Text('NAMA')),
              for (int i = 1; i <= maxMeeting; i++)
                DataColumn(label: Text('P$i'), numeric: true),
            ],
            rows: enrollments.map((e) {
              final student = e['student'] as Map<String, dynamic>? ?? {};
              final sid = student['id'] ?? '';
              final studentAttendance = attendanceMap[sid] ?? {};

              return DataRow(
                cells: [
                  DataCell(Text(student['studentId'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
                      child: Text(
                        student['name'] ?? '',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  for (int i = 1; i <= maxMeeting; i++)
                    DataCell(
                      _buildStatusChip(studentAttendance[i]),
                      onTap: studentAttendance[i] != null
                          ? () => _showEditBottomSheet(studentAttendance[i]!)
                          : null,
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(Map<String, dynamic>? attendance) {
    if (attendance == null) {
      return const Text('-', style: TextStyle(color: AppColors.textMuted));
    }
    final status = attendance['status'] ?? '';
    Color color;
    String label;
    switch (status) {
      case 'present':
        color = AppColors.success;
        label = '✓';
        break;
      case 'absent':
        color = AppColors.danger;
        label = '✗';
        break;
      case 'leave':
        color = AppColors.warning;
        label = 'I';
        break;
      default:
        color = AppColors.textMuted;
        label = '?';
    }
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
    );
  }

  void _showEditBottomSheet(Map<String, dynamic> attendance) {
    final id = attendance['id'];
    final currentStatus = attendance['status'];
    String selectedStatus = currentStatus;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Container(
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
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Ubah Status Kehadiran',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              ...['present', 'absent', 'leave'].map((status) {
                final labels = {'present': 'Hadir', 'absent': 'Alpa', 'leave': 'Izin'};
                final icons = {'present': Icons.check_circle_outline, 'absent': Icons.cancel_outlined, 'leave': Icons.description_outlined};
                final colors = {'present': AppColors.success, 'absent': AppColors.danger, 'leave': AppColors.warning};
                
                final isSelected = selectedStatus == status;

                return GestureDetector(
                  onTap: () => setDialogState(() => selectedStatus = status),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected ? colors[status]!.withValues(alpha: 0.08) : AppColors.background,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: isSelected ? colors[status]! : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(icons[status], color: colors[status], size: 22),
                        const SizedBox(width: 12),
                        Text(
                          labels[status]!,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: isSelected ? colors[status] : AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        if (isSelected)
                          Icon(Icons.check_circle, color: colors[status], size: 20),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final provider = context.read<LecturerProvider>();
                    final success = await provider.editAttendance(id, selectedStatus);
                    if (success) {
                      await provider.fetchCourseAttendance(widget.courseId);
                      if (mounted) {
                        AppAlert.toast(
                          context,
                          message: 'Status berhasil diubah',
                          type: AlertType.success,
                        );
                      }
                    }
                  },
                  child: const Text('Simpan Perubahan', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline, size: 64, color: AppColors.textMuted.withValues(alpha: 0.5)),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Belum ada mahasiswa terdaftar',
            style: TextStyle(fontSize: AppFonts.body, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
