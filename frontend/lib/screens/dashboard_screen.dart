import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../constants/theme.dart';
import '../constants/mock_data.dart';
import '../providers/app_provider.dart';
import '../services/app_time.dart';
import '../widgets/dashboard_header.dart';

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
             return Center(
               child: Padding(
                 padding: const EdgeInsets.all(32),
                 child: Column(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     const Icon(Icons.wifi_off_outlined, size: 48, color: AppColors.textMuted),
                     const SizedBox(height: 16),
                     const Text('Gagal memuat data', style: TextStyle(fontSize: AppFonts.body, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                     const SizedBox(height: 4),
                     Text('${provider.dashboardError}', textAlign: TextAlign.center, style: const TextStyle(fontSize: AppFonts.caption, color: AppColors.textMuted)),
                     const SizedBox(height: 16),
                     ElevatedButton(onPressed: () => provider.fetchDashboardData(forceRefresh: true), child: const Text('Coba Lagi')),
                   ],
                 ),
               ),
             );
          } else if (provider.dashboardData == null) {
             return const Center(
               child: Column(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   Icon(Icons.inbox_outlined, size: 48, color: AppColors.textMuted),
                   SizedBox(height: 12),
                   Text('Tidak ada data', style: TextStyle(fontSize: AppFonts.body, fontWeight: FontWeight.w400, color: AppColors.textSecondary)),
                   SizedBox(height: 4),
                   Text('Data dashboard belum tersedia', style: TextStyle(fontSize: AppFonts.caption, color: AppColors.textMuted)),
                 ],
               ),
             );
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
              statusBarColor: Colors.transparent,
            ),
            child: Column(
          children: [
            // ── Header ───────────────────────────────
            DashboardHeader(
              greeting: greeting,
              name: student.name,
              identifier: student.studentId,
              subtitle: student.department,
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
                    // Window: exactly at class start → 15 minutes after class start
                    Builder(builder: (context) {
                      final now = AppTime.timeOfDay();
                      final nowMinutes = now.hour * 60 + now.minute;
                      const earlyOpenMinutes = 0; // Exactly at start time
                      const lateCloseMinutes = 15;

                      // Check if any class is within its attendance window
                      bool isWindowOpen = false;
                      bool isAttended = false;
                      bool hasLeaveForCurrentClass = false;
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
                            if (item.status == 'attended') isAttended = true;
                            if (item.hasLeaveRequest) hasLeaveForCurrentClass = true;
                            
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
                          // Show the class start time as reference
                          final classStart = nearestClose - lateCloseMinutes;
                          final h = classStart ~/ 60;
                          final m = classStart % 60;
                          nextWindowInfo = '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
                        }
                      }

                      final bool canAttend = isWindowOpen && !isAttended && !hasLeaveForCurrentClass;

                      return Opacity(
                        opacity: canAttend ? 1.0 : 0.5,
                        child: Container(
                          decoration: BoxDecoration(
                            color: hasLeaveForCurrentClass ? AppColors.warning : AppColors.primary,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            boxShadow: canAttend ? AppShadows.card : null,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: canAttend ? () {
                                Navigator.of(context).pushNamed('/attendance').then((_) {
                                  if (context.mounted) {
                                    context.read<AppProvider>().fetchDashboardData(forceRefresh: true);
                                  }
                                });
                              } : null,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        hasLeaveForCurrentClass
                                            ? Icons.event_busy
                                            : isAttended ? Icons.check_circle : canAttend ? Icons.face : Icons.lock_clock,
                                        size: 22,
                                        color: AppColors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            hasLeaveForCurrentClass ? 'Izin Aktif' : 'Absensi',
                                            style: const TextStyle(
                                              fontSize: AppFonts.body,
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.white,
                                            ),
                                          ),
                                          Text(
                                            hasLeaveForCurrentClass
                                                ? 'Anda sudah mengajukan izin untuk kelas ini'
                                                : isAttended
                                                    ? 'Sudah absen untuk kelas ini'
                                                    : canAttend
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
                                    Icon(
                                      canAttend ? Icons.chevron_right : Icons.lock_outline,
                                      size: 18,
                                      color: Colors.white.withValues(alpha: 0.7),
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

                      // Leave request cutoff: before the FIRST class of the day starts
                      bool canSubmitLeave = false;
                      String? firstClassTime;
                      if (hasClassesToday) {
                        final now = AppTime.timeOfDay();
                        final nowMinutes = now.hour * 60 + now.minute;
                        // Get the first class start time
                        final firstItem = todaySchedules.first;
                        final startStr = firstItem.time.split(' – ').first.trim();
                        final parts = startStr.split(':');
                        if (parts.length == 2) {
                          final firstStartMinutes = int.parse(parts[0]) * 60 + int.parse(parts[1]);
                          firstClassTime = startStr;
                          canSubmitLeave = nowMinutes < firstStartMinutes;
                        }
                      }

                      final bool canRequestLeave = hasClassesToday && canSubmitLeave;

                      // Subtitle text
                      String subtitle;
                      if (!hasClassesToday) {
                        subtitle = 'Tidak ada kelas hari ini';
                      } else if (!canSubmitLeave) {
                        subtitle = 'Batas waktu izin telah lewat';
                      } else {
                        subtitle = 'Batas sebelum pukul $firstClassTime';
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
                                  ? () {
                                      Navigator.of(context).pushNamed('/leave-request').then((_) {
                                        if (context.mounted) {
                                          context.read<AppProvider>().fetchDashboardData(forceRefresh: true);
                                        }
                                      });
                                    }
                                  : null,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: AppColors.borderLight,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        canRequestLeave ? Icons.description_outlined : Icons.block,
                                        size: 22,
                                        color: AppColors.textSecondary,
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
                                              fontWeight: FontWeight.w500,
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
                                    Icon(
                                      canRequestLeave ? Icons.chevron_right : Icons.lock_outline,
                                      size: 18,
                                      color: AppColors.textMuted,
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
                              const Text(
                                'Rekap Kehadiran',
                                style: TextStyle(
                                  fontSize: AppFonts.h3,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Builder(builder: (context) {
                                final total = stats.present + stats.absent + stats.leave;
                                final pct = total == 0 ? 0 : (stats.present / total * 100).round();
                                final color = pct >= 75 ? AppColors.success : (pct >= 50 ? AppColors.warning : AppColors.danger);
                                final bgColor = pct >= 75 ? AppColors.successSurface : (pct >= 50 ? AppColors.warningSurface : AppColors.dangerSurface);
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: bgColor,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '$pct%',
                                    style: TextStyle(
                                      fontSize: AppFonts.small,
                                      fontWeight: FontWeight.w600,
                                      color: color,
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Segmented bar
                          Builder(builder: (context) {
                              final totalRecorded = stats.present + stats.absent + stats.leave;
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  height: 6,
                                  width: double.infinity,
                                  color: AppColors.borderLight,
                                  child: totalRecorded == 0 
                                      ? null 
                                      : Row(
                                          children: [
                                            if (stats.present > 0)
                                              Expanded(
                                                flex: stats.present,
                                                child: Container(color: AppColors.success),
                                              ),
                                            if (stats.absent > 0)
                                              Expanded(
                                                flex: stats.absent,
                                                child: Container(color: AppColors.danger),
                                              ),
                                            if (stats.leave > 0)
                                              Expanded(
                                                flex: stats.leave,
                                                child: Container(color: AppColors.warning),
                                              ),
                                          ],
                                        ),
                                ),
                              );
                          }),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              _StatItem(
                                icon: Icons.check_circle,
                                label: 'Hadir',
                                value: stats.present,
                                color: AppColors.success,
                                bg: AppColors.successSurface,
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
                                fontWeight: FontWeight.w400,
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
                                fontWeight: FontWeight.w400,
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
                                        fontWeight: FontWeight.w400,
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
                                                fontWeight: FontWeight.w400,
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
                                                fontWeight: FontWeight.w400,
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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: AppFonts.small,
              fontWeight: FontWeight.w500,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
