# Aura Bank Mobile and Multiplatform Client

Cross-platform Flutter application providing native mobile (iOS and Android) and responsive web experiences for the retail banking platform.

## 1. Overview and purpose

`aurabank_app` is the omnichannel client application for Aura Bank. Built with Flutter, it ensures complete layout, typography, and functional parity across Android, iOS, and modern desktop browsers (via CanvasKit / Wasm compilation).

## 2. Tech stack

* Framework: Flutter 3.x / Dart 3.x
* Architecture: Component-driven reactive UI (Material Design 3)
* Storage security: `flutter_secure_storage` interfacing with native hardware-backed keystores:
  * Android: Android KeyStore with AES-256 GCM encryption
  * iOS: Apple Keychain with biometric access controls
* HTTP client: Dio / HTTP with automatic circuit breaker and retry interceptors
* Build targets: iOS, Android, Web

## 3. Scope and boundaries

### In scope
* Splash screen, branding, and themed retail banking interface.
* Cryptographic device binding on primary mobile hardware.
* Hardware biometric authentication (Face ID, Touch ID, Android BiometricPrompt).
* Secure credential and session token storage in platform keystores.
* In-app friction modal presentation (rendering Laya advisory alerts and MPIN inputs).
* Client-side circuit breaker: If backend services are unreachable, the app renders a fail-fast maintenance notice rather than freezing.

### Out of scope
* Server-side transaction validation: Performed by `gateway-service` and `ledger-mutation-engine`.
* Fraud scoring: Handled by `risk-service`.
* SMS OTP flows: Completely eliminated per regulatory mandate.

## 4. Regulatory compliance: Zero SMS OTP

Under Bangko Sentral ng Pilipinas (BSP) Circular 1213:
* The mobile app utilizes hardware-backed biometric authentication on bound primary devices.
* No SMS OTP codes are ever sent, required, or accepted for transaction authorization.
* Step-up authentication requests use local biometrics combined with a customer transaction MPIN.

## 5. Getting started and local development

### Prerequisites
* Flutter SDK (3.19+)
* Android Studio / Xcode (for mobile emulation)

### Setup
```bash
cd aurabank_app
flutter pub get
```

### Run on connected device or emulator
```bash
# Run on Chrome
flutter run -d chrome

# Run on Android emulator
flutter run -d android

# Run on iOS simulator
flutter run -d ios
```

### Build release artifacts
```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# Web production bundle
flutter build web --release
```
