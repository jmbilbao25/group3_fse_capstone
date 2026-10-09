import 'package:flutter/material.dart';
import '../../services/bank_service.dart';
import '../../models/bank_models.dart';
import '../../theme/aura_theme.dart';
import '../transfer/send_money_screen.dart';

class WebDashboardScreen extends StatefulWidget {
  final Function(int)? onNavigateTab;

  const WebDashboardScreen({super.key, this.onNavigateTab});

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
      color: const Color(0xFFF9FAFB),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // LEFT / MAIN COLUMN (Dashboard Ledger & Analytics)
            Expanded(
              flex: 65,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBalanceHeroCard(),
                  const SizedBox(height: 20),
                  _buildKpiMetricsRow(),
                  const SizedBox(height: 24),
                  _buildTransactionLedgerTable(),
                ],
              ),
            ),

            const SizedBox(width: 24),

            // RIGHT COLUMN (Embedded Quick Transfer & Card Control)
            Expanded(
              flex: 35,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildQuickSendMoneyPanel(),
                  const SizedBox(height: 20),
                  _buildQuickCardControlPanel(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 1. HERO BALANCE CARD ---
  Widget _buildBalanceHeroCard() {
    final balance = _bankService.availableBalance;
    final accountNum = _bankService.savingsAccountNumber;

    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E0854), Color(0xFF5B1DA8), Color(0xFF380084)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF380084).withValues(alpha: 0.22),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'PRIMARY CHECKING ACCOUNT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      _isBalanceVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: Colors.white70,
                      size: 18,
                    ),
                    onPressed: () => setState(() => _isBalanceVisible = !_isBalanceVisible),
                  ),
                ],
              ),
              const Row(
                children: [
                  Icon(Icons.wifi_rounded, color: Colors.white70, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'AURA PLATINUM',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Balance Display
          Text(
            _isBalanceVisible ? _formatCurrency(balance) : '₱ ••••••••',
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 16),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 14),

          // Account Details & Quick Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    _isAccountNumVisible ? accountNum : '•••• •••• ••••',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'Toggle visibility',
                    icon: Icon(
                      _isAccountNumVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: Colors.white70,
                      size: 16,
                    ),
                    onPressed: () => setState(() => _isAccountNumVisible = !_isAccountNumVisible),
                  ),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      if (widget.onNavigateTab != null) widget.onNavigateTab!(4);
                    },
                    icon: const Icon(Icons.receipt_long_rounded, size: 14, color: Colors.white),
                    label: const Text('Statement of Account', style: TextStyle(color: Colors.white, fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white38),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
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
            trendColor: const Color(0xFF059669),
            icon: Icons.arrow_downward_rounded,
            iconBg: const Color(0xFFECFDF5),
            iconColor: const Color(0xFF059669),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _buildMetricTile(
            title: 'Monthly Outflow',
            value: '- ₱45,820.00',
            trend: 'Within budget',
            trendColor: const Color(0xFF6B7280),
            icon: Icons.arrow_upward_rounded,
            iconBg: const Color(0xFFFEF2F2),
            iconColor: const Color(0xFFDC2626),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _buildMetricTile(
            title: 'Shield Gate Protection',
            value: 'Level 4 Active',
            trend: 'Zero active alerts',
            trendColor: const Color(0xFF059669),
            icon: Icons.security_rounded,
            iconBg: const Color(0xFFF5F3FF),
            iconColor: AuraColors.primary,
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
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
                    color: Color(0xFF6B7280),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF111827),
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
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
                        color: Color(0xFF111827),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Real-time transaction settlement history',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
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

          const Divider(color: Color(0xFFF3F4F6), height: 1),

          // Transactions List
          if (txns.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text('No transaction history found', style: TextStyle(color: Color(0xFF9CA3AF))),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: txns.length,
              separatorBuilder: (_, __) => const Divider(color: Color(0xFFF9FAFB), height: 1),
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
                          color: isCredit ? const Color(0xFFECFDF5) : const Color(0xFFF5F3FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                          color: isCredit ? const Color(0xFF059669) : AuraColors.primary,
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
                                color: Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${txn.transferSubtitle} • ${txn.displayTime}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF6B7280),
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
                              color: isCredit ? const Color(0xFF059669) : const Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isFailed
                                  ? const Color(0xFFFEF2F2)
                                  : const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isFailed ? 'FAILED' : 'SETTLED',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: isFailed
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF059669),
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
          color: isSelected ? AuraColors.primary : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : const Color(0xFF4B5563),
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
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
                      color: Color(0xFF111827),
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
                      MaterialPageRoute(builder: (_) => const SendMoneyScreen()),
                    );
                  }
                },
                child: const Text('Full Flow →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Recipient Quick Pills
          const Text(
            'RECENT BENEFICIARIES',
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildBeneficiaryAvatar('Angel Lou', 'AY'),
                const SizedBox(width: 8),
                _buildBeneficiaryAvatar('Mae G.', 'MM'),
                const SizedBox(width: 8),
                _buildBeneficiaryAvatar('Jessie Mae', 'JD'),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Bank Selector
          const Text(
            'DESTINATION BANK',
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedBank,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'Aura Bank', child: Text('Aura Bank (Instant • Free)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                  DropdownMenuItem(value: 'BDO Unibank', child: Text('BDO Unibank', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                  DropdownMenuItem(value: 'BPI', child: Text('Bank of the Philippine Islands', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                  DropdownMenuItem(value: 'GCash', child: Text('GCash Wallet', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
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
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _recipientController,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              prefixIcon: const Icon(Icons.person_outline_rounded, size: 18, color: Color(0xFF9CA3AF)),
            ),
          ),

          const SizedBox(height: 14),

          // Amount Input
          const Text(
            'AMOUNT (PHP)',
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              prefixText: '₱ ',
              prefixStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
            ),
          ),

          const SizedBox(height: 18),

          // Submit CTA
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: () {
                if (widget.onNavigateTab != null) {
                  widget.onNavigateTab!(1);
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SendMoneyScreen()),
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

  Widget _buildBeneficiaryAvatar(String name, String initials) {
    return InkWell(
      onTap: () {
        setState(() => _recipientController.text = name);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 10,
              backgroundColor: const Color(0xFF380084),
              child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 6),
            Text(name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
          ],
        ),
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
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                card != null ? 'Aura ${card.title} Card' : 'Aura Platinum Card',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isLocked ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isLocked ? 'FROZEN' : 'ACTIVE',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: isLocked ? const Color(0xFFDC2626) : const Color(0xFF059669),
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
              color: Color(0xFF6B7280),
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
                activeThumbColor: const Color(0xFFDC2626),
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
