import 'package:flutter/material.dart';
import '../models/bank_models.dart';

class CardDetailsScreen extends StatelessWidget {
  final BankCard card;

  const CardDetailsScreen({
    super.key,
    required this.card,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(card.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Text(
              card.holderName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            Text(
              "Card Number: ${card.cardNumber}",
            ),

            const SizedBox(height: 10),

            Text(
              "Expiry: ${card.expiry}",
            ),

            const SizedBox(height: 10),

            Text(
              "CVV: ${card.cvv}",
            ),

          ],
        ),
      ),
    );
  }
}