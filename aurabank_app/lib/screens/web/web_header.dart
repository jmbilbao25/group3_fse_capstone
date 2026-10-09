import 'package:flutter/material.dart';
import '../../theme/aura_theme.dart';
import '../../services/bank_service.dart';

class WebHeader extends StatelessWidget {
  final VoidCallback onQuickTransfer;
  final VoidCallback onRefresh;

  const WebHeader({
    super.key,
    required this.onQuickTransfer,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final user = BankService().user;
    final userName = user.name.isNotEmpty ? user.name : 'Elijah Montefalco';

    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1.0),
        ),
      ),
      child: Row(
        children: [
          // Greeting & Time of day
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Text(
                      'Welcome back, $userName',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shield_rounded, size: 12, color: Color(0xFF059669)),
                          SizedBox(width: 4),
                          Text(
                            'LIVE CBS LEDGER',
                            style: TextStyle(
                              color: Color(0xFF047857),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'Aura Bank Corporate Core • Real-Time Settlement Engine',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),

          // Actions
          IconButton(
            tooltip: 'Sync with Ledger',
            icon: const Icon(Icons.sync_rounded, color: Color(0xFF4B5563), size: 21),
            onPressed: onRefresh,
          ),
          const SizedBox(width: 8),

          // Notification Bell
          Stack(
            children: [
              IconButton(
                tooltip: 'Notifications',
                icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF4B5563), size: 22),
                onPressed: () {},
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),

          // Primary Quick Transfer CTA
          ElevatedButton.icon(
            onPressed: onQuickTransfer,
            icon: const Icon(Icons.send_rounded, size: 16, color: Colors.white),
            label: const Text(
              'Send Money',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                letterSpacing: 0.2,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AuraColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}
