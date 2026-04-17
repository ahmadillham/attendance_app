import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/theme.dart';
import '../../providers/lecturer_provider.dart';

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
        title: Text(widget.courseName),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Consumer<LecturerProvider>(
        builder: (context, provider, _) {
          if (provider.isAttendanceLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = provider.courseAttendance;
          if (data == null) return const Center(child: Text('Tidak ada data'));

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
    // Build a map: studentId -> { meetingCount -> attendance }
    final Map<String, Map<int, Map<String, dynamic>>> attendanceMap = {};
    for (final a in attendances) {
      final sid = a['studentId'] ?? a['student']?['id'] ?? '';
      final meeting = a['meetingCount'] ?? 0;
      attendanceMap.putIfAbsent(sid, () => {});
      attendanceMap[sid]![meeting] = Map<String, dynamic>.from(a);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(AppColors.primarySurface),
          headingTextStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.primaryDark,
            fontSize: AppFonts.caption,
          ),
          dataRowMinHeight: 44,
          dataRowMaxHeight: 44,
          columnSpacing: 12,
          columns: [
            const DataColumn(label: Text('NIM')),
            const DataColumn(label: Text('Nama')),
            for (int i = 1; i <= maxMeeting; i++)
              DataColumn(label: Text('P$i'), numeric: true),
          ],
          rows: enrollments.map((e) {
            final student = e['student'] as Map<String, dynamic>? ?? {};
            final sid = student['id'] ?? '';
            final studentAttendance = attendanceMap[sid] ?? {};

            return DataRow(
              cells: [
                DataCell(Text(student['studentId'] ?? '', style: const TextStyle(fontSize: AppFonts.caption))),
                DataCell(
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 150),
                    child: Text(
                      student['name'] ?? '',
                      style: const TextStyle(fontSize: AppFonts.caption),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                for (int i = 1; i <= maxMeeting; i++)
                  DataCell(
                    _buildStatusChip(studentAttendance[i]),
                    onTap: studentAttendance[i] != null
                        ? () => _showEditDialog(studentAttendance[i]!)
                        : null,
                  ),
              ],
            );
          }).toList(),
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
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: AppFonts.caption),
        ),
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> attendance) {
    final id = attendance['id'];
    final currentStatus = attendance['status'];
    String selectedStatus = currentStatus;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit Status Absensi'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: ['present', 'absent', 'leave'].map((status) {
              final labels = {'present': 'Hadir', 'absent': 'Alpa', 'leave': 'Izin'};
              final colors = {'present': AppColors.success, 'absent': AppColors.danger, 'leave': AppColors.warning};
              return RadioListTile<String>(
                title: Text(labels[status]!, style: TextStyle(color: colors[status])),
                value: status,
                groupValue: selectedStatus,
                activeColor: colors[status],
                onChanged: (v) => setDialogState(() => selectedStatus = v!),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () async {
                Navigator.pop(ctx);
                final provider = context.read<LecturerProvider>();
                final success = await provider.editAttendance(id, selectedStatus);
                if (success) {
                  await provider.fetchCourseAttendance(widget.courseId);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Status berhasil diubah')),
                    );
                  }
                }
              },
              child: const Text('Simpan', style: TextStyle(color: Colors.white)),
            ),
          ],
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
