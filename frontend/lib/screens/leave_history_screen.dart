import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../constants/theme.dart';
import '../providers/app_provider.dart';

class LeaveHistoryScreen extends StatefulWidget {
  const LeaveHistoryScreen({super.key});

  @override
  State<LeaveHistoryScreen> createState() => _LeaveHistoryScreenState();
}

class _LeaveHistoryScreenState extends State<LeaveHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().fetchLeaveHistory();
    });
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '-';
    try {
      final date = DateTime.parse(dateStr);
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
      const days = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];
      return '${days[date.weekday % 7]}, ${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  Widget _buildStatusBadge(String status) {
    String label;
    switch (status) {
      case 'APPROVED':
        label = 'Disetujui';
        break;
      case 'REJECTED':
        label = 'Ditolak';
        break;
      case 'PENDING':
      default:
        label = 'Menunggu';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.borderLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: AppFonts.small,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
        ),
        child: Consumer<AppProvider>(
          builder: (context, provider, child) {
            final records = provider.leaveHistory ?? [];
            final isLoading = provider.isLoadingLeave && provider.leaveHistory == null;

            return Column(
              children: [
                // Custom Header — matching other screens
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
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.arrow_back, size: 20, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Riwayat Izin',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w400,
                                color: AppColors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${records.length} pengajuan',
                              style: TextStyle(
                                fontSize: AppFonts.caption,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Body
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                      : (provider.leaveError != null && provider.leaveHistory == null)
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.error_outline, size: 48, color: AppColors.textMuted),
                                  const SizedBox(height: 16),
                                  Text('Gagal memuat: ${provider.leaveError}',
                                      style: const TextStyle(color: AppColors.textSecondary)),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: () => provider.fetchLeaveHistory(forceRefresh: true),
                                    child: const Text('Coba Lagi'),
                                  ),
                                ],
                              ),
                            )
                          : records.isEmpty
                              ? const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.history_outlined, size: 48, color: AppColors.textMuted),
                                      SizedBox(height: 12),
                                      Text(
                                        'Belum ada riwayat',
                                        style: TextStyle(
                                          fontSize: AppFonts.body,
                                          fontWeight: FontWeight.w400,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Pengajuan izin Anda akan tampil di sini',
                                        style: TextStyle(
                                          fontSize: AppFonts.caption,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : RefreshIndicator(
                                  color: AppColors.primary,
                                  onRefresh: () => provider.fetchLeaveHistory(forceRefresh: true),
                                  child: SingleChildScrollView(
                                    physics: const AlwaysScrollableScrollPhysics(),
                                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                                    child: Column(
                                      children: [
                                        ...records.map((leave) => _buildLeaveCard(leave)),
                                        const SizedBox(height: 20),
                                      ],
                                    ),
                                  ),
                                ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildLeaveCard(dynamic leave) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      leave.reasonLabel,
                      style: const TextStyle(
                        fontSize: AppFonts.body,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (leave.courseName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        leave.courseName!,
                        style: const TextStyle(
                          fontSize: AppFonts.caption,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildStatusBadge(leave.status),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 12, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text(
                _formatDate(leave.date),
                style: const TextStyle(
                  fontSize: AppFonts.small,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          if (leave.description != null && leave.description!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(
                leave.description!,
                style: const TextStyle(
                  fontSize: AppFonts.caption,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
