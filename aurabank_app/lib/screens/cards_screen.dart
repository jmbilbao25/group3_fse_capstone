import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/bank_models.dart';
import '../services/bank_service.dart';
import '../theme/aura_theme.dart';

class CardsScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const CardsScreen({super.key, this.onBack});

  @override
  State<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends State<CardsScreen> {
  final BankService _bankService = BankService();
  int _activeCardIndex = 0;
  bool _showNumbers = false;
  late final PageController _pageController;

  static const Color brandViolet = AuraColors.primary;
  static const Color textDark = AuraColors.textPrimary;
  static const Color textGray = AuraColors.textMuted;
  static const Color cardBorder = Color(0xFFE5E7EB);

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.92);
    _bankService.addListener(_onServiceUpdate);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _bankService.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  void _toggleLock() {
    _bankService.toggleCardLock(_activeCardIndex);
    final card = _bankService.cards[_activeCardIndex];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          card.isLocked
              ? '${card.title} card is now locked for security.'
              : '${card.title} card is now unlocked and active.',
        ),
        backgroundColor: card.isLocked ? AuraColors.primary : AuraColors.creditGreen,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _addNewCard() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add New Aura Card',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textDark),
            ),
            const SizedBox(height: 8),
            const Text(
              'Issue an instant virtual debit card or link your physical Mastercard card.',
              style: TextStyle(fontSize: 13, color: textGray, height: 1.4),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AuraColors.tintPurple, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.credit_card_rounded, color: AuraColors.primary),
              ),
              title: const Text('Instant Virtual Card', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Ready for online payments with dynamic CVV', style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Virtual Card created and linked to Primary Vault.')),
                );
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.add_card_rounded, color: textDark),
              ),
              title: const Text('Link Physical Card', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Enter 16-digit card number and PIN to activate', style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Physical card activation flow initiated.')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeCard = _bankService.cards[_activeCardIndex];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Back, Card Control, +
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: cardBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: textDark),
                      onPressed: () {
                        if (widget.onBack != null) {
                          widget.onBack!();
                        } else {
                          Navigator.of(context).maybePop();
                        }
                      },
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  const Text(
                    'Card Control',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: textDark,
                    ),
                  ),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: cardBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.add, size: 22, color: textDark),
                      onPressed: _addNewCard,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              // Card Carousel (Horizontal Aspect Ratio matching page_8.png)
              SizedBox(
                height: 228,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _bankService.cards.length,
                  onPageChanged: (i) => setState(() => _activeCardIndex = i),
                  itemBuilder: (context, index) {
                    final card = _bankService.cards[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: _buildBankCard(card),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              // Page Indicators
              if (_bankService.cards.length > 1)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_bankService.cards.length, (i) {
                    final isSelected = i == _activeCardIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: isSelected ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isSelected ? brandViolet : const Color(0xFFD1D5DB),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),

              const SizedBox(height: 20),

              // Lock / Unlock Card Action Button (matching page_8.png & page_23.png)
              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cardBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: InkWell(
                  onTap: _toggleLock,
                  borderRadius: BorderRadius.circular(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        activeCard.isLocked ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                        color: brandViolet,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        activeCard.isLocked ? 'Unlock Card' : 'Lock Card',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: brandViolet,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 26),

              // Section: Transaction History (matching page_8.png)
              const Text(
                'Transaction History',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: textDark,
                  letterSpacing: -0.2,
                ),
              ),

              const SizedBox(height: 14),

              // Transaction List Items
              _buildTransactionCard(
                initial: 'A',
                avatarBgColor: const Color(0xFF380084),
                name: 'Angel Lou F. Yabut',
                subtitle: 'Settled',
                amount: '- 150,000',
                amountColor: textDark,
              ),
              const SizedBox(height: 12),
              _buildTransactionCard(
                initial: 'M',
                avatarBgColor: const Color(0xFF8B5CF6),
                name: 'Mae G. Mercado',
                subtitle: 'Intrabank Inward',
                amount: '+ 25,000',
                amountColor: const Color(0xFF059669),
              ),
              const SizedBox(height: 12),
              _buildTransactionCard(
                initial: 'J',
                avatarBgColor: const Color(0xFF6366F1),
                name: 'Jessie Mae Dela Paz',
                subtitle: 'Failed',
                amount: '+ 25,000',
                amountColor: const Color(0xFF059669),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // Horizontal Card Builder matching page_8.png and page_16.png
  Widget _buildBankCard(BankCard card) {
    final cleanNum = card.cardNumber.replaceAll(' ', '');
    final last4 = cleanNum.length >= 4 ? cleanNum.substring(cleanNum.length - 4) : '0809';

    return Container(
      width: double.infinity,
      height: 224,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(card.gradientStart),
            const Color(0xFF380084),
            Color(card.gradientEnd),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(card.gradientStart).withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // Card Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top Row: Aura Bank badge & Savings pill
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                'A',
                                style: TextStyle(
                                  color: AuraColors.primary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Aura Bank',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.circle, color: Color(0xFF4ADE80), size: 7),
                            const SizedBox(width: 5),
                            Text(
                              card.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Middle Row: Card Number & Eye Icon
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Card Number',
                            style: TextStyle(
                              color: Color(0xFFE9D5FF),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => setState(() => _showNumbers = !_showNumbers),
                            child: Icon(
                              _showNumbers ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _showNumbers
                            ? card.cardNumber
                            : '••••  ••••  ••••  $last4',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),

                  // Bottom Row: Expiry, CVV, Cardholder, and Mastercard Emblem
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Expires',
                            style: TextStyle(
                              color: Color(0xFFE9D5FF),
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            card.expiry,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Cardholder',
                            style: TextStyle(
                              color: Color(0xFFE9D5FF),
                              fontSize: 8.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            card.holderName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CVV',
                            style: TextStyle(
                              color: Color(0xFFE9D5FF),
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _showNumbers ? card.cvv : '•••',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),

                      // Mastercard / Card Network Logo
                      _buildMastercardLogo(),
                    ],
                  ),
                ],
              ),
            ),

            // Blurred overlay when Card is Locked (matching page_23.png)
            if (card.isLocked)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                    child: Container(
                      color: const Color(0xFF2A085C).withValues(alpha: 0.55),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.lock_rounded, color: Colors.white, size: 32),
                            SizedBox(height: 6),
                            Text(
                              'Card Locked',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Overlapping Circles Mastercard Logo matching page_8.png
  Widget _buildMastercardLogo() {
    return SizedBox(
      width: 44,
      height: 28,
      child: Stack(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: const BoxDecoration(
              color: Color(0xFFEB001B),
              shape: BoxShape.circle,
            ),
          ),
          Positioned(
            left: 16,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: const Color(0xFFF79E1B).withValues(alpha: 0.92),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Transaction item card matching page_8.png
  Widget _buildTransactionCard({
    required String initial,
    required Color avatarBgColor,
    required String name,
    required String subtitle,
    required String amount,
    required Color amountColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            width: 42,
            height: 42,
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
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
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
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: amountColor,
            ),
          ),
        ],
      ),
    );
  }
}
