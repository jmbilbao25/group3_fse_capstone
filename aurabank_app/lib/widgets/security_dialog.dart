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
        Icon(icon, size: 16, color: isDark ? const Color(0xFF6B7FFF) : const Color(0xFF2F78A8)),
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
    final isDesktop = alert.isDesktopSession;
    final isThird = alert.isThirdDevice && !isDesktop;

    Color badgeColor;
    IconData headerIcon;
    String headerTitle;

    if (isDesktop) {
      badgeColor = const Color(0xFF2F78A8);
      headerIcon = Icons.laptop_mac_rounded;
      headerTitle = 'Desktop Session Alert';
    } else if (isThird) {
      badgeColor = Colors.orange;
      headerIcon = Icons.swap_horizontal_circle_rounded;
      headerTitle = '3rd Mobile Login Request';
    } else {
      badgeColor = Colors.amber;
      headerIcon = Icons.warning_amber_rounded;
      headerTitle = 'Security Push Alert';
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF1E222B) : Colors.white,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: badgeColor.withAlpha(40),
              shape: BoxShape.circle,
            ),
            child: Icon(
              headerIcon,
              color: badgeColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              headerTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isDesktop) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF2F78A8).withAlpha(20),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF2F78A8).withAlpha(70)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Color(0xFF2F78A8), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Policy: 1 Web session permitted alongside 2 Mobile devices. Your mobile device remains the primary authenticator.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF1E3A8A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'A desktop/web session just logged into your AuraBank account. If this was not you, terminate the desktop session immediately.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[300] : Colors.grey[800],
              ),
            ),
          ] else if (isThird) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withAlpha(80)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'If you Approve, the current secondary device will be logged out and replaced. If you Deny, the new device will be removed.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.orange[200] : Colors.orange[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'A 3rd mobile device is requesting access. Only 1 secondary slot is available — approving this device will log out the current secondary.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[300] : Colors.grey[800],
              ),
            ),
          ] else ...[
            Text(
              'A new secondary mobile device just logged into your AuraBank account.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[300] : Colors.grey[800],
              ),
            ),
          ],
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
                _buildDetailRow(
                  isDesktop
                      ? 'Desktop Device'
                      : (isThird ? 'Incoming 3rd Mobile' : 'Device'),
                  alert.deviceName,
                  isDesktop ? Icons.laptop_mac_rounded : Icons.phone_android_rounded,
                  isDark,
                ),
                const SizedBox(height: 8),
                _buildDetailRow('IP Address', alert.clientIp, Icons.wifi_rounded, isDark),
                const SizedBox(height: 8),
                _buildDetailRow(
                  'Session Status',
                  isDesktop ? 'Active Web Session' : 'Pending Your Approval',
                  isDesktop ? Icons.check_circle_outline_rounded : Icons.lock_clock_rounded,
                  isDark,
                ),
                if (isThird && alert.replacedDeviceName.isNotEmpty) ...[
                  const Divider(height: 16),
                  _buildDetailRow(
                    'Will Deregister',
                    alert.replacedDeviceName,
                    Icons.phonelink_erase_rounded,
                    isDark,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isDesktop
                ? 'Desktop sessions can access web banking, but primary security alerts remain on this mobile.'
                : (isThird
                    ? 'Your Primary device is permanently bound. Only the Secondary device slot is replaceable.'
                    : 'Banking transactions are currently locked on this secondary device until you approve it.'),
            style: TextStyle(
              fontSize: 12,
              color: isDesktop ? const Color(0xFF2F78A8) : const Color(0xFFD97706),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      actions: [
        if (!isThird) ...[
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
                  SnackBar(
                    content: Text(isDesktop
                        ? 'Desktop session terminated. Access revoked.'
                        : 'Access revoked. Device has been logged out.'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            child: Text(isDesktop ? 'Revoke Desktop' : 'Revoke Access'),
          ),
          FilledButton.icon(
            icon: Icon(isDesktop ? Icons.thumb_up_rounded : Icons.check_circle_rounded, size: 16),
            style: FilledButton.styleFrom(
              backgroundColor: isDesktop ? const Color(0xFF2F78A8) : const Color(0xFF107C41),
            ),
            onPressed: () async {
              Navigator.of(context).pop();
              final devId = alert.deviceId.isNotEmpty ? alert.deviceId : alert.deviceName;
              if (!isDesktop) {
                await AuthApiService().approveDevice(deviceId: devId);
              }
              onHandled?.call();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isDesktop
                        ? 'Desktop session acknowledged.'
                        : 'Approved! ${alert.deviceName} authorized for transactions.'),
                    backgroundColor: isDesktop ? const Color(0xFF2F78A8) : const Color(0xFF107C41),
                  ),
                );
              }
            },
            label: Text(isDesktop ? 'Acknowledge' : 'Approve Access'),
          ),
        ] else ...[
          // 3rd-device: primary approves → 2nd device is revoked; deny → 3rd device is removed.
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
                    content: Text('Denied. The new device has been removed. Your existing secondary device remains.'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            child: const Text('Deny'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.swap_horizontal_circle_rounded, size: 16),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () async {
              Navigator.of(context).pop();
              final devId = alert.deviceId.isNotEmpty ? alert.deviceId : alert.deviceName;
              await AuthApiService().approveDevice(deviceId: devId);
              onHandled?.call();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Approved! ${alert.deviceName} is now active. Previous secondary device was logged out.'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            label: const Text('Approve & Replace'),
          ),
        ],
      ],
    );
  }
}

/// Dialog displayed on a device when its session is terminated —
/// either because a 3rd mobile signed in (auto-logout) or the primary
/// user manually revoked access.
class DeviceRevokedWarningDialog extends StatelessWidget {
  final String? deviceName;
  final VoidCallback onDismissed;
  /// 'auto' = 3rd device caused auto-logout; 'revoked' = primary manually revoked
  final String reason;

  const DeviceRevokedWarningDialog({
    super.key,
    this.deviceName,
    required this.onDismissed,
    this.reason = 'auto',
  });

  static Future<void> show(
    BuildContext context, {
    String? deviceName,
    required VoidCallback onDismissed,
    String reason = 'auto',
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DeviceRevokedWarningDialog(
        deviceName: deviceName,
        onDismissed: onDismissed,
        reason: reason,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRevoked = reason == 'revoked';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF1E222B) : Colors.white,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.redAccent.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isRevoked ? Icons.block_rounded : Icons.phonelink_erase_rounded,
              color: isRevoked ? Colors.redAccent : const Color(0xFFD97706),
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isRevoked ? 'Access Revoked' : 'Session Terminated',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isRevoked
                ? 'Your access to this AuraBank account has been revoked by the primary device holder. You have been logged out.'
                : 'This device has been automatically logged out because another mobile device signed in to your AuraBank account.',
            style: TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: isDark ? Colors.grey[300] : const Color(0xFF2E3A43),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF262C38)
                  : (isRevoked ? const Color(0xFFFFF1F1) : const Color(0xFFFEF3C7)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (isRevoked ? Colors.redAccent : const Color(0xFFF59E0B)).withAlpha(100),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: isRevoked ? Colors.redAccent : const Color(0xFFD97706),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isRevoked
                        ? 'If you believe this was a mistake, contact your primary account holder or sign in again to request re-authorization.'
                        : 'AuraBank allows a maximum of 2 mobile devices (1 Primary + 1 Secondary). When a 3rd device signs in, the existing secondary session is automatically terminated.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: isDark
                          ? (isRevoked ? const Color(0xFFFFCDD2) : const Color(0xFFFDE68A))
                          : (isRevoked ? const Color(0xFF8E2B26) : const Color(0xFF92400E)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          height: 46,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2F78A8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              onDismissed();
            },
            child: const Text('Return to Sign In', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}

