import 'package:aurabank_core/services/auth_api_service.dart';
import 'package:aurabank_core/services/bank_service.dart';
import 'package:aurabank_core/services/notification_stream_service.dart';
import 'package:aurabank_core/theme/aura_theme.dart';
import 'package:flutter/material.dart';

import 'screens/web/analytics/web_analytics_screen.dart';
import 'screens/web/cards/web_cards_screen.dart';
import 'screens/web/dashboard/web_dashboard_screen.dart';
import 'screens/web/dashboard/web_header.dart';
import 'screens/web/dashboard/web_sidebar.dart';
import 'screens/web/profile/web_profile_screen.dart';
import 'screens/web/scan/web_scan_screen.dart';
import 'screens/web/transfer/web_transfer_screen.dart';

class WebShell extends StatefulWidget {
  final int initialIndex;

  const WebShell({super.key, this.initialIndex = 0});

  @override
  State<WebShell> createState() => _WebShellState();
}

class _WebShellState extends State<WebShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tabFade = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 300), value: 1);
  late final Animation<double> _tabCurve =
      CurvedAnimation(parent: _tabFade, curve: AuraMotion.emphasized);
  late int _currentIndex;
  QuickTransferDraft? _quickTransferDraft;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    BankService().syncWithBackend();
    final uid = AuthApiService().currentUserId ?? 'USR-0001';
    NotificationStreamService().connect(uid);
  }

  @override
  void dispose() {
    NotificationStreamService().disconnect();
    _tabFade.dispose();
    super.dispose();
  }

  void _onNavigateTab(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    if (!AuraMotion.reduced(context)) _tabFade.forward(from: 0);
  }

  /// Fade-through on the whole stack, so tab state is kept but the switch reads.
  Widget _fade(Widget child) => FadeTransition(
        opacity: _tabCurve,
        child: ScaleTransition(
            scale: Tween(begin: 0.985, end: 1.0).animate(_tabCurve),
            child: child),
      );

  @override
  Widget build(BuildContext context) {
    final webScreens = [
      WebDashboardScreen(
        onNavigateTab: _onNavigateTab,
        onQuickTransfer: (draft) {
          setState(() {
            _quickTransferDraft = draft;
            _currentIndex = 1;
          });
        },
      ),
      WebTransferScreen(draft: _quickTransferDraft),
      const WebCardsScreen(),
      WebScanScreen(
        onBack: () => _onNavigateTab(0),
        onTransfer: () => _onNavigateTab(1),
      ),
      const WebAnalyticsScreen(),
      const WebProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: AuraColors.canvas,
      body: Row(
        children: [
          WebSidebar(
            selectedIndex: _currentIndex,
            onDestinationSelected: _onNavigateTab,
            onLogout: () {
              Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                WebHeader(
                  onQuickTransfer: () => _onNavigateTab(1),
                  onRefresh: () {
                    BankService().syncWithBackend();
                  },
                ),
                Expanded(
                  child: _fade(IndexedStack(
                    index: _currentIndex.clamp(0, webScreens.length - 1),
                    children: webScreens,
                  )),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
