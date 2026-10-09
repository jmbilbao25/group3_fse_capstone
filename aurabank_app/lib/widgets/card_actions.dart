import 'package:flutter/material.dart';

import '../models/bank_models.dart';
import '../services/bank_service.dart';
import '../services/biometric_service.dart';
import '../theme/aura_theme.dart';
import 'aura_card.dart';

/// Asks the device to confirm the holder before card details are shown.
///
/// shortcut: devices with no biometric or screen lock (web, emulators) reveal
/// without a prompt, matching the previous ungated behaviour; gate on the
/// session PIN once the app has one.
Future<bool> confirmCardReveal() async {
  final bio = BiometricService();
  if (!await bio.canAuthenticate()) return true;
  return bio.authenticate(reason: 'Confirm it is you to show card details');
}

/// Bottom sheet for issuing a new debit card on the savings account.
Future<BankCard?> showIssueCardSheet(BuildContext context) {
  return showModalBottomSheet<BankCard>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _IssueCardSheet(),
  );
}

class _IssueCardSheet extends StatefulWidget {
  const _IssueCardSheet();

  @override
  State<_IssueCardSheet> createState() => _IssueCardSheetState();
}

class _IssueCardSheetState extends State<_IssueCardSheet> {
  CardNetwork _network = CardNetwork.visa;
  bool _virtual = true;

  @override
  Widget build(BuildContext context) {
    final preview = BankCard(
      id: 'preview-${_network.name}',
      title: _virtual ? 'Aura Virtual' : 'Aura Debit',
      cardNumber: _network == CardNetwork.visa
          ? '4123 0000 0000 0000'
          : '5235 0000 0000 0000',
      expiry: '--/--',
      cvv: '---',
      holderName: BankService().user.name,
      network: _network,
      isVirtual: _virtual,
    );

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('New debit card',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.4)),
            const SizedBox(height: 6),
            const Text(
              'Spends from your savings account. Virtual cards are ready right away.',
              style: TextStyle(
                  fontSize: 14, color: AuraColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 20),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: AspectRatio(
                  aspectRatio: kCardAspect,
                  child: AnimatedSwitcher(
                    duration: AuraMotion.resolve(context, AuraMotion.medium),
                    switchInCurve: AuraMotion.emphasized,
                    child: AuraCardFace(
                        key: ValueKey(preview.id + _virtual.toString()),
                        card: preview,
                        lift: 0.6),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const _SheetLabel('Network'),
            const SizedBox(height: 10),
            SegmentedButton<CardNetwork>(
              showSelectedIcon: false,
              style: _segmentStyle,
              segments: [
                for (final n in CardNetwork.values)
                  ButtonSegment(
                      value: n,
                      label: Text(n.label),
                      icon: SizedBox(
                          width: 26,
                          child: NetworkMark(network: n, width: 26))),
              ],
              selected: {_network},
              onSelectionChanged: (s) => setState(() => _network = s.first),
            ),
            const SizedBox(height: 18),
            const _SheetLabel('Type'),
            const SizedBox(height: 10),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              style: _segmentStyle,
              segments: const [
                ButtonSegment(
                    value: true,
                    label: Text('Virtual'),
                    icon: Icon(Icons.phone_iphone_rounded, size: 18)),
                ButtonSegment(
                    value: false,
                    label: Text('Physical'),
                    icon: Icon(Icons.credit_card_rounded, size: 18)),
              ],
              selected: {_virtual},
              onSelectionChanged: (s) => setState(() => _virtual = s.first),
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  final card = BankService()
                      .issueCard(network: _network, isVirtual: _virtual);
                  Navigator.of(context).pop(card);
                },
                child: Text(
                    _virtual ? 'Issue virtual card' : 'Order physical card'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static final ButtonStyle _segmentStyle = SegmentedButton.styleFrom(
    selectedBackgroundColor: AuraColors.mint,
    selectedForegroundColor: AuraColors.ink,
    foregroundColor: AuraColors.textSecondary,
    side: const BorderSide(color: AuraColors.cardBorder),
    minimumSize: const Size(0, 48),
    textStyle: const TextStyle(
        fontFamily: AuraTheme.fontFamily, fontWeight: FontWeight.w600),
  );
}

class _SheetLabel extends StatelessWidget {
  const _SheetLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AuraColors.textMuted));
}

/// Deck state shared by the phone and desktop cards screens: which card is in
/// front, which one is turned over, and freeze/issue actions.
mixin CardDeckState<T extends StatefulWidget> on State<T> {
  final BankService bank = BankService();
  int activeIndex = 0;
  String? revealedId;
  int _revealToken = 0;

  /// How long details stay visible before the card turns back by itself.
  static const Duration revealWindow = Duration(seconds: 20);

  BankCard get activeCard =>
      bank.cards[activeIndex.clamp(0, bank.cards.length - 1)];

  void _onBank() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    bank.addListener(_onBank);
  }

  @override
  void dispose() {
    bank.removeListener(_onBank);
    super.dispose();
  }

  void selectCard(int index) => setState(() {
        activeIndex = index;
        revealedId = null;
      });

  Future<void> toggleReveal() async {
    final card = activeCard;
    if (revealedId == card.id) {
      setState(() => revealedId = null);
      return;
    }
    if (!await confirmCardReveal() || !mounted) return;
    final token = ++_revealToken;
    setState(() => revealedId = card.id);
    Future.delayed(revealWindow, () {
      if (mounted && token == _revealToken && revealedId == card.id) {
        setState(() => revealedId = null);
      }
    });
  }

  void toggleFreeze() {
    bank.toggleCardLock(activeIndex);
    final card = activeCard;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(card.isLocked
            ? '${card.title} ending ${card.last4} is frozen. Payments will be declined.'
            : '${card.title} ending ${card.last4} is active again.'),
      ));
  }

  Future<void> issueCard() async {
    final card = await showIssueCardSheet(context);
    if (card == null || !mounted) return;
    setState(() => activeIndex = bank.cards.indexOf(card));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              '${card.network.label} ${card.kindLabel.toLowerCase()} card ending ${card.last4} is ready.')),
    );
  }
}
