import 'package:flutter/material.dart';
import '../services/auth_api_service.dart';

/// A reusable guard widget for UI developers.
/// Wrap any button or transaction form with [RequireDeviceApproval] to automatically
/// disable actions on secondary devices until authorized by the primary device.
class RequireDeviceApproval extends StatelessWidget {
  final Widget child;
  final String actionLabel;
  final bool showNoticeBanner;

  const RequireDeviceApproval({
    super.key,
    required this.child,
    this.actionLabel = 'Banking transactions',
    this.showNoticeBanner = true,
  });

  /// Convenience helper to check before manual actions
  static bool canTransact(BuildContext context, {bool showWarningSnackBar = true}) {
    final isApproved = AuthApiService().isDeviceApproved;
    if (!isApproved && showWarningSnackBar) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Action locked: Secondary device requires approval from your primary device.'),
          backgroundColor: Color(0xFFD97706),
          duration: Duration(seconds: 4),
        ),
      );
    }
    return isApproved;
  }

  @override
  Widget build(BuildContext context) {
    final isApproved = AuthApiService().isDeviceApproved;

    if (isApproved) {
      return child;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showNoticeBanner) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2C2213) : const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0xFF78350F) : const Color(0xFFFDE68A),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, color: Color(0xFFD97706), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$actionLabel are disabled until authorized by your primary device.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        Opacity(
          opacity: 0.55,
          child: AbsorbPointer(
            absorbing: true,
            child: child,
          ),
        ),
      ],
    );
  }
}
