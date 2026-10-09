import 'package:flutter/material.dart';
import 'package:aurabank_core/services/bank_service.dart';

class WebHeader extends StatelessWidget {
  final VoidCallback? onQuickTransfer;
  final VoidCallback? onRefresh;

  const WebHeader({
    super.key,
    this.onQuickTransfer,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final user = BankService().user;
    final userName = user.name.isNotEmpty ? user.name : 'Elijah Riley Montefalco';

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
          // Greeting
          Expanded(
            child: Text(
              'Welcome back, $userName',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
                letterSpacing: -0.3,
              ),
            ),
          ),

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
        ],
      ),
    );
  }
}
