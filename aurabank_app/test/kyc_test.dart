import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:aurabank_app/services/kyc_service.dart';
import 'package:aurabank_app/services/bank_service.dart';
import 'package:aurabank_app/screens/kyc_wizard_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('KycDocumentType Model Tests', () {
    test('Should support all 5 Philippine Government ID types', () {
      final types = KycDocumentType.supportedTypes;
      expect(types.length, 5);

      final codes = types.map((t) => t.code).toList();
      expect(codes, containsAll(['PHILID', 'DRIVERS_LICENSE', 'PASSPORT', 'UMID', 'POSTAL_ID']));
    });

    test('Passport should require only front page', () {
      final passport = KycDocumentType.supportedTypes.firstWhere((t) => t.code == 'PASSPORT');
      expect(passport.requiresBack, isFalse);
    });

    test('PhilID and Driver License should require front and back', () {
      final philId = KycDocumentType.supportedTypes.firstWhere((t) => t.code == 'PHILID');
      final dl = KycDocumentType.supportedTypes.firstWhere((t) => t.code == 'DRIVERS_LICENSE');

      expect(philId.requiresBack, isTrue);
      expect(dl.requiresBack, isTrue);
    });
  });

  group('KycUploadIntent & KycVerificationResult Parsing Tests', () {
    test('Should parse KycUploadIntent JSON correctly', () {
      final json = {
        'submissionId': 'KYC-2026-9901',
        'containerName': 'kyc-vault',
        'expiresInSeconds': 300,
        'frontSlot': {
          'slotName': 'id_front',
          'blobPath': 'users/USR-1/KYC-2026-9901/id_front.jpg',
          'uploadUrl': 'http://localhost:10000/kyc-vault/users/USR-1/KYC-2026-9901/id_front.jpg?sp=cw',
          'httpMethod': 'PUT',
        },
        'backSlot': {
          'slotName': 'id_back',
          'blobPath': 'users/USR-1/KYC-2026-9901/id_back.jpg',
          'uploadUrl': 'http://localhost:10000/kyc-vault/users/USR-1/KYC-2026-9901/id_back.jpg?sp=cw',
          'httpMethod': 'PUT',
        },
        'selfieSlot': {
          'slotName': 'selfie',
          'blobPath': 'users/USR-1/KYC-2026-9901/selfie.jpg',
          'uploadUrl': 'http://localhost:10000/kyc-vault/users/USR-1/KYC-2026-9901/selfie.jpg?sp=cw',
          'httpMethod': 'PUT',
        },
      };

      final intent = KycUploadIntent.fromJson(json);

      expect(intent.submissionId, 'KYC-2026-9901');
      expect(intent.containerName, 'kyc-vault');
      expect(intent.expiresInSeconds, 300);
      expect(intent.frontSlot.slotName, 'id_front');
      expect(intent.backSlot?.slotName, 'id_back');
      expect(intent.selfieSlot.slotName, 'selfie');
      expect(intent.frontSlot.httpMethod, 'PUT');
    });

    test('Should parse KycVerificationResult for Approved decision', () {
      final json = {
        'userId': 'USR-100001',
        'submissionId': 'KYC-2026-9901',
        'kycStatus': 'VERIFIED',
        'userStatus': 'ACTIVE',
        'confidenceScore': 94.5,
        'message': 'Identity successfully verified.',
        'reasons': ['High face similarity', 'Valid PhilID OCR match'],
      };

      final result = KycVerificationResult.fromJson(json);

      expect(result.userId, 'USR-100001');
      expect(result.isApproved, isTrue);
      expect(result.isPendingReview, isFalse);
      expect(result.isRejected, isFalse);
      expect(result.confidenceScore, 94.5);
      expect(result.reasons.length, 2);
    });

    test('Should parse KycVerificationResult for Pending Review decision', () {
      final json = {
        'userId': 'USR-100001',
        'submissionId': 'KYC-2026-9902',
        'kycStatus': 'PENDING_REVIEW',
        'userStatus': 'ACTIVE',
        'confidenceScore': 78.0,
        'message': 'Application under compliance review.',
        'reasons': ['Minor name discrepancy detected'],
      };

      final result = KycVerificationResult.fromJson(json);

      expect(result.isApproved, isFalse);
      expect(result.isPendingReview, isTrue);
      expect(result.isRejected, isFalse);
    });

    test('Should parse KycVerificationResult for Rejected decision', () {
      final json = {
        'userId': 'USR-100001',
        'submissionId': 'KYC-2026-9903',
        'kycStatus': 'REJECTED',
        'userStatus': 'ACTIVE',
        'confidenceScore': 42.0,
        'message': 'Face mismatch detected.',
        'reasons': ['Biometric selfie does not match ID portrait crop'],
      };

      final result = KycVerificationResult.fromJson(json);

      expect(result.isApproved, isFalse);
      expect(result.isPendingReview, isFalse);
      expect(result.isRejected, isTrue);
    });
  });

  group('KycService Mocked HTTP Tests', () {
    test('requestUploadIntent should parse response properly from mock server', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/api/v1/kyc/upload-intent')) {
          final body = {
            'submissionId': 'KYC-MOCK-001',
            'containerName': 'kyc-vault',
            'expiresInSeconds': 300,
            'frontSlot': {
              'slotName': 'id_front',
              'blobPath': 'path/front.jpg',
              'uploadUrl': 'http://localhost:10000/upload-front',
              'httpMethod': 'PUT',
            },
            'selfieSlot': {
              'slotName': 'selfie',
              'blobPath': 'path/selfie.jpg',
              'uploadUrl': 'http://localhost:10000/upload-selfie',
              'httpMethod': 'PUT',
            },
          };
          return http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('Not Found', 404);
      });

      final service = KycService();
      service.httpClient = mockClient;

      final intent = await service.requestUploadIntent(idType: 'PASSPORT', requireBack: false);

      expect(intent, isNotNull);
      expect(intent!.submissionId, 'KYC-MOCK-001');
      expect(intent.expiresInSeconds, 300);
      expect(intent.frontSlot.uploadUrl, 'http://localhost:10000/upload-front');
    });

    test('verifySubmission should update BankService user kycStatus on approval', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/api/v1/kyc/verify')) {
          final body = {
            'userId': 'USR-TEST-01',
            'submissionId': 'KYC-MOCK-001',
            'kycStatus': 'VERIFIED',
            'userStatus': 'ACTIVE',
            'confidenceScore': 95.0,
            'message': 'Account verified',
            'reasons': ['Automated approval'],
          };
          return http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('Not Found', 404);
      });

      final service = KycService();
      service.httpClient = mockClient;

      final result = await service.verifySubmission(
        submissionId: 'KYC-MOCK-001',
        idType: 'PHILID',
      );

      expect(result.isApproved, isTrue);
      expect(BankService().user.kycStatus, 'VERIFIED');
      expect(BankService().user.isKycVerified, isTrue);
    });
  });

  group('KycWizardScreen UI Rendering Tests', () {
    testWidgets('Renders KycWizardScreen with Document Type choices', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: KycWizardScreen(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Identity Verification'), findsOneWidget);
      expect(find.text('Choose your document'), findsOneWidget);
      expect(find.text('Philippine National ID'), findsOneWidget);
      expect(find.text("Driver's License"), findsOneWidget);
      expect(find.text('Philippine Passport'), findsOneWidget);
      expect(find.text('Continue to Document Capture'), findsOneWidget);
    });
  });
}
