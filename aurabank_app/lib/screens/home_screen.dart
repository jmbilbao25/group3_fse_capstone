import 'package:flutter/material.dart';
import '../models/bank_models.dart';
import '../services/bank_service.dart';
import '../theme/aura_theme.dart';
import 'send_money_screen.dart';

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

  static const Color brandViolet = AuraColors.primary;
  static const Color textDark = AuraColors.textPrimary;
  static const Color textGray = AuraColors.textMuted;
  static const Color cardBorder = AuraColors.cardBorder;
  static const Color greenCredit = AuraColors.creditGreen;

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

              const SizedBox(height: 18),

              // 2. Available Balance Hero Card
              _buildBalanceCard(),

              const SizedBox(height: 22),

              // 3. Quick Actions Grid
              _buildQuickActions(),

              const SizedBox(height: 24),

              // 4. Recent Transactions
              _buildRecentTransactions(),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

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
                color: AuraColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _bankService.user.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      _isAccountNumVisible
                          ? 'Account Number: ${_bankService.savingsAccountNumber}'
                          : 'Account Number: •••• •••• •••• 1327',
                      style: const TextStyle(fontSize: 11, color: textGray),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => setState(() => _isAccountNumVisible = !_isAccountNumVisible),
                      child: Icon(
                        _isAccountNumVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        size: 14,
                        color: textGray,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        Stack(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: cardBorder),
              ),
              child: const Icon(Icons.notifications_none_rounded, size: 20, color: textDark),
            ),
            Positioned(
              top: 7,
              right: 7,
              child: Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: Color(0xFFE11D48),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: AuraColors.balanceHeroGradient,
        boxShadow: [
          BoxShadow(
            color: AuraColors.primary.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'SAVINGS • PRIMARY',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: Color(0xFFD8B4FE),
                ),
              ),
              Text(
                'AURA',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'Available Balance',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFE9D5FF),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => _isBalanceVisible = !_isBalanceVisible),
                child: Icon(
                  _isBalanceVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  size: 16,
                  color: const Color(0xFFE9D5FF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _isBalanceVisible ? _formatBalance(_bankService.availableBalance) : '₱ ••••••••',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'AUR  ••••  8842',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                  color: Color(0xFFD8B4FE),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: const Text(
                  'Savings Account',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildActionItem(
              icon: Icons.swap_horiz_rounded,
              label: 'Transfer',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const SendMoneyScreen()),
                );
              },
            ),
            _buildActionItem(
              icon: Icons.qr_code_scanner_rounded,
              label: 'Scan',
              onTap: () => widget.onNavigateTab?.call(2),
            ),
            _buildActionItem(
              icon: Icons.credit_card_rounded,
              label: 'Cards',
              onTap: () => widget.onNavigateTab?.call(1),
            ),
            _buildActionItem(
              icon: Icons.show_chart_rounded,
              label: 'Analytics',
              onTap: () => widget.onNavigateTab?.call(3),
            ),
            _buildActionItem(
              icon: Icons.more_horiz_rounded,
              label: 'More',
              onTap: _showMoreServicesSheet,
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Hardware Trust Pill Banner (Figma image_51_0.png)
        InkWell(
          onTap: () {
            Navigator.of(context).pushNamed('/devices');
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: const [
                Icon(Icons.circle, color: Color(0xFF10B981), size: 7),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'iPhone 15 Pro • Primary Trusted Hardware',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AuraColors.textPrimary,
                    ),
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AuraColors.textMuted),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showMoreServicesSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Aura Bank Hub',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AuraColors.textPrimary),
            ),
            const SizedBox(height: 14),
            ListTile(
              leading: const Icon(Icons.mark_email_read_outlined, color: AuraColors.primary),
              title: const Text('Email OTP Verification', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              subtitle: const Text('Figma 001 verification screen flow', style: TextStyle(fontSize: 11)),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 13),
              onTap: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pushNamed('/otp');
              },
            ),
            ListTile(
              leading: const Icon(Icons.shield_outlined, color: AuraColors.primary),
              title: const Text('Security Gates & Threat Detection', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              subtitle: const Text('Gate 0 Scan, Screen Share & Fraud block', style: TextStyle(fontSize: 11)),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 13),
              onTap: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pushNamed('/security_gate');
              },
            ),
            ListTile(
              leading: const Icon(Icons.devices_rounded, color: AuraColors.primary),
              title: const Text('Trusted Devices & Active Sessions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              subtitle: const Text('Figma 012 hardware telemetry management', style: TextStyle(fontSize: 11)),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 13),
              onTap: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pushNamed('/devices');
              },
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined, color: AuraColors.primary),
              title: const Text('Statement of Account', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              subtitle: const Text('Monthly e-statements with digital certificate', style: TextStyle(fontSize: 11)),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 13),
              onTap: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pushNamed('/statement');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AuraColors.bgLavender,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AuraColors.borderLavender),
              boxShadow: [
                BoxShadow(
                  color: AuraColors.primary.withValues(alpha: 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: brandViolet, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Transactions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: textDark,
          ),
        ),
        const SizedBox(height: 12),
        ..._bankService.recentTransactions.map((t) {
          final isDebit = t.type == TransactionType.outgoing;
          final Color badgeColor = t.status == TransactionStatus.failed
              ? const Color(0xFFDC2626)
              : (isDebit ? textDark : greenCredit);

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Color(t.avatarColorValue),
                  child: Text(
                    t.initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.counterparty,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        t.status == TransactionStatus.settled ? 'Settled' : t.statusDisplay,
                        style: TextStyle(
                          fontSize: 11,
                          color: t.status == TransactionStatus.failed ? const Color(0xFFDC2626) : textGray,
                          fontWeight: t.status == TransactionStatus.failed ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${isDebit ? '- ' : '+ '}${_formatAmountPlain(t.amount)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: badgeColor,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
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

  String _formatAmountPlain(double amount) {
    final parts = amount.toStringAsFixed(0);
    final formatted = parts.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return formatted;
  }
}
