import 'package:flutter/material.dart';

import '../../models/bank_models.dart';
import '../../theme/aura_theme.dart';
import '../../widgets/aura_card.dart';
import '../../widgets/card_actions.dart';
import '../../widgets/motion.dart';
import '../../widgets/transaction_tile.dart';

class CardsScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const CardsScreen({super.key, this.onBack});

  @override
  State<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends State<CardsScreen>
    with CardDeckState<CardsScreen> {
  @override
  Widget build(BuildContext context) {
    final card = activeCard;
    final revealed = revealedId == card.id;
    final canPop = widget.onBack != null || Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: AuraColors.canvas,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 32),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  if (canPop) ...[
                    _CircleButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Back',
                      onTap: widget.onBack ??
                          () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 12),
                  ],
                  const Expanded(
                    child: Text('Cards',
                        style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.6)),
                  ),
                  _CircleButton(
                      icon: Icons.add_rounded,
                      tooltip: 'New card',
                      onTap: issueCard),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Reveal(
              offset: 28,
              duration: const Duration(milliseconds: 680),
              child: AuraCardCarousel(
                cards: bank.cards,
                initialIndex: activeIndex,
                revealedCardId: revealedId,
                onPageChanged: selectCard,
                onCardTap: (_) => toggleReveal(),
              ),
            ),
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  CardActionButton(
                    icon: card.isLocked
                        ? Icons.lock_open_rounded
                        : Icons.ac_unit_rounded,
                    label: card.isLocked ? 'Unfreeze' : 'Freeze',
                    highlighted: card.isLocked,
                    onTap: toggleFreeze,
                  ),
                  CardActionButton(
                    icon: revealed
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    label: revealed ? 'Hide' : 'Details',
                    highlighted: revealed,
                    onTap: toggleReveal,
                  ),
                  CardActionButton(
                      icon: Icons.add_card_rounded,
                      label: 'New card',
                      onTap: issueCard),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _CardFacts(card: card),
            ),
            const SizedBox(height: 28),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('Recent card activity',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3)),
            ),
            const SizedBox(height: 12),
            for (final (i, txn) in bank.recentTransactions.indexed)
              Reveal(
                delay: Reveal.stagger(i, base: 260),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: TransactionTile(txn: txn),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CardFacts extends StatelessWidget {
  const _CardFacts({required this.card});
  final BankCard card;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('Spends from', 'Savings account'),
      ('Type', '${card.network.label} ${card.kindLabel.toLowerCase()}'),
      ('Status', card.isLocked ? 'Frozen' : 'Active'),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Row(
                children: [
                  Text(rows[i].$1,
                      style: const TextStyle(
                          fontSize: 14, color: AuraColors.textMuted)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      rows[i].$2,
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Round action with a label underneath, as on the wallet.
class CardActionButton extends StatelessWidget {
  const CardActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Pressable(
        onTap: onTap,
        scale: 0.92,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: AuraMotion.resolve(context, AuraMotion.fast),
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: highlighted ? AuraColors.mint : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                    color:
                        highlighted ? AuraColors.mint : AuraColors.cardBorder),
              ),
              child: Icon(icon, size: 22, color: AuraColors.ink),
            ),
            const SizedBox(height: 8),
            ExcludeSemantics(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: AuraColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton(
      {required this.icon, required this.onTap, required this.tooltip});
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(icon, size: 22, color: AuraColors.ink),
        style: IconButton.styleFrom(
          backgroundColor: Colors.white,
          fixedSize: const Size(44, 44),
          side: const BorderSide(color: AuraColors.cardBorder),
        ),
      );
}
