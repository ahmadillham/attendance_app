import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../constants/theme.dart';
import '../widgets/screen_header.dart';
import '../widgets/section_label.dart';
import '../widgets/app_alert.dart';
import '../services/api_service.dart';
import '../services/app_time.dart';
import '../providers/app_provider.dart';
import '../models/schedule.dart';
import '../models/leave_request.dart';

/// LeaveRequestScreen — Modern Clean Design
/// ─────────────────────────────────────────────
/// Sectioned form with soft card inputs,
/// refined bottom sheet pickers, and subtle animations.

// Leave Reason Options
class _LeaveReasonOption {
  final String label;
  final String value;
  final IconData icon;

  const _LeaveReasonOption({
    required this.label,
    required this.value,
    required this.icon,
  });
}

const List<_LeaveReasonOption> _leaveReasons = [
  _LeaveReasonOption(label: 'Sakit', value: 'sick', icon: Icons.medical_services_outlined),
  _LeaveReasonOption(label: 'Urusan Keluarga', value: 'family', icon: Icons.people_outline),
  _LeaveReasonOption(label: 'Kegiatan Akademik', value: 'academic', icon: Icons.school_outlined),
  _LeaveReasonOption(label: 'Musibah / Force Majeure', value: 'emergency', icon: Icons.warning_outlined),
  _LeaveReasonOption(label: 'Lainnya', value: 'other', icon: Icons.more_horiz),
];

class LeaveRequestScreen extends StatefulWidget {
  const LeaveRequestScreen({super.key});

  @override
  State<LeaveRequestScreen> createState() => _LeaveRequestScreenState();
}

class _LeaveRequestScreenState extends State<LeaveRequestScreen> {
  DateTime _selectedDate = DateTime(AppTime.now().year, AppTime.now().month, AppTime.now().day);
  String? _reason;
  final _descriptionController = TextEditingController();
  PlatformFile? _document;
  bool _isSubmitting = false;

  List<String> _selectedCourseIds = [];
  List<String> _disabledCourseIds = [];
  List<ScheduleItem> _availableSchedules = [];
  bool _isLoadingSchedules = false;

  @override
  void initState() {
    super.initState();
    _fetchSchedulesForSelectedDate();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _fetchSchedulesForSelectedDate() async {
    setState(() {
      _isLoadingSchedules = true;
      _availableSchedules = [];
      _selectedCourseIds.clear();
    });

    try {
      const dayNames = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
      final dayName = dayNames[_selectedDate.weekday % 7];
      
      // Fetch both schedules and leave history concurrently
      final results = await Future.wait([
        ApiService.getSchedulesByDay(dayName),
        ApiService.getLeaveHistory(),
      ]);
      
      final schedules = results[0] as List<ScheduleItem>;
      final leaveHistory = results[1] as List;

      // Find courses that already have a leave request on this specific date
      final disabledIds = <String>[];
      for (final leave in leaveHistory) {
        if (leave is! LeaveRequest) continue;
        
        try {
          final leaveDate = DateTime.parse(leave.date).toLocal();
          if (leaveDate.year == _selectedDate.year &&
              leaveDate.month == _selectedDate.month &&
              leaveDate.day == _selectedDate.day &&
              leave.courseId != null) {
            disabledIds.add(leave.courseId!);
          }
        } catch (_) {
          // Ignore parse errors
        }
      }

      if (mounted) {
        setState(() {
          _availableSchedules = schedules;
          _disabledCourseIds = disabledIds;
          
          // Auto-select only courses that are not disabled
          _selectedCourseIds = schedules
              .map((s) => s.courseId)
              .whereType<String>()
              .where((id) => !disabledIds.contains(id))
              .toList();
              
          _isLoadingSchedules = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingSchedules = false);
      }
    }
  }

  String _formatDate(DateTime date) {
    const days = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${days[date.weekday % 7]}, ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Future<void> _handleDocumentPick() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() => _document = result.files.first);
      }
    } catch (e) {
      if (mounted) {
        AppAlert.toast(
          context,
          message: 'Gagal memilih dokumen.',
          type: AlertType.error,
        );
      }
    }
  }

  Future<void> _handleSubmit() async {
    if (_selectedCourseIds.isEmpty) {
      _showAlert('Peringatan', 'Pilih minimal satu mata kuliah.');
      return;
    }
    if (_reason == null) {
      _showAlert('Peringatan', 'Pilih alasan izin.');
      return;
    }
    if (_descriptionController.text.trim().isEmpty) {
      _showAlert('Peringatan', 'Masukkan keterangan.');
      return;
    }

    setState(() => _isSubmitting = true);

    bool reqSuccess = false;
    String errorMsg = 'Terjadi kesalahan saat mengirim pengajuan.';

    try {
      reqSuccess = await ApiService.submitLeaveRequest(
        courseIds: _selectedCourseIds,
        leaveType: _reason!,
        date: _selectedDate.toIso8601String(),
        reason: _descriptionController.text.trim(),
        clientTime: AppTime.now().toIso8601String(),
        document: _document,
      );
    } catch (e) {
      errorMsg = e.toString().replaceAll('Exception: ', '');
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (reqSuccess) {
      // Invalidate cached leave history so the history screen fetches fresh data
      if (mounted) {
        context.read<AppProvider>().leaveHistory = null;
      }
      final reasonLabel = _leaveReasons.firstWhere((r) => r.value == _reason).label;
      _showAlert(
        '✅ Berhasil',
        'Perizinan $reasonLabel telah dikirim.\n\nTanggal: ${_formatDate(_selectedDate)}\n\nTunggu konfirmasi dari dosen.',
        onDismiss: () => Navigator.of(context).pop(),
      );
    } else {
      _showAlert('❌ Gagal', errorMsg);
    }
  }

  void _showAlert(String title, String message, {VoidCallback? onDismiss}) {
    // Determine if this is a success alert
    final bool isSuccess = title.contains('Berhasil');
    final cleanTitle = title.replaceAll(RegExp(r'[✅❌]\s*'), '');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: !isSuccess, // Prevent dismissing success by tapping outside
      builder: (ctx) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppShadows.medium,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: isSuccess ? AppColors.accentSurface : AppColors.dangerSurface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                isSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                size: 36,
                color: isSuccess ? AppColors.accent : AppColors.danger,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              cleanTitle,
              style: const TextStyle(
                fontSize: AppFonts.h3,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: AppFonts.body,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  onDismiss?.call();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSuccess ? AppColors.accent : AppColors.primary,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  onDismiss != null ? 'Kembali ke Dashboard' : 'Mengerti',
                  style: const TextStyle(fontSize: AppFonts.body, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReasonPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
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
          children: [
            // Sheet bar
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Pilih Alasan',
                style: TextStyle(
                  fontSize: AppFonts.h3,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ..._leaveReasons.map((item) => GestureDetector(
              onTap: () {
                setState(() => _reason = item.value);
                Navigator.pop(ctx);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                decoration: BoxDecoration(
                  color: _reason == item.value ? AppColors.primarySurface : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _reason == item.value ? AppColors.primarySurface : AppColors.borderLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        item.icon,
                        size: 20,
                        color: _reason == item.value ? AppColors.primary : AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.label,
                        style: TextStyle(
                          fontSize: AppFonts.body,
                          color: _reason == item.value ? AppColors.primary : AppColors.textPrimary,
                          fontWeight: _reason == item.value ? FontWeight.w400 : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (_reason == item.value)
                      const Icon(Icons.check_circle, size: 20, color: AppColors.primary),
                  ],
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }

  void _showDatePickerSheet() {
    int tempYear = _selectedDate.year;
    int tempMonth = _selectedDate.month;
    int tempDay = _selectedDate.day;

    const monthNames = [
      '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];

    int daysInMonth(int y, int m) => DateTime(y, m + 1, 0).day;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
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
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Tanggal Izin',
                  style: TextStyle(
                    fontSize: AppFonts.h3,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Date preview
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  '$tempDay ${monthNames[tempMonth]} $tempYear',
                  style: const TextStyle(
                    fontSize: AppFonts.body,
                    fontWeight: FontWeight.w400,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Picker columns
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _PickerColumn(
                    label: 'Tanggal',
                    value: tempDay,
                    onUp: () => setSheetState(() => tempDay = (tempDay - 1).clamp(1, daysInMonth(tempYear, tempMonth))),
                    onDown: () => setSheetState(() => tempDay = (tempDay + 1).clamp(1, daysInMonth(tempYear, tempMonth))),
                  ),
                  _PickerColumn(
                    label: 'Bulan',
                    value: tempMonth,
                    onUp: () => setSheetState(() {
                      tempMonth = (tempMonth - 1).clamp(1, 12);
                      tempDay = tempDay.clamp(1, daysInMonth(tempYear, tempMonth));
                    }),
                    onDown: () => setSheetState(() {
                      tempMonth = (tempMonth + 1).clamp(1, 12);
                      tempDay = tempDay.clamp(1, daysInMonth(tempYear, tempMonth));
                    }),
                  ),
                  _PickerColumn(
                    label: 'Tahun',
                    value: tempYear,
                    onUp: () => setSheetState(() => tempYear--),
                    onDown: () => setSheetState(() => tempYear++),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedDate = DateTime(tempYear, tempMonth, tempDay);
                    });
                    _fetchSchedulesForSelectedDate();
                    Navigator.pop(ctx);
                  },
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
                    'Konfirmasi',
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
    final reasonLabel = _reason != null
        ? _leaveReasons.firstWhere((r) => r.value == _reason).label
        : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: AppColors.primaryDark,
        ),
        child: Column(
          children: [
            ScreenHeader(
              title: 'Ajukan Perizinan',
              subtitle: 'Lengkapi formulir berikut',
              onBack: () => Navigator.of(context).pop(),
              action: IconButton(
                icon: const Icon(Icons.history, color: AppColors.white),
                tooltip: 'Riwayat Izin',
                onPressed: () {
                  Navigator.pushNamed(context, '/leave-history');
                },
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Date Selection ─────────────────
                    const SectionLabel('TANGGAL IZIN'),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        boxShadow: AppShadows.card,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.primarySurface,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.calendar_today, size: 16, color: AppColors.primary),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Tanggal', style: TextStyle(fontSize: AppFonts.small, color: AppColors.textMuted)),
                                const SizedBox(height: 1),
                                Text(
                                  _formatDate(_selectedDate),
                                  style: const TextStyle(fontSize: AppFonts.caption, fontWeight: FontWeight.w400, color: AppColors.textPrimary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Course Selection ──────────────
                    if (_isLoadingSchedules)
                      const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
                    else if (_availableSchedules.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: AppColors.dangerSurface,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.error_outline, color: AppColors.danger),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Tidak ada jadwal mata kuliah pada tanggal ini.',
                                style: TextStyle(color: AppColors.danger, fontSize: AppFonts.body),
                              ),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      const SectionLabel('PILIH MATA KULIAH'),
                      ..._availableSchedules.map((schedule) {
                        final courseId = schedule.courseId;
                        if (courseId == null) return const SizedBox.shrink();
                        
                        final isSelected = _selectedCourseIds.contains(courseId);
                        final isDisabled = _disabledCourseIds.contains(courseId);
                        
                        return GestureDetector(
                          onTap: isDisabled ? null : () {
                            setState(() {
                              if (isSelected) {
                                _selectedCourseIds.remove(courseId);
                              } else {
                                _selectedCourseIds.add(courseId);
                              }
                            });
                          },
                          child: Opacity(
                            opacity: isDisabled ? 0.6 : 1.0,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                              decoration: BoxDecoration(
                                color: isDisabled 
                                    ? AppColors.borderLight.withValues(alpha: 0.3)
                                    : isSelected ? AppColors.primarySurface : AppColors.surface,
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                border: Border.all(
                                  color: isDisabled ? AppColors.border : isSelected ? AppColors.primary : AppColors.borderLight,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isDisabled 
                                        ? Icons.do_not_disturb_alt
                                        : isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                                    color: isDisabled ? AppColors.textMuted : isSelected ? AppColors.primary : AppColors.textMuted,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          schedule.subject,
                                          style: TextStyle(
                                            fontSize: AppFonts.body,
                                            fontWeight: isSelected && !isDisabled ? FontWeight.w600 : FontWeight.w400,
                                            color: isDisabled ? AppColors.textMuted : isSelected ? AppColors.primary : AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Text(
                                              schedule.time,
                                              style: TextStyle(
                                                fontSize: AppFonts.small,
                                                color: isDisabled ? AppColors.textMuted : isSelected ? AppColors.primary.withValues(alpha: 0.8) : AppColors.textMuted,
                                              ),
                                            ),
                                            if (isDisabled) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppColors.borderLight,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: const Text(
                                                  'Sudah diajukan',
                                                  style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                    ],

                    // ── Reason Picker ─────────────────
                    const SectionLabel('ALASAN IZIN'),
                    GestureDetector(
                      onTap: _showReasonPicker,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          boxShadow: AppShadows.card,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: _reason != null ? AppColors.primarySurface : AppColors.borderLight,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.assignment_outlined,
                                size: 18,
                                color: _reason != null ? AppColors.primary : AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                reasonLabel ?? 'Pilih alasan izin…',
                                style: TextStyle(
                                  fontSize: AppFonts.body,
                                  color: _reason != null ? AppColors.textPrimary : AppColors.textMuted,
                                  fontWeight: _reason != null ? FontWeight.w400 : FontWeight.w400,
                                ),
                              ),
                            ),
                            const Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.textMuted),
                          ],
                        ),
                      ),
                    ),

                    // ── Description ───────────────────
                    const SectionLabel('KETERANGAN'),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        boxShadow: AppShadows.card,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          TextField(
                            controller: _descriptionController,
                            maxLines: 4,
                            maxLength: 500,
                            onChanged: (_) => setState(() {}),
                            style: const TextStyle(
                              fontSize: AppFonts.body,
                              color: AppColors.textPrimary,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Jelaskan alasan perizinan…',
                              hintStyle: TextStyle(color: AppColors.textMuted),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.all(14),
                              counterText: '',
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 14, bottom: 10),
                            child: Text(
                              '${_descriptionController.text.length}/500',
                              style: const TextStyle(
                                fontSize: AppFonts.small,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Document Upload ───────────────
                    const SectionLabel('DOKUMEN PENDUKUNG'),
                    GestureDetector(
                      onTap: _handleDocumentPick,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          boxShadow: AppShadows.card,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: _document != null ? AppColors.accentSurface : AppColors.primarySurface,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                _document != null ? Icons.description : Icons.cloud_upload_outlined,
                                size: 22,
                                color: _document != null ? AppColors.accent : AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _document?.name ?? 'Unggah Dokumen',
                                    style: const TextStyle(
                                      fontSize: AppFonts.body,
                                      fontWeight: FontWeight.w400,
                                      color: AppColors.textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _document != null
                                        ? '${(_document!.size / 1024).toStringAsFixed(1)} KB'
                                        : 'PDF atau Gambar · Opsional',
                                    style: const TextStyle(
                                      fontSize: AppFonts.small,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_document != null)
                              GestureDetector(
                                onTap: () => setState(() => _document = null),
                                child: const Icon(Icons.cancel, size: 22, color: AppColors.danger),
                              )
                            else
                              const Icon(Icons.add_circle_outline, size: 22, color: AppColors.primary),
                          ],
                        ),
                      ),
                    ),

                    // ── Submit Button ─────────────────
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          boxShadow: AppShadows.glow,
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _isSubmitting ? null : _handleSubmit,
                          icon: _isSubmitting 
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white))
                              : const Icon(Icons.send, size: 18),
                          label: Text(
                            _isSubmitting ? 'Mengirim...' : 'Kirim Perizinan',
                            style: const TextStyle(fontSize: AppFonts.body, fontWeight: FontWeight.w400),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ),

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


}

class _PickerColumn extends StatelessWidget {
  final String label;
  final int value;
  final VoidCallback onUp;
  final VoidCallback onDown;

  const _PickerColumn({
    required this.label,
    required this.value,
    required this.onUp,
    required this.onDown,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: AppFonts.small,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onUp,
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(Icons.keyboard_arrow_up, size: 20, color: AppColors.primary),
          ),
        ),
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.borderLight,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Text(
              '$value',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w400,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
        GestureDetector(
          onTap: onDown,
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(Icons.keyboard_arrow_down, size: 20, color: AppColors.primary),
          ),
        ),
      ],
    );
  }
}
