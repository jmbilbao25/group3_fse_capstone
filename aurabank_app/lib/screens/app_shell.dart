import 'package:flutter/material.dart';
import 'home/home_screen.dart';
import 'cards/cards_screen.dart';
import 'scan/scan_screen.dart';
import 'analytics/analytics_screen.dart';
import 'profile/profile_screen.dart';
import '../services/auth_api_service.dart';
import '../services/bank_service.dart';
import '../services/notification_stream_service.dart';
import '../theme/aura_theme.dart';

class AppShell extends StatefulWidget {
  final int initialIndex;

  const AppShell({super.key, this.initialIndex = 0});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tabFade = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 300), value: 1);
  late final Animation<double> _tabCurve =
      CurvedAnimation(parent: _tabFade, curve: AuraMotion.emphasized);
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
    return _buildMobileShell();
  }

  Widget _buildMobileShell() {
    final screens = [
      HomeScreen(onNavigateTab: _onNavigateTab),
      const CardsScreen(),
      ScanScreen(onBack: () => _onNavigateTab(0)),
      const AnalyticsScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: AuraColors.canvas,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: _fade(IndexedStack(
            index: _currentIndex.clamp(0, screens.length - 1),
            children: screens,
          )),
        ),
      ),
      bottomNavigationBar: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: _buildBottomBar(),
        ),
      ),
    );
  }

  static const _tabs = <(int, IconData, IconData, String)>[
    (0, Icons.home_rounded, Icons.home_outlined, 'Home'),
    (1, Icons.credit_card_rounded, Icons.credit_card_outlined, 'Cards'),
    (2, Icons.qr_code_scanner_rounded, Icons.qr_code_scanner_rounded, 'Scan'),
    (3, Icons.insights_rounded, Icons.insights_outlined, 'Insights'),
    (4, Icons.person_rounded, Icons.person_outline_rounded, 'Profile'),
  ];

  Widget _buildBottomBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AuraColors.cardBorder)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            children: [
              for (final t in _tabs)
                Expanded(
                    child: t.$1 == 2
                        ? _buildScanTab()
                        : _buildNavItem(
                            index: t.$1,
                            icon: t.$2,
                            unselectedIcon: t.$3,
                            label: t.$4)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScanTab() {
    final selected = _currentIndex == 2;
    return Center(
      child: Semantics(
        button: true,
        selected: selected,
        label: 'Scan',
        child: Material(
          color: selected ? AuraColors.mint : AuraColors.ink,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => _onNavigateTab(2),
            child: SizedBox.square(
              dimension: 50,
              child: Icon(Icons.qr_code_scanner_rounded,
                  size: 22, color: selected ? AuraColors.ink : Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData unselectedIcon,
    required String label,
  }) {
    final isSelected = _currentIndex == index;
    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: InkResponse(
        onTap: () => _onNavigateTab(index),
        radius: 32,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: AuraMotion.resolve(context, AuraMotion.fast),
              curve: AuraMotion.standard,
              padding: EdgeInsets.symmetric(
                  horizontal: isSelected ? 16 : 8, vertical: 5),
              decoration: BoxDecoration(
                color: isSelected ? AuraColors.tintPurple : Colors.transparent,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Icon(isSelected ? icon : unselectedIcon,
                  size: 22,
                  color: isSelected ? AuraColors.ink : AuraColors.textMuted),
            ),
            const SizedBox(height: 3),
            ExcludeSemantics(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? AuraColors.ink : AuraColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
