import 'package:flutter/material.dart';
import 'package:aurabank_core/models/bank_models.dart';
import 'package:aurabank_core/services/bank_service.dart';
import 'package:aurabank_core/theme/aura_theme.dart';

class WebCardsScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const WebCardsScreen({super.key, this.onBack});

  @override
  State<WebCardsScreen> createState() => _WebCardsScreenState();
}

class _WebCardsScreenState extends State<WebCardsScreen> {
  final BankService _bankService = BankService();
  int _activeCardIndex = 0;
  bool _revealCardDetails = false;

  static const Color brandViolet = AuraColors.primary;
  static const Color textDark = AuraColors.textPrimary;
  static const Color textGray = AuraColors.textMuted;
  static const Color cardBorder = Color(0xFFE5E7EB);

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

  List<BankCard> get _savingsCards => _bankService.cards
      .where((card) => card.title.toLowerCase() == 'savings')
      .toList();

  void _toggleLock() {
    final cards = _savingsCards;
    if (cards.isEmpty) return;
    final card = cards[_activeCardIndex.clamp(0, cards.length - 1)];
    final realIndex = _bankService.cards.indexWhere((item) => item.id == card.id);
    if (realIndex < 0) return;
    _bankService.toggleCardLock(realIndex);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          card.isLocked
              ? '${card.title} card is now locked for security.'
              : '${card.title} card is now unlocked and active.',
        ),
        backgroundColor: card.isLocked ? const Color(0xFF380084) : AuraColors.creditGreen,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _addNewCard() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Issue New Aura Corporate Card', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select the card type to instantly provision under your primary corporate vault.',
              style: TextStyle(fontSize: 13, color: textGray),
            ),
            const SizedBox(height: 18),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: cardBorder)),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AuraColors.tintPurple, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.credit_card_rounded, color: brandViolet),
              ),
              title: const Text('Instant Virtual Card', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              subtitle: const Text('Provisioned with dynamic tokenization & single-use CVV', style: TextStyle(fontSize: 11)),
              onTap: () {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Virtual Card provisioned successfully.')),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: textGray, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cards = _savingsCards;
    final activeCard = cards.isNotEmpty ? cards[_activeCardIndex.clamp(0, cards.length - 1)] : null;

    return Container(
      color: const Color(0xFFF9FAFB),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Executive Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Cards & Programmable Controls',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: textDark,
                        letterSpacing: -0.4,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Manage corporate physical & virtual cards, spending boundaries, and instant freeze gates',
                      style: TextStyle(fontSize: 13, color: textGray),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _addNewCard,
                  icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                  label: const Text('Issue New Card', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandViolet,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 2. Desktop Master-Detail Layout (40% Deck Selector / 60% Active Terminal & Ledger)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // LEFT COLUMN: Card Deck Selector (Interactive Cards List)
                Expanded(
                  flex: 42,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ACTIVE CARD PORTFOLIO',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 12),
                      ...cards.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final card = entry.value;
                        final isSelected = _activeCardIndex == idx;
                        return _buildDesktopCardPreview(card, idx, isSelected);
                      }),
                    ],
                  ),
                ),

                const SizedBox(width: 24),

                // RIGHT COLUMN: Detailed Card Terminal, Security Controls, and Card Ledger
                Expanded(
                  flex: 58,
                  child: activeCard != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildCardTerminalPanel(activeCard),
                            const SizedBox(height: 20),
                            _buildCardSecurityControlsPanel(activeCard),
                            const SizedBox(height: 20),
                            _buildCardRecentTransactionsPanel(activeCard),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopCardPreview(BankCard card, int index, bool isSelected) {
    final last4 = card.cardNumber.replaceAll(' ', '');
    final ending = last4.length >= 4 ? last4.substring(last4.length - 4) : card.cardNumber;
    return GestureDetector(
      onTap: () => setState(() => _activeCardIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2E1065), Color(0xFF5B21B6), Color(0xFF7C3AED)],
            stops: [0.0, 0.52, 1.0],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: isSelected ? 0.55 : 0.18)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6D28D9).withValues(alpha: 0.28),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('A', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Aura Bank',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.white70,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: card.isLocked ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        card.isLocked ? 'Locked' : card.title,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                const Text(
                  'Card Number',
                  style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () => setState(() => _revealCardDetails = !_revealCardDetails),
                  borderRadius: BorderRadius.circular(12),
                  child: Icon(
                    _revealCardDetails ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_revealCardDetails)
              Text(
                card.cardNumber,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 1.4),
              )
            else
              Row(
                children: [
                  _buildDotGroup(),
                  const SizedBox(width: 14),
                  _buildDotGroup(),
                  const SizedBox(width: 14),
                  _buildDotGroup(),
                  const SizedBox(width: 14),
                  Text(ending, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                ],
              ),
            const SizedBox(height: 18),
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Expires', style: TextStyle(color: Colors.white70, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(card.expiry, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(width: 36),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('CVV', style: TextStyle(color: Colors.white70, fontSize: 11)),
                    const SizedBox(height: 4),
                    _revealCardDetails
                        ? Text(card.cvv, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1))
                        : _buildDotGroup(count: 3, size: 6),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Cardholder', style: TextStyle(color: Colors.white70, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(card.holderName, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                  ],
                ),
                const Spacer(),
                SizedBox(
                  width: 42,
                  height: 26,
                  child: Stack(
                    children: [
                      Positioned(
                        left: 0,
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: const BoxDecoration(color: Color(0xFFEB001B), shape: BoxShape.circle),
                        ),
                      ),
                      Positioned(
                        left: 14,
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(color: const Color(0xFFF79E1B).withValues(alpha: 0.92), shape: BoxShape.circle),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDotGroup({int count = 4, double size = 7}) {
    return Row(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          ),
        ],
      ],
    );
  }

  Widget _buildCardTerminalPanel(BankCard card) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${card.title} Terminal Details',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textDark),
                  ),
                  const SizedBox(height: 2),
                  const Text('Direct settlement vault integration', style: TextStyle(fontSize: 11.5, color: textGray)),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () => setState(() => _revealCardDetails = !_revealCardDetails),
                icon: Icon(_revealCardDetails ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 14),
                label: Text(_revealCardDetails ? 'Hide Credentials' : 'Show CVV & PAN', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: cardBorder),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFF3F4F6))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCredentialColumn('CARD NUMBER', _revealCardDetails ? card.cardNumber : card.maskedCardNumber),
                _buildCredentialColumn('EXPIRATION', card.expiry),
                _buildCredentialColumn('SECURITY CVV', _revealCardDetails ? card.cvv : '•••'),
                _buildCredentialColumn('CARD TYPE', 'Savings'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: textGray, letterSpacing: 0.3)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textDark)),
      ],
    );
  }

  Widget _buildCardSecurityControlsPanel(BankCard card) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Security & Boundary Gates', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textDark)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildActionToggleTile(
                  icon: card.isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                  iconColor: card.isLocked ? const Color(0xFFDC2626) : const Color(0xFF059669),
                  title: card.isLocked ? 'Card is Frozen' : 'Instant Freeze',
                  subtitle: card.isLocked ? 'Tap to re-activate transactions' : 'Block all in-store & online debits',
                  buttonLabel: card.isLocked ? 'Unlock Card' : 'Freeze Card',
                  buttonColor: card.isLocked ? const Color(0xFF059669) : const Color(0xFFDC2626),
                  onTap: _toggleLock,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildActionToggleTile(
                  icon: Icons.speed_rounded,
                  iconColor: const Color(0xFF380084),
                  title: 'Daily Spend Limit',
                  subtitle: '₱150,000.00 / ₱250,000 max',
                  buttonLabel: 'Adjust Limits',
                  buttonColor: const Color(0xFF380084),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Spending limit modal opened.')));
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionToggleTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String buttonLabel,
    required Color buttonColor,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: textDark)),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: textGray)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: Text(buttonLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardRecentTransactionsPanel(BankCard card) {
    final transactions = _bankService.recentTransactions.take(4).toList();

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('Card Clearance Ledger', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textDark)),
              Text('Real-time POS settlement', style: TextStyle(fontSize: 11.5, color: textGray)),
            ],
          ),
          const SizedBox(height: 14),
          ...transactions.map((txn) {
            final isCredit = txn.isIncoming;
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isCredit ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isCredit ? Icons.arrow_downward_rounded : Icons.shopping_bag_outlined,
                          size: 16,
                          color: isCredit ? const Color(0xFF059669) : const Color(0xFFDC2626),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(txn.counterparty, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textDark)),
                          Text(txn.displayTime, style: const TextStyle(fontSize: 11, color: textGray)),
                        ],
                      ),
                    ],
                  ),
                  Text(
                    '${isCredit ? "+ " : "- "}₱${txn.formattedIntegerAmount}',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: isCredit ? const Color(0xFF059669) : textDark,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
