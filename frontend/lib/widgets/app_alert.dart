import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/theme.dart';

/// ─── AppAlert ──────────────────────────────────────────────
/// Reusable alert components matching the app's design system.
/// Replaces all native AlertDialog and SnackBar usage.
///
/// Usage:
///   AppAlert.show(context, title: '...', message: '...');
///   AppAlert.confirm(context, title: '...', message: '...', onConfirm: () {});
///   AppAlert.toast(context, message: '...');
/// ────────────────────────────────────────────────────────────

enum AlertType { success, error, warning, info }

class AppAlert {
  /// ─── Modal Bottom Sheet ─────────────────────────────
  /// For important info/success/error messages with a single action button.
  static void show(
    BuildContext context, {
    required String title,
    required String message,
    AlertType type = AlertType.info,
    VoidCallback? onDismiss,
  }) {
    final config = _alertConfig(type);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: type != AlertType.success,
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
                color: config.bgColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(config.icon, size: 36, color: config.color),
            ),
            const SizedBox(height: 16),
            Text(
              title,
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
                  backgroundColor: config.buttonColor,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  onDismiss != null ? 'Kembali' : 'Mengerti',
                  style: const TextStyle(fontSize: AppFonts.body, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ─── Confirm Bottom Sheet ───────────────────────────
  /// For destructive/important confirmations with Cancel + Confirm buttons.
  static void confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Konfirmasi',
    String cancelText = 'Batal',
    Color? confirmColor,
    IconData? icon,
    required VoidCallback onConfirm,
  }) {
    final effectiveColor = confirmColor ?? AppColors.danger;
    final effectiveIcon = icon ?? Icons.warning_amber_rounded;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
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
                color: effectiveColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(effectiveIcon, size: 36, color: effectiveColor),
            ),
            const SizedBox(height: 16),
            Text(
              title,
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
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.border, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    child: Text(
                      cancelText,
                      style: const TextStyle(fontSize: AppFonts.body, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      onConfirm();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: effectiveColor,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      confirmText,
                      style: const TextStyle(fontSize: AppFonts.body, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// ─── Toast Overlay ──────────────────────────────────
  /// Lightweight, auto-dismissing floating notification.
  static void toast(
    BuildContext context, {
    required String message,
    AlertType type = AlertType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlay = Overlay.of(context);
    final config = _alertConfig(type);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _ToastWidget(
        message: message,
        icon: config.icon,
        color: config.color,
        bgColor: config.bgColor,
        duration: duration,
        onDismiss: () => entry.remove(),
      ),
    );

    overlay.insert(entry);
  }

  /// ─── Config helper ──────────────────────────────────
  static _AlertConfig _alertConfig(AlertType type) {
    switch (type) {
      case AlertType.success:
        return _AlertConfig(
          icon: Icons.check_circle_rounded,
          color: AppColors.accent,
          bgColor: AppColors.accentSurface,
          buttonColor: AppColors.accent,
        );
      case AlertType.error:
        return _AlertConfig(
          icon: Icons.error_outline_rounded,
          color: AppColors.danger,
          bgColor: AppColors.dangerSurface,
          buttonColor: AppColors.primary,
        );
      case AlertType.warning:
        return _AlertConfig(
          icon: Icons.warning_amber_rounded,
          color: AppColors.warning,
          bgColor: AppColors.warningSurface,
          buttonColor: AppColors.primary,
        );
      case AlertType.info:
        return _AlertConfig(
          icon: Icons.info_outline_rounded,
          color: AppColors.primary,
          bgColor: AppColors.primarySurface,
          buttonColor: AppColors.primary,
        );
    }
  }
}

class _AlertConfig {
  final IconData icon;
  final Color color;
  final Color bgColor;
  final Color buttonColor;

  const _AlertConfig({
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.buttonColor,
  });
}

/// ─── Toast Widget (animated) ──────────────────────────
class _ToastWidget extends StatefulWidget {
  final String message;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final Duration duration;
  final VoidCallback onDismiss;

  const _ToastWidget({
    required this.message,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();

    Future.delayed(widget.duration, () {
      if (mounted) {
        _controller.reverse().then((_) => widget.onDismiss());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnim,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                boxShadow: AppShadows.medium,
                border: Border.all(color: widget.color.withValues(alpha: 0.2), width: 1),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: widget.bgColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(widget.icon, size: 20, color: widget.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: const TextStyle(
                        fontSize: AppFonts.caption,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      _controller.reverse().then((_) => widget.onDismiss());
                    },
                    child: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
