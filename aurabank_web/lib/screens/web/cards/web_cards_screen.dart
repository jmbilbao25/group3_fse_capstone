import 'package:flutter/material.dart';

import 'package:aurabank_core/theme/aura_theme.dart';
import 'package:aurabank_core/widgets/aura_card.dart';
import 'package:aurabank_core/widgets/card_actions.dart';
import 'package:aurabank_core/widgets/transaction_tile.dart';

class WebCardsScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const WebCardsScreen({super.key, this.onBack});

  @override
  State<WebCardsScreen> createState() => _WebCardsScreenState();
}

class _WebCardsScreenState extends State<WebCardsScreen> with CardDeckState<WebCardsScreen> {
  @override
  Widget build(BuildContext context) {
    final card = activeCard;
    final revealed = revealedId == card.id;

    return Container(
      color: AuraColors.canvas,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(32, 8, 32, 32),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Cards', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, letterSpacing: -0.6)),
              ),
              FilledButton.icon(
                onPressed: issueCard,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('New card'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
                  child: Column(
                    children: [
                      AuraCardCarousel(
                        cards: bank.cards,
                        initialIndex: activeIndex,
                        revealedCardId: revealedId,
                        viewportFraction: 0.62,
                        maxCardWidth: 380,
                        onPageChanged: selectCard,
                        onCardTap: (_) => toggleReveal(),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        revealed ? 'Details turn back after 20 seconds.' : 'Click the card in front to show its details.',
                        style: const TextStyle(fontSize: 13, color: AuraColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Panel(
                      title: '${card.title} ending ${card.last4}',
                      child: Column(
                        children: [
                          _Fact('Network', card.network.label),
                          _Fact('Type', card.kindLabel),
                          _Fact('Spends from', 'Savings account'),
                          _Fact('Status', card.isLocked ? 'Frozen' : 'Active'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _Panel(
                      title: 'Controls',
                      child: Column(
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: card.isLocked,
                            onChanged: (_) => toggleFreeze(),
                            title: const Text('Freeze card', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                            subtitle: const Text('Declines new payments until you unfreeze.', style: TextStyle(fontSize: 13)),
                          ),
                          const Divider(),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            onTap: toggleReveal,
                            leading: Icon(revealed ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AuraColors.ink),
                            title: Text(revealed ? 'Hide details' : 'Show number and CVV',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                            trailing: const Icon(Icons.chevron_right_rounded),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const Text('Recent card activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.3)),
          const SizedBox(height: 12),
          for (final txn in bank.recentTransactions)
            Padding(padding: const EdgeInsets.only(bottom: 8), child: TransactionTile(txn: txn)),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      );
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 14, color: AuraColors.textMuted)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(value, textAlign: TextAlign.end, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
}
