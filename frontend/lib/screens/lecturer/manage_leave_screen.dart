import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/theme.dart';
import '../../providers/lecturer_provider.dart';
import '../../services/api_service.dart';

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
        title: const Text(
          'Kelola Perizinan',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                indicatorColor: AppColors.primary,
                indicatorWeight: 3,
                indicatorSize: TabBarIndicatorSize.label,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textMuted,
                labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 13),
                tabs: const [
                  Tab(text: 'Pending'),
                  Tab(text: 'Disetujui'),
                  Tab(text: 'Ditolak'),
                ],
              ),
              Container(color: AppColors.borderLight, height: 1),
            ],
          ),
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
            Icon(Icons.inbox_outlined, size: 64, color: AppColors.textMuted.withValues(alpha: 0.3)),
            const SizedBox(height: AppSpacing.md),
            const Text('Tidak ada data perizinan', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => context.read<LecturerProvider>().fetchLeaveRequests(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, index) => _buildLeaveCard(items[index], showActions),
      ),
    );
  }

  Widget _buildLeaveCard(Map<String, dynamic> leave, bool showActions) {
    final student = leave['student'] as Map<String, dynamic>? ?? {};
    final dateStr = leave['date'];
    final date = dateStr != null ? DateTime.tryParse(dateStr) : null;
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
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: AppShadows.card,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      (student['name'] ?? 'U')[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student['name'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textPrimary),
                      ),
                      Text(
                        student['studentId'] ?? '',
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Reason & Description
            Text(
              leave['course']?['name'] != null ? '${leave['reason']} - ${leave['course']['name']}' : (leave['reason'] ?? ''),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
            ),
            if (leave['description'] != null && leave['description'].toString().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                leave['description'],
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),

            // Meta info
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text(
                  date != null
                      ? DateFormat('dd MMM yyyy', 'id').format(date)
                      : '-',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                const Spacer(),
                if (leave['evidenceUrl'] != null && leave['evidenceUrl'].toString().isNotEmpty)
                  GestureDetector(
                    onTap: () async {
                      final domain = ApiService.baseUrl.replaceAll('/api', '');
                      final url = Uri.parse('$domain${leave['evidenceUrl']}');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    },
                    child: Row(
                      children: [
                        const Icon(Icons.attach_file, size: 14, color: AppColors.primary),
                        const SizedBox(width: 4),
                        const Text(
                          'Lihat Dokumen',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            // Review note
            if (reviewNote != null && reviewNote.toString().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${reviewedBy?['name'] ?? 'Dosen'}: $reviewNote',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Action buttons
            if (showActions) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _showReviewBottomSheet(leave['id'], 'REJECTED'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger, width: 1.2),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      ),
                      child: const Text('Tolak', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _showReviewBottomSheet(leave['id'], 'APPROVED'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                        elevation: 0,
                      ),
                      child: const Text('Setujui', style: TextStyle(fontWeight: FontWeight.w600)),
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

  void _showReviewBottomSheet(String id, String status) {
    final noteController = TextEditingController();
    final isApprove = status == 'APPROVED';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
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
              Text(
                isApprove ? 'Setujui Perizinan' : 'Tolak Perizinan',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteController,
                decoration: InputDecoration(
                  hintText: 'Tulis catatan review (opsional)...',
                  hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isApprove ? AppColors.success : AppColors.danger,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    elevation: 0,
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
                          content: Text(success ? 'Berhasil memproses perizinan' : 'Gagal, coba lagi.'),
                          backgroundColor: success ? AppColors.success : AppColors.danger,
                        ),
                      );
                    }
                  },
                  child: Text(isApprove ? 'Setujui Sekarang' : 'Tolak Sekarang', style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
