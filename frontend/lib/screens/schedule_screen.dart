import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/theme.dart';
import '../constants/mock_data.dart';
import '../services/api_service.dart';
import '../services/app_time.dart';

/// ScheduleScreen — Weekly schedule with day tabs
const _days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late int _selectedDay;
  bool _isLoading = true;

  // Cache: fetch all days once, filter locally on tab switch
  Map<String, List<ScheduleItem>> _weeklyCache = {};

  @override
  void initState() {
    super.initState();
    final today = AppTime.now().weekday; // 1=Mon ... 7=Sun
    if (today == 7) {
      _selectedDay = 0; // Sunday → show Monday
    } else if (today == 6) {
      _selectedDay = 5; // Saturday
    } else {
      _selectedDay = today - 1;
    }
    _fetchAllSchedules();
  }

  /// Fetch all 6 days in parallel once, then cache
  Future<void> _fetchAllSchedules() async {
    setState(() => _isLoading = true);

    try {
      // Fire all 6 requests in parallel
      final futures = _days.map((day) => ApiService.getSchedulesByDay(day));
      final results = await Future.wait(futures);

      if (mounted) {
        final cache = <String, List<ScheduleItem>>{};
        for (int i = 0; i < _days.length; i++) {
          cache[_days[i]] = results[i];
        }
        setState(() {
          _weeklyCache = cache;
          _isLoading = false;
        });
      }
    } catch (e) {
      // Fallback to mock data
      if (mounted) {
        setState(() {
          _weeklyCache = Map<String, List<ScheduleItem>>.from(mockWeeklySchedule);
          _isLoading = false;
        });
      }
    }
  }

  void _selectDay(int index) {
    if (index == _selectedDay) return;
    setState(() => _selectedDay = index);
    // No API call — just re-render from cache (instant!)
  }

  List<ScheduleItem> get _daySchedule =>
      _weeklyCache[_days[_selectedDay]] ?? [];

  @override
  Widget build(BuildContext context) {
    final daySchedule = _daySchedule;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
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
                    'Jadwal Kuliah',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w400,
                      color: AppColors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Semester 4',
                    style: TextStyle(
                      fontSize: AppFonts.caption,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),

            // Day tabs
            Container(
              padding: const EdgeInsets.only(top: 16),
              child: SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  separatorBuilder: (context2, index2) => const SizedBox(width: 8),
                  itemCount: _days.length,
                  itemBuilder: (context, i) {
                    final isActive = _selectedDay == i;
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _selectDay(i),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          decoration: BoxDecoration(
                            color: isActive ? AppColors.primary : AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          child: Text(
                            _days[i],
                            style: TextStyle(
                              fontSize: AppFonts.caption,
                              fontWeight: FontWeight.w400,
                              color: isActive ? AppColors.white : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Schedule list
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    )
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: _fetchAllSchedules,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                        child: daySchedule.isEmpty
                            ? Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(48),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(AppRadius.lg),
                                  boxShadow: AppShadows.card,
                                ),
                                child: Column(
                                  children: [
                                    const Icon(Icons.coffee, size: 48, color: AppColors.textMuted),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Tidak ada jadwal',
                                      style: TextStyle(
                                        fontSize: AppFonts.body,
                                        fontWeight: FontWeight.w400,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Tidak ada jadwal kuliah untuk hari ini. Selamat beristirahat!',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: AppFonts.caption,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Column(
                                children: [
                                  ...daySchedule.asMap().entries.map((entry) {
                                    final index = entry.key;
                                    final item = entry.value;
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Card content
                                          Expanded(
                                            child: Container(
                                              margin: const EdgeInsets.only(left: 10, bottom: 10),
                                              padding: const EdgeInsets.all(16),
                                              decoration: BoxDecoration(
                                                color: AppColors.surface,
                                                borderRadius: BorderRadius.circular(AppRadius.md),
                                                boxShadow: AppShadows.card,
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Text(
                                                        item.time,
                                                        style: const TextStyle(
                                                          fontSize: AppFonts.small,
                                                          fontWeight: FontWeight.w400,
                                                          color: AppColors.textSecondary,
                                                        ),
                                                      ),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: AppColors.borderLight,
                                                          borderRadius: BorderRadius.circular(6),
                                                        ),
                                                        child: Text(
                                                          item.room,
                                                          style: const TextStyle(
                                                            fontSize: AppFonts.small,
                                                            fontWeight: FontWeight.w400,
                                                            color: AppColors.textMuted,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    item.subject,
                                                    style: const TextStyle(
                                                      fontSize: AppFonts.body,
                                                      fontWeight: FontWeight.w400,
                                                      color: AppColors.textPrimary,
                                                    ),
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
                                                          item.lecturer,
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
                                  const SizedBox(height: 20),
                                ],
                              ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
