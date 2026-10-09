import 'package:flutter/material.dart';

import '../../models/bank_models.dart';
import '../../services/bank_service.dart';
import '../../theme/aura_theme.dart';
import '../../widgets/aura_card.dart';
import '../../widgets/motion.dart';
import '../../widgets/transaction_tile.dart';
import '../cards/cards_screen.dart' show CardActionButton;
import '../transfer/send_money_screen.dart';

class HomeScreen extends StatefulWidget {
  final Function(int)? onNavigateTab;

  const HomeScreen({super.key, this.onNavigateTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final BankService _bankService = BankService();
  bool _isBalanceVisible = true;
  bool _isAccountNumVisible = false;

  @override
  void initState() {
    super.initState();
    _bankService.addListener(_onServiceUpdate);
  }

  @override
  void dispose() {
    _bankService.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  void _openTransfer() => Navigator.of(context)
      .push(MaterialPageRoute(builder: (context) => const SendMoneyScreen()));

  void _toggleFreeze() {
    if (_bankService.cards.isEmpty) return;
    _bankService.toggleCardLock(0);
    final card = _bankService.cards.first;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(card.isLocked
            ? 'Card ending ${card.last4} is frozen.'
            : 'Card ending ${card.last4} is active again.'),
      ));
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final card =
        _bankService.cards.isNotEmpty ? _bankService.cards.first : null;
    final recent = _bankService.recentTransactions;
    final payees = <String, BankTransaction>{
      for (final t in recent.where((t) => !t.isIncoming)) t.counterparty: t,
    }.values.toList();

    return Scaffold(
      backgroundColor: AuraColors.canvas,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Reveal(child: _buildHeader()),
            const SizedBox(height: 24),
            Row(
              children: [
                const Text('Your wallet',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3)),
                const SizedBox(width: 12),
                const Spacer(),
                Flexible(
                  flex: 3,
                  child: GestureDetector(
                    onTap: () => setState(
                        () => _isAccountNumVisible = !_isAccountNumVisible),
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            _isAccountNumVisible
                                ? 'Savings ${_bankService.savingsAccountNumber}'
                                : 'Savings •••• ${_bankService.savingsAccountNumber.substring(_bankService.savingsAccountNumber.length - 4)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13,
                                color: AuraColors.textMuted,
                                fontFeatures: [FontFeature.tabularFigures()]),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          _isAccountNumVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 16,
                          color: AuraColors.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (card != null)
              Reveal(
                delay: const Duration(milliseconds: 80),
                offset: 28,
                duration: const Duration(milliseconds: 720),
                child: Semantics(
                  label:
                      'Available balance ${_isBalanceVisible ? _formatBalance(_bankService.availableBalance) : 'hidden'}',
                  child: AspectRatio(
                    aspectRatio: kCardAspect,
                    child: CardTilt(
                      maxTilt: 0.08,
                      builder: (context, sheen) => AuraCardFace(
                        card: card,
                        sheen: sheen,
                        balance: _formatBalance(_bankService.availableBalance),
                        balanceValue: _bankService.availableBalance,
                        formatBalance: _formatBalance,
                        balanceVisible: _isBalanceVisible,
                        onToggleBalance: () => setState(
                            () => _isBalanceVisible = !_isBalanceVisible),
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: () =>
                    setState(() => _isBalanceVisible = !_isBalanceVisible),
                icon: Icon(
                    _isBalanceVisible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 18),
                label:
                    Text(_isBalanceVisible ? 'Hide balance' : 'Show balance'),
                style: TextButton.styleFrom(
                    foregroundColor: AuraColors.textSecondary),
              ),
            ),
            const SizedBox(height: 6),
            Reveal(
              delay: const Duration(milliseconds: 200),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CardActionButton(
                      icon: Icons.north_east_rounded,
                      label: 'Send',
                      highlighted: true,
                      onTap: _openTransfer),
                  CardActionButton(
                      icon: Icons.qr_code_scanner_rounded,
                      label: 'Scan',
                      onTap: () => widget.onNavigateTab?.call(2)),
                  CardActionButton(
                    icon: card?.isLocked == true
                        ? Icons.lock_open_rounded
                        : Icons.ac_unit_rounded,
                    label: card?.isLocked == true ? 'Unfreeze' : 'Freeze',
                    onTap: _toggleFreeze,
                  ),
                  CardActionButton(
                      icon: Icons.insights_rounded,
                      label: 'Insights',
                      onTap: () => widget.onNavigateTab?.call(3)),
                ],
              ),
            ),
            const SizedBox(height: 30),
            const Text('Activities',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3)),
            const SizedBox(height: 12),
            if (payees.isNotEmpty)
              Reveal(
                  delay: const Duration(milliseconds: 280),
                  child: _RecentPayees(payees: payees, onTap: _openTransfer)),
            const SizedBox(height: 22),
            Row(
              children: [
                const Text('Transactions',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton(
                  onPressed: () => widget.onNavigateTab?.call(3),
                  style: TextButton.styleFrom(
                      foregroundColor: AuraColors.textMuted),
                  child: const Text('See all'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            for (final (i, txn) in recent.indexed)
              Reveal(
                delay: Reveal.stagger(i, base: 340),
                child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TransactionTile(txn: txn)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final name = _bankService.user.name.isNotEmpty
        ? _bankService.user.name
        : 'Elijah Montefalco';
    final parts = name.trim().split(RegExp(r'\s+'));
    final short =
        parts.length > 1 ? '${parts.first} ${parts.last[0]}.' : parts.first;
    final initials =
        parts.length > 1 ? '${parts.first[0]}${parts.last[0]}' : parts.first[0];

    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
              color: AuraColors.mint, shape: BoxShape.circle),
          child: Text(initials.toUpperCase(),
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: AuraColors.ink)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_greeting,
                  style: const TextStyle(
                      fontSize: 13, color: AuraColors.textMuted)),
              const SizedBox(height: 1),
              Text(short,
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2)),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Notifications',
          onPressed: () {},
          icon: const Icon(Icons.notifications_none_rounded,
              color: AuraColors.ink),
        ),
      ],
    );
  }

  String _formatBalance(double amount) {
    final fixed = amount.toStringAsFixed(2).split('.');
    final whole = fixed[0].replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return '₱ $whole.${fixed[1]}';
  }
}

class _RecentPayees extends StatelessWidget {
  const _RecentPayees({required this.payees, required this.onTap});

  final List<BankTransaction> payees;
  final VoidCallback onTap;

  static const _fills = [
    AuraColors.mint,
    AuraColors.sky,
    AuraColors.periwinkle,
    Color(0xFFF6D7B8)
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(22)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Recent transfers',
                    style:
                        TextStyle(fontSize: 13, color: AuraColors.textMuted)),
                const SizedBox(height: 10),
                SizedBox(
                  height: 40,
                  child: Stack(
                    children: [
                      for (var i = 0; i < payees.length && i < 5; i++)
                        Positioned(
                          left: i * 30.0,
                          child: Tooltip(
                            message: payees[i].counterparty,
                            child: Container(
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _fills[i % _fills.length],
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2.5),
                              ),
                              child: Text(payees[i].initial,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          IconButton.filled(
            tooltip: 'New transfer',
            onPressed: onTap,
            icon: const Icon(Icons.add_rounded),
            style: IconButton.styleFrom(
                backgroundColor: AuraColors.sky,
                foregroundColor: AuraColors.ink,
                fixedSize: const Size(44, 44)),
          ),
        ],
      ),
    );
  }
}
