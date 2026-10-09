import 'package:flutter/material.dart';

import 'package:aurabank_core/services/bank_service.dart';
import 'package:aurabank_core/theme/aura_theme.dart';

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
    final name = BankService().user.name;
    final first = name.isNotEmpty ? name.split(' ').first : 'Elijah';
    final h = DateTime.now().hour;
    final greeting = h < 12 ? 'Good morning' : (h < 18 ? 'Good afternoon' : 'Good evening');

    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      color: AuraColors.canvas,
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$greeting, $first',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.5),
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded, color: AuraColors.textSecondary),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded, color: AuraColors.textSecondary),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: onQuickTransfer,
            icon: const Icon(Icons.north_east_rounded, size: 18),
            label: const Text('Send money'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44), padding: const EdgeInsets.symmetric(horizontal: 20)),
          ),
        ],
      ),
    );
  }
}
