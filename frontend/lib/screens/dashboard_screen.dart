import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../constants/theme.dart';
import '../constants/mock_data.dart';
import '../providers/app_provider.dart';
import '../services/app_time.dart';

/// DashboardScreen — Modern Clean Design
/// ─────────────────────────────────────────────
/// Schedule data comes from the campus server (mock data for now).
///
/// 🔌 BACKEND INTEGRATION POINT:
///    Replace MOCK_SCHEDULE with: GET /api/schedules?studentId=...
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().fetchDashboardData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Builder(
        builder: (context) {
          if (provider.isLoadingDashboard && provider.dashboardData == null) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          } else if (provider.dashboardError != null && provider.dashboardData == null) {
             return Center(child: Text('Error: ${provider.dashboardError}'));
          } else if (provider.dashboardData == null) {
             return const Center(child: Text('Tidak ada data didapat'));
          }

          final student = provider.dashboardData!.student;
          final schedule = provider.dashboardData!.todaySchedules.asMap().entries.map((entry) {
            return _ScheduleDisplay(
              item: entry.value,
              status: entry.key == 0 ? 'active' : 'upcoming',
            );
          }).toList();
          final stats = student.attendanceSummary;
          final attendancePercent = stats.percentage;
          const dayNames = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
          final todayDay = dayNames[AppTime.now().weekday - 1];

          // Dynamic greeting based on time of day
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
                          greeting,
                          style: TextStyle(
                            fontSize: AppFonts.caption,
                            color: Colors.white.withValues(alpha: 0.9),
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
                                color: AppColors.white,
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
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () => provider.fetchDashboardData(forceRefresh: true),
                child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Quick Actions ──────────────────
                    // Compute attendance time-window eligibility
                    // Window: 12 hours before class start → 15 minutes after class start
                    Builder(builder: (context) {
                      final now = AppTime.timeOfDay();
                      final nowMinutes = now.hour * 60 + now.minute;
                      const earlyOpenMinutes = 12 * 60; // 12 hours
                      const lateCloseMinutes = 15;

                      // Check if any class is within its attendance window
                      bool isWindowOpen = false;
                      String? windowCloseInfo; // when the current open window closes
                      String? nextWindowInfo; // when the next window opens

                      final todaySchedules = provider.dashboardData!.todaySchedules;
                      for (final item in todaySchedules) {
                        // time format: "09:45 – 11:00"
                        final startStr = item.time.split(' – ').first.trim();
                        final parts = startStr.split(':');
                        if (parts.length == 2) {
                          final startMinutes = int.parse(parts[0]) * 60 + int.parse(parts[1]);
                          final diff = nowMinutes - startMinutes;
                          // Allow: from earlyOpenMinutes before to lateCloseMinutes after
                          if (diff >= -earlyOpenMinutes && diff <= lateCloseMinutes) {
                            isWindowOpen = true;
                            final closeMin = startMinutes + lateCloseMinutes;
                            final h = closeMin ~/ 60;
                            final m = closeMin % 60;
                            windowCloseInfo = '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
                            break;
                          }
                        }
                      }

                      // Find next upcoming window for display
                      if (!isWindowOpen && todaySchedules.isNotEmpty) {
                        int? nearestClose;
                        for (final item in todaySchedules) {
                          final startStr = item.time.split(' – ').first.trim();
                          final parts = startStr.split(':');
                          if (parts.length == 2) {
                            final startMinutes = int.parse(parts[0]) * 60 + int.parse(parts[1]);
                            final closeMinutes = startMinutes + lateCloseMinutes;
                            // Only future windows (haven't closed yet)
                            if (closeMinutes > nowMinutes) {
                              nearestClose ??= closeMinutes;
                              if (closeMinutes < nearestClose) nearestClose = closeMinutes;
                            }
                          }
                        }
                        if (nearestClose != null) {
                          // The window will open earlyOpenMinutes before class start
                          // but since earlyOpen is 12h, it's likely already open or will be "soon"
                          // Show the class start time as reference
                          final classStart = nearestClose - lateCloseMinutes;
                          final h = classStart ~/ 60;
                          final m = classStart % 60;
                          nextWindowInfo = '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
                        }
                      }

                      final bool canAttend = isWindowOpen;

                      return Opacity(
                        opacity: canAttend ? 1.0 : 0.5,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            boxShadow: canAttend ? AppShadows.glow : null,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: canAttend ? () => Navigator.of(context).pushNamed('/attendance') : null,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: AppColors.primarySurface,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(
                                        canAttend ? Icons.face : Icons.lock_clock,
                                        size: 22,
                                        color: AppColors.primary,
                                      ),
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
                                            canAttend
                                                ? windowCloseInfo != null
                                                    ? 'Batas absen sampai $windowCloseInfo'
                                                    : 'Wajah & Lokasi'
                                                : nextWindowInfo != null
                                                    ? 'Kelas berikutnya pukul $nextWindowInfo'
                                                    : todaySchedules.isEmpty
                                                        ? 'Tidak ada kelas hari ini'
                                                        : 'Semua jendela absensi telah ditutup',
                                            style: TextStyle(
                                              fontSize: AppFonts.small,
                                              color: Colors.white.withValues(alpha: 0.9),
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
                                      child: Icon(
                                        canAttend ? Icons.chevron_right : Icons.lock_outline,
                                        size: 18,
                                        color: AppColors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 10),

                    // Ajukan Izin Button
                    Builder(builder: (context) {
                      final todaySchedules = provider.dashboardData!.todaySchedules;
                      final hasClassesToday = todaySchedules.isNotEmpty;

                      // Check if at least one class hasn't started yet (cutoff = class start time)
                      bool hasUpcomingClass = false;
                      String? nextClassTime;
                      if (hasClassesToday) {
                        final now = AppTime.timeOfDay();
                        final nowMinutes = now.hour * 60 + now.minute;
                        for (final item in todaySchedules) {
                          final startStr = item.time.split(' – ').first.trim();
                          final parts = startStr.split(':');
                          if (parts.length == 2) {
                            final startMinutes = int.parse(parts[0]) * 60 + int.parse(parts[1]);
                            if (startMinutes > nowMinutes) {
                              hasUpcomingClass = true;
                              nextClassTime ??= startStr;
                              break;
                            }
                          }
                        }
                      }

                      final bool canRequestLeave = hasClassesToday && hasUpcomingClass;

                      // Subtitle text
                      String subtitle;
                      if (!hasClassesToday) {
                        subtitle = 'Tidak ada kelas hari ini';
                      } else if (!hasUpcomingClass) {
                        subtitle = 'Batas waktu izin telah lewat';
                      } else {
                        subtitle = 'Batas sebelum pukul $nextClassTime';
                      }

                      return Opacity(
                        opacity: canRequestLeave ? 1.0 : 0.5,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            border: Border.all(color: AppColors.border),
                            boxShadow: canRequestLeave ? AppShadows.card : null,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: canRequestLeave
                                  ? () => Navigator.of(context).pushNamed('/leave-request')
                                  : null,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: canRequestLeave ? AppColors.warningSurface : AppColors.borderLight,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(
                                        canRequestLeave ? Icons.description_outlined : Icons.block,
                                        size: 22,
                                        color: canRequestLeave ? AppColors.warning : AppColors.textMuted,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Ajukan Izin',
                                            style: TextStyle(
                                              fontSize: AppFonts.body,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          Text(
                                            subtitle,
                                            style: const TextStyle(
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
                                      child: Icon(
                                        canRequestLeave ? Icons.chevron_right : Icons.lock_outline,
                                        size: 18,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),

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
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                  const SizedBox(height: 2),
                                  Text(
                                    'Semester ini',
                                    style: const TextStyle(
                                      fontSize: AppFonts.small,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
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
                              color: AppColors.border,
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
                              DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(AppTime.now()),
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
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Padding(
                                            padding: EdgeInsets.only(top: 2),
                                            child: Icon(Icons.person_outline, size: 12, color: AppColors.textMuted),
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              item.item.lecturer,
                                              style: const TextStyle(
                                                fontSize: AppFonts.small,
                                                color: AppColors.textMuted,
                                              ),
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
            ),
          ],
        ),
      );
    }),
  );
}

  static Map<String, dynamic> _statusLabel(String status) {
    switch (status) {
      case 'active':
        return {'text': 'Berlangsung', 'color': AppColors.success, 'bg': AppColors.successSurface, 'dotColor': AppColors.success};
      case 'completed':
        return {'text': 'Selesai', 'color': AppColors.success, 'bg': AppColors.successSurface, 'dotColor': AppColors.success};
      default:
        return {'text': 'Mendatang', 'color': AppColors.textMuted, 'bg': AppColors.borderLight, 'dotColor': AppColors.textMuted};
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
