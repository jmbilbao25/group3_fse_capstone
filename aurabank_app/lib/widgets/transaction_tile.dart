import 'package:flutter/material.dart';

import '../models/bank_models.dart';
import '../theme/aura_theme.dart';
import 'motion.dart';

/// One ledger row: counterparty, channel and status, signed amount.
class TransactionTile extends StatelessWidget {
  const TransactionTile({super.key, required this.txn, this.onTap});

  final BankTransaction txn;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final failed = txn.status == TransactionStatus.failed;
    final amountColor = failed
        ? AuraColors.textMuted
        : txn.isIncoming
            ? AuraColors.creditGreen
            : AuraColors.ink;

    return Pressable(
      onTap: onTap,
      scale: 0.98,
      haptic: false,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color:
                        txn.isIncoming ? AuraColors.tintPurple : AuraColors.ink,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    txn.initial,
                    style: TextStyle(
                      color: txn.isIncoming ? AuraColors.accent : Colors.white,
                      fontWeight: FontWeight.w600,
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
                        txn.counterparty,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: AuraColors.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        failed ? 'Failed' : txn.channelName,
                        style: TextStyle(
                            fontSize: 12.5,
                            color: failed
                                ? AuraColors.debitRed
                                : AuraColors.textMuted),
                      ),
                    ],
                  ),
                ),
                Text(
                  txn.formattedAmount,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: amountColor,
                    decoration: failed ? TextDecoration.lineThrough : null,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
