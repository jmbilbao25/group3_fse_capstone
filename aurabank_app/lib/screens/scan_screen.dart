import 'package:flutter/material.dart';
import '../services/bank_service.dart';
import '../widgets/aura_logo.dart';

class ScanScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const ScanScreen({super.key, this.onBack});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with SingleTickerProviderStateMixin {
  final BankService _bankService = BankService();
  bool _isScanning = true;
  late final AnimationController _animController;

  static const Color textDark = Color(0xFF1E1E2D);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top White Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  if (widget.onBack != null) ...[
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                      color: textDark,
                      onPressed: widget.onBack,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                    const SizedBox(width: 8),
                  ],
                  const AuraLogo(size: 32, style: AuraLogoStyle.violet, borderRadius: 8),
                  const SizedBox(width: 10),
                  const Text(
                    'Aura Bank',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textDark,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // QR Scanner Viewfinder with Animated Laser
            Center(
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // QR Code Image / Matrix
                      Container(
                        width: 220,
                        height: 220,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: CustomPaint(
                          painter: _LargeQrPainter(),
                        ),
                      ),

                      // Laser Sweep line
                      if (_isScanning)
                        AnimatedBuilder(
                          animation: _animController,
                          builder: (context, child) {
                            return Positioned(
                              top: 30 + (220 * _animController.value),
                              left: 30,
                              right: 30,
                              child: Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00E676),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF00E676).withValues(alpha: 0.8),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Stop / Start Scan Toggle
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: textDark,
                elevation: 4,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                setState(() => _isScanning = !_isScanning);
              },
              child: Text(
                _isScanning ? 'Stop Scan' : 'Start Scan',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),

            const Spacer(),

            // Bottom Actions: Upload from Gallery & Generate QR
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: textDark,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.image_outlined, size: 18),
                      label: const Text('Upload\nfrom Gallery', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Gallery QR selection opened.')),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: textDark,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                      label: const Text('Generate\nQR', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                      onPressed: () => _showMyQrModal(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMyQrModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AuraLogo(size: 40, style: AuraLogoStyle.violet, borderRadius: 10),
              const SizedBox(height: 12),
              Text(
                _bankService.user.name,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: textDark),
              ),
              Text(
                'Aura Account: ${_bankService.savingsAccountNumber}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF8A92A6)),
              ),
              const SizedBox(height: 20),
              Container(
                width: 180,
                height: 180,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: CustomPaint(painter: _LargeQrPainter()),
              ),
              const SizedBox(height: 20),
              const Text('Show this QR code to receive instant Aura-to-Aura transfers.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Color(0xFF8A92A6))),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

class _LargeQrPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1E1E2D)
      ..style = PaintingStyle.fill;

    final cell = size.width / 11.0;

    void drawFinder(double x, double y) {
      canvas.drawRect(Rect.fromLTWH(x, y, cell * 3.5, cell * 3.5), paint);
      canvas.drawRect(
        Rect.fromLTWH(x + cell * 0.7, y + cell * 0.7, cell * 2.1, cell * 2.1),
        Paint()..color = Colors.white,
      );
      canvas.drawRect(
        Rect.fromLTWH(x + cell * 1.1, y + cell * 1.1, cell * 1.3, cell * 1.3),
        paint,
      );
    }

    drawFinder(0, 0);
    drawFinder(size.width - cell * 3.5, 0);
    drawFinder(0, size.height - cell * 3.5);

    // Grid dots
    for (int r = 0; r < 11; r++) {
      for (int c = 0; c < 11; c++) {
        if ((r < 4 && c < 4) || (r < 4 && c > 6) || (r > 6 && c < 4)) continue;
        if ((r + c * 3) % 2 == 0) {
          canvas.drawRect(
            Rect.fromLTWH(c * cell + cell * 0.1, r * cell + cell * 0.1, cell * 0.8, cell * 0.8),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
