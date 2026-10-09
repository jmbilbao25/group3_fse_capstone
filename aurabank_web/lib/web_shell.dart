import 'package:aurabank_core/services/auth_api_service.dart';
import 'package:aurabank_core/services/bank_service.dart';
import 'package:aurabank_core/services/notification_stream_service.dart';
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

class _WebShellState extends State<WebShell> {
  late int _currentIndex;

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
    super.dispose();
  }

  void _onNavigateTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final webScreens = [
      WebDashboardScreen(onNavigateTab: _onNavigateTab),
      const WebTransferScreen(),
      const WebCardsScreen(),
      WebScanScreen(
        onBack: () => _onNavigateTab(0),
        onTransfer: () => _onNavigateTab(1),
      ),
      const WebAnalyticsScreen(),
      const WebProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Row(
        children: [
          WebSidebar(
            selectedIndex: _currentIndex,
            onDestinationSelected: _onNavigateTab,
            onLogout: () {
              Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
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
                  child: IndexedStack(
                    index: _currentIndex.clamp(0, webScreens.length - 1),
                    children: webScreens,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
