import 'package:flutter/material.dart';
import 'package:aurabank_core/services/bank_service.dart';
import 'package:aurabank_core/models/bank_models.dart';
import 'package:aurabank_core/theme/aura_theme.dart';
import 'package:aurabank_core/widgets/aura_card.dart';
import 'package:aurabank_core/widgets/aurora_background.dart';
import '../transfer/web_transfer_screen.dart';

class WebDashboardScreen extends StatefulWidget {
  final Function(int)? onNavigateTab;
  final void Function(QuickTransferDraft draft)? onQuickTransfer;

  const WebDashboardScreen({super.key, this.onNavigateTab, this.onQuickTransfer});

  @override
  State<WebDashboardScreen> createState() => _WebDashboardScreenState();
}

class _WebDashboardScreenState extends State<WebDashboardScreen> {
  final BankService _bankService = BankService();
  bool _isBalanceVisible = true;
  bool _isAccountNumVisible = true;
  String _selectedTxnFilter = 'All';

  // Quick Send Form Controllers
  final TextEditingController _recipientController = TextEditingController(text: 'Angel Lou F. Yabut');
  final TextEditingController _amountController = TextEditingController(text: '1500');
  String _selectedBank = 'Aura Bank';

  @override
  void initState() {
    super.initState();
    _bankService.addListener(_onServiceUpdate);
  }

  @override
  void dispose() {
    _bankService.removeListener(_onServiceUpdate);
    _recipientController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  String _formatCurrency(double amount) {
    final parts = amount.toStringAsFixed(2).split('.');
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    final formattedInt = parts[0].replaceAllMapped(reg, (Match m) => '${m[1]},');
    return '₱$formattedInt.${parts[1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AuraColors.canvas,
      child: LayoutBuilder(builder: (context, c) {
        final main = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBalanceHeroCard(),
            const SizedBox(height: 20),
            _buildKpiMetricsRow(),
            const SizedBox(height: 24),
            _buildTransactionLedgerTable(),
          ],
        );
        final side = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildQuickSendMoneyPanel(),
            const SizedBox(height: 20),
            _buildQuickCardControlPanel(),
          ],
        );
        // Below ~1100px of content the side panels drop under the main column
        // instead of squeezing both until text wraps by the letter.
        final twoColumn = c.maxWidth >= 1100;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(32, 8, 32, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1360),
              child: twoColumn
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 65, child: main),
                        const SizedBox(width: 24),
                        Expanded(flex: 35, child: side),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        main,
                        const SizedBox(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildQuickSendMoneyPanel()),
                            const SizedBox(width: 20),
                            Expanded(child: _buildQuickCardControlPanel()),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
        );
      }),
    );
  }

  // --- 1. HERO: balance under the aurora, with the wallet card in hand ---
  Widget _buildBalanceHeroCard() {
    final balance = _bankService.availableBalance;
    final accountNum = _bankService.savingsAccountNumber;
    final card = _bankService.cards.isNotEmpty ? _bankService.cards.first : null;
    final muted = Colors.white.withValues(alpha: 0.66);

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: SizedBox(
        height: 260,
        child: AuroraBackground(
          intensity: 0.85,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 28, 28, 28),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Savings account', style: TextStyle(color: muted, fontSize: 14)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _isBalanceVisible ? _formatCurrency(balance) : '₱ ••••••••',
                                style: const TextStyle(
                                  fontSize: 44,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  letterSpacing: -1.4,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: _isBalanceVisible ? 'Hide balance' : 'Show balance',
                            icon: Icon(_isBalanceVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: muted, size: 20),
                            onPressed: () => setState(() => _isBalanceVisible = !_isBalanceVisible),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            _isAccountNumVisible ? accountNum : '•••• •••• ${accountNum.substring(accountNum.length - 4)}',
                            style: TextStyle(color: muted, fontSize: 14, letterSpacing: 0.6, fontFeatures: const [FontFeature.tabularFigures()]),
                          ),
                          IconButton(
                            tooltip: 'Show account number',
                            icon: Icon(_isAccountNumVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: muted, size: 16),
                            onPressed: () => setState(() => _isAccountNumVisible = !_isAccountNumVisible),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Wrap(
                        spacing: 10,
                        children: [
                          FilledButton.icon(
                            onPressed: () => widget.onNavigateTab?.call(1),
                            icon: const Icon(Icons.north_east_rounded, size: 18),
                            label: const Text('Send'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AuraColors.mint,
                              foregroundColor: AuraColors.ink,
                              minimumSize: const Size(0, 44),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => widget.onNavigateTab?.call(4),
                            icon: const Icon(Icons.receipt_long_rounded, size: 17),
                            label: const Text('Statement'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                              minimumSize: const Size(0, 44),
                              shape: const StadiumBorder(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (card != null && MediaQuery.sizeOf(context).width >= 1180)
                  SizedBox(
                    width: 300,
                    child: AspectRatio(
                      aspectRatio: kCardAspect,
                      child: CardTilt(builder: (context, sheen) => AuraCardFace(card: card, sheen: sheen)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- 2. KPI METRICS ---
  Widget _buildKpiMetricsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildMetricTile(
            title: 'Monthly Inflow',
            value: '+ ₱125,000.00',
            trend: '+ 12.4% vs last mo',
            trendColor: const Color(0xFF17805F),
            icon: Icons.arrow_downward_rounded,
            iconBg: const Color(0xFFE4F5EE),
            iconColor: const Color(0xFF17805F),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _buildMetricTile(
            title: 'Monthly Outflow',
            value: '- ₱45,820.00',
            trend: 'Within budget',
            trendColor: const Color(0xFF7D8892),
            icon: Icons.arrow_upward_rounded,
            iconBg: const Color(0xFFFDF3F2),
            iconColor: const Color(0xFFC8423B),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String trend,
    required Color trendColor,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEAECEE)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF7D8892),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF10171C),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  trend,
                  style: TextStyle(
                    color: trendColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 3. TRANSACTIONS LEDGER TABLE ---
  Widget _buildTransactionLedgerTable() {
    final allTxns = _bankService.statements.values.expand((s) => s.transactions).toList();
    final txns = allTxns.where((t) {
      if (_selectedTxnFilter == 'Credit') return t.isIncoming;
      if (_selectedTxnFilter == 'Debit') return !t.isIncoming;
      return true;
    }).take(8).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEAECEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table Header Bar with Filters
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recent Ledger Activity',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF10171C),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Real-time transaction settlement history',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7D8892),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    _buildFilterChip('All'),
                    const SizedBox(width: 6),
                    _buildFilterChip('Credit'),
                    const SizedBox(width: 6),
                    _buildFilterChip('Debit'),
                  ],
                ),
              ],
            ),
          ),

          const Divider(color: Color(0xFFF1F3F4), height: 1),

          // Transactions List
          if (txns.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text('No transaction history found', style: TextStyle(color: Color(0xFF9AA3AB))),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: txns.length,
              separatorBuilder: (_, __) => const Divider(color: Color(0xFFF7F7F7), height: 1),
              itemBuilder: (context, index) {
                final txn = txns[index];
                final isCredit = txn.isIncoming;
                final isFailed = txn.status == TransactionStatus.failed;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: isCredit ? const Color(0xFFE4F5EE) : const Color(0xFFF5F3FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                          color: isCredit ? const Color(0xFF17805F) : AuraColors.primary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              txn.counterparty,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF10171C),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${txn.transferSubtitle} • ${txn.displayTime}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF7D8892),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${isCredit ? "+ " : "- "}₱${txn.formattedIntegerAmount}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: isCredit ? const Color(0xFF17805F) : const Color(0xFF10171C),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isFailed
                                  ? const Color(0xFFFDF3F2)
                                  : const Color(0xFFE4F5EE),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isFailed ? 'FAILED' : 'SETTLED',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: isFailed
                                    ? const Color(0xFFC8423B)
                                    : const Color(0xFF17805F),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedTxnFilter == label;
    return InkWell(
      onTap: () => setState(() => _selectedTxnFilter = label),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AuraColors.primary : const Color(0xFFF1F3F4),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : const Color(0xFF47525C),
          ),
        ),
      ),
    );
  }

  // --- 4. RIGHT PANEL: QUICK SEND MONEY ---
  Widget _buildQuickSendMoneyPanel() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEAECEE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.bolt_rounded, color: Color(0xFFF59E0B), size: 20),
                  SizedBox(width: 6),
                  Text(
                    'Quick Transfer',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF10171C),
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  if (widget.onNavigateTab != null) {
                    widget.onNavigateTab!(1);
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const WebTransferScreen()),
                    );
                  }
                },
                child: const Text('Full Flow →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Bank Selector
          const Text(
            'DESTINATION BANK',
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF7D8892)),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFEAECEE)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedBank,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'Aura Bank', child: Text('Aura Bank', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                  DropdownMenuItem(value: 'MeyBank', child: Text('MeyBank (Group 2 Partner)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                  DropdownMenuItem(value: 'Apex Digital Bank', child: Text('Apex Digital Bank (Group 1 Partner)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                  DropdownMenuItem(value: 'Nexus Core Bank', child: Text('Nexus Core Bank (Group 4 Partner)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedBank = val);
                },
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Recipient Input
          const Text(
            'ACCOUNT OR MOBILE NUMBER',
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF7D8892)),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _recipientController,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF7F7F7),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFEAECEE))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFEAECEE))),
              prefixIcon: const Icon(Icons.person_outline_rounded, size: 18, color: Color(0xFF9AA3AB)),
            ),
          ),

          const SizedBox(height: 14),

          // Amount Input
          const Text(
            'AMOUNT (PHP)',
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF7D8892)),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF7F7F7),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFEAECEE))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFEAECEE))),
              prefixText: '₱ ',
              prefixStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF10171C)),
            ),
          ),

          const SizedBox(height: 18),

          // Submit CTA
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: () {
                final draft = QuickTransferDraft(
                  accountNumber: _recipientController.text,
                  amount: _amountController.text,
                  bank: _selectedBank,
                );
                if (widget.onQuickTransfer != null) {
                  widget.onQuickTransfer!(draft);
                } else if (widget.onNavigateTab != null) {
                  widget.onNavigateTab!(1);
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => WebTransferScreen(draft: draft)),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AuraColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('Proceed to Transfer', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  // --- 5. RIGHT PANEL: QUICK CARD CONTROLS ---
  Widget _buildQuickCardControlPanel() {
    final card = _bankService.cards.isNotEmpty ? _bankService.cards.first : null;
    final isLocked = card?.isLocked ?? false;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEAECEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                card != null ? '${card.title} ending ${card.last4}' : 'Aura Debit',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF10171C),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isLocked ? const Color(0xFFFDF3F2) : const Color(0xFFE4F5EE),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isLocked ? 'FROZEN' : 'ACTIVE',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: isLocked ? const Color(0xFFC8423B) : const Color(0xFF17805F),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            card != null ? '${card.cardNumber}  |  EXP ${card.expiry}' : '•••• •••• •••• 4410  |  EXP 09/29',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF7D8892),
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Instant Freeze Card', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              Switch(
                value: isLocked,
                activeThumbColor: const Color(0xFFC8423B),
                onChanged: (val) {
                  _bankService.toggleCardLock(0);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
