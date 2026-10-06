import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'cards_screen.dart';
import 'scan_screen.dart';
import 'analytics_screen.dart';
import 'profile_screen.dart';
import '../services/bank_service.dart';
import '../theme/aura_theme.dart';

class AppShell extends StatefulWidget {
  final int initialIndex;

  const AppShell({super.key, this.initialIndex = 0});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _currentIndex;

  static const Color brandViolet = AuraColors.primary;
  static const Color textGray = AuraColors.textMuted;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    BankService().syncWithBackend();
  }

  void _onNavigateTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(onNavigateTab: _onNavigateTab),
      const CardsScreen(),
      const ScanScreen(),
      const AnalyticsScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: _buildLuxuryBottomBar(),
    );
  }

  Widget _buildLuxuryBottomBar() {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      color: Colors.transparent,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // Background Bar Container with rounded top and violet ambient shadow
          Container(
            height: 66 + bottomInset,
            padding: EdgeInsets.only(bottom: bottomInset, top: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              border: const Border(
                top: BorderSide(color: Color(0xFFEDE9FE), width: 1.0),
              ),
              boxShadow: [
                BoxShadow(
                  color: brandViolet.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  index: 0,
                  icon: Icons.account_balance_rounded,
                  unselectedIcon: Icons.account_balance_outlined,
                  label: 'Home',
                ),
                _buildNavItem(
                  index: 1,
                  icon: Icons.credit_card_rounded,
                  unselectedIcon: Icons.credit_card_outlined,
                  label: 'Cards',
                ),
                // Spacer for elevated center floating button
                const SizedBox(width: 56),
                _buildNavItem(
                  index: 3,
                  icon: Icons.show_chart_rounded,
                  unselectedIcon: Icons.show_chart_rounded,
                  label: 'Analytics',
                ),
                _buildNavItem(
                  index: 4,
                  icon: Icons.person_rounded,
                  unselectedIcon: Icons.person_outline_rounded,
                  label: 'Profile',
                ),
              ],
            ),
          ),

          // Elevated Floating Center Action Button (Scan QR)
          Positioned(
            top: -16,
            child: GestureDetector(
              onTap: () => setState(() => _currentIndex = 2),
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AuraColors.balanceHeroGradient,
                      border: Border.all(color: Colors.white, width: 3.5),
                      boxShadow: [
                        BoxShadow(
                          color: brandViolet.withValues(alpha: 0.40),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Scan',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: _currentIndex == 2 ? FontWeight.w800 : FontWeight.w600,
                      color: _currentIndex == 2 ? brandViolet : textGray,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(
                horizontal: isSelected ? 12 : 6,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFF5EEFF) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isSelected ? icon : unselectedIcon,
                color: isSelected ? brandViolet : textGray,
                size: 22,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: isSelected ? brandViolet : textGray,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              width: 3.5,
              height: 3.5,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF10B981) : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
