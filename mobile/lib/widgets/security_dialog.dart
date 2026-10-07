import 'package:flutter/material.dart';
import '../services/auth_api_service.dart';
import '../services/notification_stream_service.dart';

class SecurityApprovalDialog extends StatelessWidget {
  final SecurityAlertEvent alert;
  final VoidCallback? onHandled;

  const SecurityApprovalDialog({
    super.key,
    required this.alert,
    this.onHandled,
  });

  static Future<void> show(BuildContext context, SecurityAlertEvent alert, {VoidCallback? onHandled}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SecurityApprovalDialog(alert: alert, onHandled: onHandled),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 16, color: isDark ? const Color(0xFF6B7FFF) : const Color(0xFF3A4CD6)),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey[400] : Colors.grey[700],
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF1E222B) : Colors.white,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.withAlpha(40),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Colors.amber,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Security Push Alert',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'A new device just logged into your AuraBank account from another location.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey[300] : Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF282E3A) : const Color(0xFFF3F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF384050) : const Color(0xFFE2E6EF),
              ),
            ),
            child: Column(
              children: [
                _buildDetailRow('Device', alert.deviceName, Icons.phone_android_rounded, isDark),
                const SizedBox(height: 8),
                _buildDetailRow('IP Address', alert.clientIp, Icons.wifi_rounded, isDark),
                const SizedBox(height: 8),
                _buildDetailRow('Status', 'Pending Your Approval', Icons.lock_clock_rounded, isDark),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Banking transactions are currently locked on this secondary device until you approve it.',
            style: TextStyle(fontSize: 12, color: Color(0xFFD97706), fontWeight: FontWeight.w500),
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      actions: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.redAccent,
            side: const BorderSide(color: Colors.redAccent),
          ),
          onPressed: () async {
            Navigator.of(context).pop();
            final devId = alert.deviceId.isNotEmpty ? alert.deviceId : alert.deviceName;
            await AuthApiService().revokeDevice(deviceId: devId);
            onHandled?.call();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Remote session revoked. Access blocked.'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            }
          },
          child: const Text('Revoke Access'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.check_circle_rounded, size: 16),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF107C41),
          ),
          onPressed: () async {
            Navigator.of(context).pop();
            final devId = alert.deviceId.isNotEmpty ? alert.deviceId : alert.deviceName;
            await AuthApiService().approveDevice(deviceId: devId);
            onHandled?.call();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Approved! ${alert.deviceName} authorized for transactions.'),
                  backgroundColor: const Color(0xFF107C41),
                ),
              );
            }
          },
          label: const Text('Approve Access'),
        ),
      ],
    );
  }
}
