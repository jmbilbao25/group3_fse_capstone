import 'package:flutter/material.dart';
import 'package:aurabank_core/theme/aura_theme.dart';
import 'package:aurabank_core/services/bank_service.dart';
import 'package:aurabank_core/widgets/aura_logo.dart';

class WebSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback? onLogout;

  const WebSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.onLogout,
  });

  static const _items = <(IconData, String)>[
    (Icons.space_dashboard_outlined, 'Overview'),
    (Icons.north_east_rounded, 'Transfer'),
    (Icons.credit_card_rounded, 'Cards'),
    (Icons.qr_code_scanner_rounded, 'Scan & pay'),
    (Icons.insights_rounded, 'Insights'),
    (Icons.shield_outlined, 'Security & profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final bank = BankService();
    final name = bank.user.name.isNotEmpty ? bank.user.name : 'Elijah Montefalco';
    final acct = bank.savingsAccountNumber;

    return Container(
      width: 248,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(22, 26, 22, 26),
            child: AuraWordmark(size: 34),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                for (var i = 0; i < _items.length; i++)
                  _NavItem(
                    icon: _items[i].$1,
                    label: _items[i].$2,
                    selected: selectedIndex == i,
                    onTap: () => onDestinationSelected(i),
                  ),
              ],
            ),
          ),
          const Spacer(),
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AuraColors.canvas, borderRadius: BorderRadius.circular(18)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Savings account', style: TextStyle(fontSize: 12, color: AuraColors.textMuted)),
                const SizedBox(height: 4),
                Text(
                  '•••• ${acct.substring(acct.length - 4)}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()]),
                ),
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AuraColors.mint,
                  child: Text(name[0].toUpperCase(),
                      style: const TextStyle(color: AuraColors.ink, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                ),
                IconButton(
                  tooltip: 'Sign out',
                  onPressed: onLogout,
                  icon: const Icon(Icons.logout_rounded, size: 19, color: AuraColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected ? AuraColors.tintPurple : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 20, color: selected ? AuraColors.ink : AuraColors.textMuted),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? AuraColors.ink : AuraColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
