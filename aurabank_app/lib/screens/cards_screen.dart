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
  int _revealedCard = -1;
  late final PageController _pageController;

  static const Color brandViolet = AuraColors.primary;
  static const Color textDark = AuraColors.textPrimary;
  static const Color textGray = AuraColors.textMuted;
  static const Color cardBorder = Color(0xFFE5E7EB);

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      viewportFraction: 0.96,
      initialPage: _activeCardIndex,
    );
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
    final cardColor = _getCardGradient(card, _activeCardIndex).first;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          card.isLocked
              ? '${card.title} card is now locked for security.'
              : '${card.title} card is now unlocked and active.',
        ),
        backgroundColor: card.isLocked ? cardColor : AuraColors.creditGreen,
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

  List<Color> _getCardGradient(BankCard card, int index) {
    final title = card.title.toLowerCase();
    if (title.contains('saving') || index % 3 == 0) {
      return const [
        Color(0xFF430897),
        Color(0xFF7A45C6),
        Color(0xFFB183F4),
      ];
    } else if (title.contains('current') || index % 3 == 1) {
      return const [
        Color(0xFF3E104B),
        Color(0xFF87608E),
        Color(0xFFD1B1D3),
      ];
    } else {
      return const [
        Color(0xFF8C0C83),
        Color(0xFFA965A5),
        Color(0xFFC7C0C6),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCard = _bankService.cards[_activeCardIndex];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Back, Card Control, + (with 18 horizontal padding)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18.0),
                child: Row(
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
              ),

              const SizedBox(height: 22),

              // Full-Width Carousel: Natural edge-to-edge
              SizedBox(
                height: 205,
                child: PageView.builder(
                  controller: _pageController,
                  clipBehavior: Clip.none,
                  itemCount: _bankService.cards.length,
                  onPageChanged: (i) => setState(() => _activeCardIndex = i),
                  itemBuilder: (context, index) {
                    final card = _bankService.cards[index];
                    final isActive = _activeCardIndex == index;

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        scale: isActive ? 1.0 : 0.93,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 280),
                          opacity: isActive ? 1.0 : 0.72,
                          child: _buildBankCard(card, index),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 14),

              // Lower Content Section (18.0 horizontal padding)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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

                    // Lock / Unlock Card Action Button
                    Container(
                      width: double.infinity,
                      height: 48,
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

                    // Section: Transaction History
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
                      subtitle: 'Same Bank Transfer • Settled',
                      amount: '- 150,000',
                      amountColor: textDark,
                    ),
                    const SizedBox(height: 8),
                    _buildTransactionCard(
                      initial: 'M',
                      avatarBgColor: const Color(0xFF8B5CF6),
                      name: 'Mae G. Mercado',
                      subtitle: 'Other Bank Transfer • Settled',
                      amount: '+ 25,000',
                      amountColor: const Color(0xFF059669),
                    ),
                    const SizedBox(height: 12),
                    _buildTransactionCard(
                      initial: 'J',
                      avatarBgColor: const Color(0xFF6366F1),
                      name: 'Jessie Mae Dela Paz',
                      subtitle: 'Same Bank Transfer • Failed',
                      amount: '+ 25,000',
                      amountColor: const Color(0xFF059669),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Card Builder
  Widget _buildBankCard(BankCard card, int index) {
    final cleanNum = card.cardNumber.replaceAll(' ', '');
    final last4 = cleanNum.length >= 4 ? cleanNum.substring(cleanNum.length - 4) : '0809';
    final isRevealed = _revealedCard == index;
    final gradientColors = _getCardGradient(card, index);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // --- TOP ROW: Aura Bank badge & Account type pill ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Aura Bank Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: const Color(0xFF3C0092),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                'A',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Aura Bank',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                                decoration: TextDecoration.underline,
                                decorationColor: Colors.white,
                                decorationThickness: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Pill: ● Savings / ● Current / ● Credit
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4.5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF4ADE80),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              card.title,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // --- MIDDLE ROW: Card Number & Eye Icon ---
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Card Number',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.72),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _revealedCard = isRevealed ? -1 : index;
                              });
                            },
                            child: Icon(
                              isRevealed ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: Colors.white.withValues(alpha: 0.85),
                              size: 15,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isRevealed ? card.cardNumber : '●●●●  ●●●●  ●●●●  $last4',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          letterSpacing: 2.0,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),

                  // --- BOTTOM SECTION: Expires, CVV, Cardholder, and Mastercard ---
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sub-row 1: Expires & CVV
                      Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Expires',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                card.expiry,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 42),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CVV',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isRevealed ? card.cvv : '●●●',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  letterSpacing: 1.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      // Sub-row 2: Cardholder name & Mastercard emblem
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cardholder',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.65),
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                card.holderName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          _buildMastercardLogo(),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Blurred overlay matching the specific card's own gradient colors
            if (card.isLocked)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            // Darkened tint derived from card's own gradient
                            Color.lerp(gradientColors.first, Colors.black, 0.40)!.withValues(alpha: 0.75),
                            Color.lerp(gradientColors.last, Colors.black, 0.35)!.withValues(alpha: 0.65),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.lock_rounded, color: Colors.white, size: 30),
                            SizedBox(height: 6),
                            Text(
                              'Card Locked',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
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

  // Overlapping Circles Mastercard Logo
  Widget _buildMastercardLogo() {
    return SizedBox(
      width: 36,
      height: 22,
      child: Stack(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: Color(0xFFEB001B),
              shape: BoxShape.circle,
            ),
          ),
          Positioned(
            left: 14,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: const Color(0xFFF79E1B).withValues(alpha: 0.95),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Transaction item card
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
}