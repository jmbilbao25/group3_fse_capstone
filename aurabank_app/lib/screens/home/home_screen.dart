import 'package:flutter/material.dart';
import '../../services/bank_service.dart';
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
  bool _isAccountNumVisible = true;

  static const Color textDark = Color(0xFF111827);
  static const Color textGray = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFE5E7EB);
  static const Color greenCredit = Color(0xFF059669);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top User Profile Header
              _buildProfileHeader(),

              const SizedBox(height: 16),

              // 2. Available Balance Hero Card (exact 205px height matching CardsScreen)
              _buildBalanceCard(),

              const SizedBox(height: 20),

              // 3. Quick Action Cards (Transfer, Scan, Cards, Analytics)
              _buildQuickActions(),

              const SizedBox(height: 22),

              // 4. Recent Transactions (exact sizing from CardsScreen)
              _buildRecentTransactions(),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // --- 1. PROFILE HEADER ---
  Widget _buildProfileHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFF380084),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_outline_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _bankService.user.name.isNotEmpty ? _bankService.user.name : 'Elijah Montefalco',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: textDark,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      _isAccountNumVisible
                          ? 'Acc. No: ${_bankService.savingsAccountNumber}'
                          : 'Acc. No: ••••••••••••',
                      style: const TextStyle(fontSize: 11, color: textGray, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => setState(() => _isAccountNumVisible = !_isAccountNumVisible),
                      child: Icon(
                        _isAccountNumVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        size: 13,
                        color: textGray,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        // Clean Circular Bell Notification Button
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.notifications_none_rounded, size: 20, color: textDark),
        ),
      ],
    );
  }

  // --- 2. HERO BALANCE CARD (EXACT 205px HEIGHT MATCHING CARDSSCREEN, NO MASTERCARD LOGO) ---
  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity,
      height: 205,
      padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 20.0), // Exact same padding
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24), // Exact same border radius
        gradient: const LinearGradient(
          colors: [
            Color(0xFF430897),
            Color(0xFF7A45C6),
            Color(0xFFB183F4),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF430897).withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top: Available Balance + Eye Icon
          Row(
            children: [
              const Text(
                'Available Balance',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => _isBalanceVisible = !_isBalanceVisible),
                child: Icon(
                  _isBalanceVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),

          // Middle: Balance Amount
          Text(
            _isBalanceVisible
                ? (_bankService.availableBalance > 0
                ? _formatBalance(_bankService.availableBalance)
                : '₱ 50,000,000')
                : '₱ ••••••••',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),

          // Bottom: Clean Savings Account Label (No Mastercard logo)
          Text(
            'Savings Account',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  // --- 3. QUICK ACTIONS ---
  Widget _buildQuickActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildActionCard(
          iconWidget: const Icon(Icons.swap_horiz_rounded, color: textDark, size: 24),
          label: 'Transfer',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const SendMoneyScreen()),
            );
          },
        ),
        _buildActionCard(
          iconWidget: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(Icons.qr_code_2_rounded, color: textDark, size: 24),
              Container(
                width: 20,
                height: 3,
                decoration: BoxDecoration(
                  color: const Color(0xFFA855F7),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
          label: 'Scan',
          onTap: () {
            if (widget.onNavigateTab != null) {
              widget.onNavigateTab!(2);
            }
          },
        ),
        _buildActionCard(
          iconWidget: const Icon(Icons.credit_card_rounded, color: textDark, size: 24),
          label: 'Cards',
          onTap: () {
            if (widget.onNavigateTab != null) {
              widget.onNavigateTab!(1);
            }
          },
        ),
        _buildActionCard(
          iconWidget: const Icon(Icons.show_chart_rounded, color: textDark, size: 24),
          label: 'Analytics',
          onTap: () {
            if (widget.onNavigateTab != null) {
              widget.onNavigateTab!(3);
            }
          },
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required Widget iconWidget,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 66,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            iconWidget,
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 4. RECENT TRANSACTIONS (EXACT CARDSSCREEN SIZING) ---
  Widget _buildRecentTransactions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Transactions',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: textDark,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 12),

        // Transaction 1: Angel Lou F. Yabut
        _buildTransactionCard(
          initial: 'A',
          avatarBgColor: const Color(0xFF380084),
          name: 'Angel Lou F. Yabut',
          subtitle: 'Settled',
          amount: '- 150,000',
          amountColor: textDark,
        ),

        const SizedBox(height: 8),

        // Transaction 2: Mae G. Mercado
        _buildTransactionCard(
          initial: 'M',
          avatarBgColor: const Color(0xFF8B5CF6),
          name: 'Mae G. Mercado',
          subtitle: 'Interbank Inward',
          amount: '+ 25,000',
          amountColor: greenCredit,
        ),

        const SizedBox(height: 8),

        // Transaction 3: Jessie Mae Dela Paz
        _buildTransactionCard(
          initial: 'J',
          avatarBgColor: const Color(0xFF6366F1),
          name: 'Jessie Mae Dela Paz',
          subtitle: 'Failed',
          amount: '+ 25,000',
          amountColor: greenCredit,
        ),
      ],
    );
  }

  Widget _buildTransactionCard({
    required String initial,
    required Color avatarBgColor,
    required String name,
    required String subtitle,
    required String amount,
    required Color amountColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: avatarBgColor,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: textGray,
                  ),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: amountColor,
            ),
          ),
        ],
      ),
    );
  }

  String _formatBalance(double amount) {
    final parts = amount.toStringAsFixed(0);
    final formatted = parts.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
    );
    return '₱ $formatted';
  }
}