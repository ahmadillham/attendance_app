import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../constants/theme.dart';
import '../constants/mock_data.dart';

/// DashboardScreen — Modern Clean Design
/// ─────────────────────────────────────────────
/// Schedule data comes from the campus server (mock data for now).
///
/// 🔌 BACKEND INTEGRATION POINT:
///    Replace MOCK_SCHEDULE with: GET /api/schedules?studentId=...
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final student = mockStudent;
    const todayDay = 'Selasa';
    final schedule = (mockWeeklySchedule[todayDay] ?? []).asMap().entries.map((entry) {
      return _ScheduleDisplay(
        item: entry.value,
        status: entry.key == 0 ? 'active' : 'upcoming',
      );
    }).toList();
    final stats = student.attendanceSummary;
    final attendancePercent = (stats.present / stats.total * 100).round();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: AppColors.primaryDark,
        ),
        child: Column(
          children: [
            // ── Header ───────────────────────────────
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
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SELAMAT PAGI',
                          style: TextStyle(
                            fontSize: AppFonts.caption,
                            color: Colors.white.withValues(alpha: 0.7),
                            letterSpacing: 0.3,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          student.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppColors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                            const SizedBox(width: 8),
                            Text(
                              student.department,
                              style: TextStyle(
                                fontSize: AppFonts.small,
                                fontWeight: FontWeight.w600,
                                color: AppColors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        student.avatarInitials,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Scrollable Body ──────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Quick Actions ──────────────────
                    // Absensi Button
                    GestureDetector(
                      onTap: () => Navigator.of(context).pushNamed('/attendance'),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          boxShadow: AppShadows.glow,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.primarySurface,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.face, size: 22, color: AppColors.primary),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Absensi',
                                    style: TextStyle(
                                      fontSize: AppFonts.body,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.white,
                                    ),
                                  ),
                                  Text(
                                    'Wajah & Lokasi',
                                    style: TextStyle(
                                      fontSize: AppFonts.small,
                                      color: Colors.white.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.chevron_right, size: 18, color: AppColors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Ajukan Izin Button
                    GestureDetector(
                      onTap: () => Navigator.of(context).pushNamed('/leave-request'),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(color: AppColors.border),
                          boxShadow: AppShadows.card,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.warningSurface,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.description_outlined, size: 22, color: AppColors.warning),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Ajukan Izin',
                                    style: TextStyle(
                                      fontSize: AppFonts.body,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    'Perizinan & Sakit',
                                    style: TextStyle(
                                      fontSize: AppFonts.small,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.border,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Attendance Stats ───────────────
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        boxShadow: AppShadows.card,
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Rekap Kehadiran',
                                style: TextStyle(
                                  fontSize: AppFonts.h3,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.accentSurface,
                                  borderRadius: BorderRadius.circular(AppRadius.full),
                                ),
                                child: Text(
                                  '$attendancePercent%',
                                  style: const TextStyle(
                                    fontSize: AppFonts.caption,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.accent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          // Progress bar
                          Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: AppColors.borderLight,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: attendancePercent / 100,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.accent,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              _StatItem(
                                icon: Icons.check_circle,
                                label: 'Hadir',
                                value: stats.present,
                                color: AppColors.accent,
                                bg: AppColors.accentSurface,
                              ),
                              _StatItem(
                                icon: Icons.cancel,
                                label: 'Absen',
                                value: stats.absent,
                                color: AppColors.danger,
                                bg: AppColors.dangerSurface,
                              ),
                              _StatItem(
                                icon: Icons.description,
                                label: 'Izin',
                                value: stats.leave,
                                color: AppColors.warning,
                                bg: AppColors.warningSurface,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Today's Schedule ───────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Jadwal Hari Ini',
                              style: TextStyle(
                                fontSize: AppFonts.h3,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(DateTime.now()),
                              style: const TextStyle(
                                fontSize: AppFonts.caption,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (schedule.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(48),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          boxShadow: AppShadows.card,
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.calendar_today_outlined, size: 48, color: AppColors.textMuted),
                            const SizedBox(height: 12),
                            const Text(
                              'Tidak ada jadwal',
                              style: TextStyle(
                                fontSize: AppFonts.body,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Hari $todayDay libur',
                              style: const TextStyle(
                                fontSize: AppFonts.caption,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ...schedule.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        final badge = _statusLabel(item.status);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Time column
                              SizedBox(
                                width: 52,
                                child: Column(
                                  children: [
                                    const SizedBox(height: 2),
                                    Text(
                                      item.item.time.split(' – ')[0],
                                      style: const TextStyle(
                                        fontSize: AppFonts.small,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: badge['dotColor'] as Color,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    if (index < schedule.length - 1)
                                      Container(
                                        width: 2,
                                        height: 60,
                                        margin: const EdgeInsets.only(top: 4),
                                        color: AppColors.border,
                                      ),
                                  ],
                                ),
                              ),
                              // Content
                              Expanded(
                                child: Container(
                                  margin: const EdgeInsets.only(left: 8, bottom: 10),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(AppRadius.md),
                                    boxShadow: AppShadows.card,
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.item.subject,
                                              style: const TextStyle(
                                                fontSize: AppFonts.body,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.borderLight,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              item.item.room,
                                              style: const TextStyle(
                                                fontSize: AppFonts.small,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textMuted,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Icon(Icons.person_outline, size: 12, color: AppColors.textMuted),
                                          const SizedBox(width: 4),
                                          Text(
                                            item.item.lecturer,
                                            style: const TextStyle(
                                              fontSize: AppFonts.small,
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Map<String, dynamic> _statusLabel(String status) {
    switch (status) {
      case 'active':
        return {'text': 'Berlangsung', 'color': const Color(0xFF0D9488), 'bg': const Color(0xFFF0FDFA), 'dotColor': const Color(0xFF14B8A6)};
      case 'completed':
        return {'text': 'Selesai', 'color': const Color(0xFF64748B), 'bg': const Color(0xFFF8FAFC), 'dotColor': const Color(0xFF94A3B8)};
      default:
        return {'text': 'Mendatang', 'color': const Color(0xFF4338CA), 'bg': const Color(0xFFEEF2FF), 'dotColor': const Color(0xFF6366F1)};
    }
  }
}

class _ScheduleDisplay {
  final ScheduleItem item;
  final String status;

  _ScheduleDisplay({required this.item, required this.status});
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final Color color;
  final Color bg;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 6),
          Text(
            '$value',
            style: const TextStyle(
              fontSize: AppFonts.h2,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: AppFonts.small,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
