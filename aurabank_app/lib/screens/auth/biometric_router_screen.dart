import 'package:flutter/material.dart';
import '../../services/bank_service.dart';
import 'login_screen.dart';
import 'login_page_face_id.dart';
import 'login_page_fingerprint.dart';

class BiometricRouterScreen extends StatelessWidget {
  const BiometricRouterScreen({super.key});

  @override
  Widget build(BuildContext context) {

    final user = BankService().user;

    if (user.faceIdEnabled) {
      return const LoginPageFaceId();
    }

    if (user.fingerprintEnabled) {
      return const LoginPageFingerprint();
    }

    return const LoginScreen();
  }
}