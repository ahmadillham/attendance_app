import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../constants/theme.dart';
import '../../providers/lecturer_provider.dart';

/// Manage Leave Requests — approve/reject with tabs
class ManageLeaveScreen extends StatefulWidget {
  const ManageLeaveScreen({super.key});

  @override
  State<ManageLeaveScreen> createState() => _ManageLeaveScreenState();
}

class _ManageLeaveScreenState extends State<ManageLeaveScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LecturerProvider>().fetchLeaveRequests();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Kelola Perizinan'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Disetujui'),
            Tab(text: 'Ditolak'),
          ],
        ),
      ),
      body: Consumer<LecturerProvider>(
        builder: (context, provider, _) {
          if (provider.isLeaveLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final pending = provider.leaveRequests.where((l) => l['status'] == 'PENDING').toList();
          final approved = provider.leaveRequests.where((l) => l['status'] == 'APPROVED').toList();
          final rejected = provider.leaveRequests.where((l) => l['status'] == 'REJECTED').toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildLeaveList(pending, showActions: true),
              _buildLeaveList(approved),
              _buildLeaveList(rejected),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLeaveList(List<Map<String, dynamic>> items, {bool showActions = false}) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: AppColors.textMuted.withValues(alpha: 0.5)),
            const SizedBox(height: AppSpacing.md),
            const Text('Tidak ada data', style: TextStyle(color: AppColors.textMuted)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => context.read<LecturerProvider>().fetchLeaveRequests(),
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: items.length,
        itemBuilder: (context, index) => _buildLeaveCard(items[index], showActions),
      ),
    );
  }

  Widget _buildLeaveCard(Map<String, dynamic> leave, bool showActions) {
    final student = leave['student'] as Map<String, dynamic>? ?? {};
    final dateFrom = DateTime.tryParse(leave['dateFrom'] ?? '');
    final dateTo = DateTime.tryParse(leave['dateTo'] ?? '');
    final status = leave['status'] ?? 'PENDING';
    final reviewNote = leave['reviewNote'];
    final reviewedBy = leave['reviewedBy'] as Map<String, dynamic>?;

    Color statusColor;
    String statusLabel;
    switch (status) {
      case 'APPROVED':
        statusColor = AppColors.success;
        statusLabel = 'Disetujui';
        break;
      case 'REJECTED':
        statusColor = AppColors.danger;
        statusLabel = 'Ditolak';
        break;
      default:
        statusColor = AppColors.warning;
        statusLabel = 'Pending';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.card,
        border: Border(left: BorderSide(color: statusColor, width: 4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Student info & status
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Center(
                    child: Text(
                      (student['name'] ?? 'U')[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: AppFonts.h3,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student['name'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: AppFonts.body),
                      ),
                      Text(
                        student['studentId'] ?? '',
                        style: const TextStyle(fontSize: AppFonts.caption, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: AppFonts.small,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Reason
            Text(
              leave['reason'] ?? '',
              style: const TextStyle(fontSize: AppFonts.body, color: AppColors.textPrimary),
            ),
            if (leave['description'] != null && leave['description'].toString().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                leave['description'],
                style: const TextStyle(fontSize: AppFonts.caption, color: AppColors.textSecondary),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: AppSpacing.sm),

            // Date range
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  dateFrom != null && dateTo != null
                      ? '${DateFormat('dd MMM yyyy', 'id').format(dateFrom)} — ${DateFormat('dd MMM yyyy', 'id').format(dateTo)}'
                      : '-',
                  style: const TextStyle(fontSize: AppFonts.caption, color: AppColors.textMuted),
                ),
              ],
            ),

            // Review note
            if (reviewNote != null && reviewNote.toString().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.comment_outlined, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        '${reviewedBy?['name'] ?? 'Dosen'}: $reviewNote',
                        style: const TextStyle(fontSize: AppFonts.caption, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Action buttons
            if (showActions) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Tolak'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                      ),
                      onPressed: () => _showReviewDialog(leave['id'], 'REJECTED'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Setujui'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _showReviewDialog(leave['id'], 'APPROVED'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showReviewDialog(String id, String status) {
    final noteController = TextEditingController();
    final isApprove = status == 'APPROVED';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isApprove ? 'Setujui Izin' : 'Tolak Izin'),
        content: TextField(
          controller: noteController,
          decoration: InputDecoration(
            hintText: 'Catatan (opsional)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isApprove ? AppColors.success : AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final provider = context.read<LecturerProvider>();
              final success = await provider.reviewLeave(
                id,
                status,
                noteController.text.isEmpty ? null : noteController.text,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Berhasil!' : 'Gagal, coba lagi.'),
                    backgroundColor: success ? AppColors.success : AppColors.danger,
                  ),
                );
              }
            },
            child: Text(isApprove ? 'Setujui' : 'Tolak'),
          ),
        ],
      ),
    );
  }
}
