import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_api_service.dart';
import 'bank_service.dart';
import 'device_storage.dart';

class KycDocumentType {
  final String code;
  final String name;
  final String description;
  final bool requiresBack;
  final String sampleFormat;

  const KycDocumentType({
    required this.code,
    required this.name,
    required this.description,
    required this.requiresBack,
    required this.sampleFormat,
  });

  static const List<KycDocumentType> supportedTypes = [
    KycDocumentType(
      code: 'PHILID',
      name: 'Philippine National ID',
      description: 'PhilSys Card (Printed or ePhilID)',
      requiresBack: true,
      sampleFormat: 'XXXX-XXXX-XXXX-XXXX',
    ),
    KycDocumentType(
      code: 'DRIVERS_LICENSE',
      name: "Driver's License",
      description: 'Land Transportation Office (LTO)',
      requiresBack: true,
      sampleFormat: 'X00-00-000000',
    ),
    KycDocumentType(
      code: 'PASSPORT',
      name: 'Philippine Passport',
      description: 'DFA Biometric Passport (Data Page)',
      requiresBack: false,
      sampleFormat: 'P0000000A',
    ),
    KycDocumentType(
      code: 'UMID',
      name: 'Unified Multi-Purpose ID (UMID)',
      description: 'SSS / GSIS issued card',
      requiresBack: true,
      sampleFormat: '0000-0000000-0',
    ),
    KycDocumentType(
      code: 'POSTAL_ID',
      name: 'Postal ID',
      description: 'PHLPost Biometric Card',
      requiresBack: true,
      sampleFormat: 'PR000000000',
    ),
  ];
}

class KycUploadSlot {
  final String slotName;
  final String blobPath;
  final String uploadUrl;
  final String httpMethod;

  KycUploadSlot({
    required this.slotName,
    required this.blobPath,
    required this.uploadUrl,
    required this.httpMethod,
  });

  factory KycUploadSlot.fromJson(Map<String, dynamic> json) {
    return KycUploadSlot(
      slotName: json['slotName']?.toString() ?? '',
      blobPath: json['blobPath']?.toString() ?? '',
      uploadUrl: json['uploadUrl']?.toString() ?? '',
      httpMethod: json['httpMethod']?.toString() ?? 'PUT',
    );
  }
}

class KycUploadIntent {
  final String submissionId;
  final String containerName;
  final int expiresInSeconds;
  final KycUploadSlot frontSlot;
  final KycUploadSlot? backSlot;
  final KycUploadSlot selfieSlot;

  KycUploadIntent({
    required this.submissionId,
    required this.containerName,
    required this.expiresInSeconds,
    required this.frontSlot,
    this.backSlot,
    required this.selfieSlot,
  });

  factory KycUploadIntent.fromJson(Map<String, dynamic> json) {
    return KycUploadIntent(
      submissionId: json['submissionId']?.toString() ?? '',
      containerName: json['containerName']?.toString() ?? 'kyc-vault',
      expiresInSeconds: (json['expiresInSeconds'] as num?)?.toInt() ?? 300,
      frontSlot: KycUploadSlot.fromJson(json['frontSlot'] ?? {}),
      backSlot: json['backSlot'] != null ? KycUploadSlot.fromJson(json['backSlot']) : null,
      selfieSlot: KycUploadSlot.fromJson(json['selfieSlot'] ?? {}),
    );
  }
}

class KycVerificationResult {
  final String userId;
  final String submissionId;
  final String kycStatus;
  final String userStatus;
  final double? confidenceScore;
  final String message;
  final List<String> reasons;

  KycVerificationResult({
    required this.userId,
    required this.submissionId,
    required this.kycStatus,
    required this.userStatus,
    this.confidenceScore,
    required this.message,
    this.reasons = const [],
  });

  bool get isApproved => kycStatus.toUpperCase() == 'VERIFIED';
  bool get isPendingReview => kycStatus.toUpperCase() == 'PENDING_REVIEW';
  bool get isRejected => kycStatus.toUpperCase() == 'REJECTED';

  factory KycVerificationResult.fromJson(Map<String, dynamic> json) {
    final rawReasons = json['reasons'];
    final List<String> parsedReasons = [];
    if (rawReasons is List) {
      for (final r in rawReasons) {
        parsedReasons.add(r.toString());
      }
    }
    return KycVerificationResult(
      userId: json['userId']?.toString() ?? '',
      submissionId: json['submissionId']?.toString() ?? '',
      kycStatus: json['kycStatus']?.toString() ?? 'PENDING_REVIEW',
      userStatus: json['userStatus']?.toString() ?? 'ACTIVE',
      confidenceScore: (json['confidenceScore'] as num?)?.toDouble(),
      message: json['message']?.toString() ?? '',
      reasons: parsedReasons,
    );
  }

  factory KycVerificationResult.error(String msg) {
    return KycVerificationResult(
      userId: '',
      submissionId: '',
      kycStatus: 'ERROR',
      userStatus: '',
      message: msg,
      reasons: [msg],
    );
  }
}

/// Service orchestrating customer e-KYC flow:
/// 1. Requesting pre-signed SAS upload intents from Account Service
/// 2. Direct binary streaming upload to Azurite / Azure Blob Storage
/// 3. Requesting automated identity verification and updating user state
class KycService {
  static final KycService _instance = KycService._internal();
  factory KycService() => _instance;
  KycService._internal();

  http.Client? httpClient;

  List<String> get _candidateEndpoints {
    final backendHost = BackendConfig().host;
    return <String>[
      BankService().baseUrl,
      'http://$backendHost:8080',
      'http://$backendHost:8081',
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) ...[
        'http://10.0.2.2:8080',
        'http://10.0.2.2:8081',
      ],
      'http://localhost:8080',
      'http://localhost:8081',
    ];
  }

  String _resolveBlobUploadUrl(String rawUrl) {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return rawUrl;
    final backendHost = BackendConfig().host;
    if ((uri.host == 'localhost' || uri.host == '127.0.0.1' || uri.host == 'azurite-storage' || uri.host == 'azurite') &&
        backendHost != 'localhost') {
      return uri.replace(host: backendHost).toString();
    }
    return rawUrl;
  }

  String? _resolveAuthToken() {
    return AuthApiService().currentAccessToken ?? DeviceStorage.getAccessToken();
  }

  /// Request pre-signed SAS upload tokens (300-second TTL) from account-service
  Future<KycUploadIntent?> requestUploadIntent({
    required String idType,
    required bool requireBack,
  }) async {
    final token = _resolveAuthToken();
    final client = httpClient ?? http.Client();
    final payload = jsonEncode({
      'idType': idType,
      'requireBack': requireBack,
    });

    for (final base in _candidateEndpoints) {
      try {
        final uri = Uri.parse('$base/api/v1/kyc/upload-intent');
        final headers = <String, String>{
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        };
        final res = await client.post(uri, headers: headers, body: payload).timeout(const Duration(seconds: 4));
        if (res.statusCode >= 200 && res.statusCode < 300) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          return KycUploadIntent.fromJson(data);
        }
      } catch (e) {
        debugPrint('[KycService] upload-intent failed on $base: $e');
      }
    }
    return null;
  }

  /// Direct binary upload of document or selfie JPEG to Azure / Azurite storage
  Future<bool> uploadBlob({
    required String uploadUrl,
    required Uint8List bytes,
  }) async {
    final client = httpClient ?? http.Client();
    final resolvedUrl = _resolveBlobUploadUrl(uploadUrl);
    try {
      final uri = Uri.parse(resolvedUrl);
      final res = await client.put(
        uri,
        headers: {
          'x-ms-blob-type': 'BlockBlob',
          'Content-Type': 'image/jpeg',
        },
        body: bytes,
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200 || res.statusCode == 201) {
        return true;
      }
      debugPrint('[KycService] Blob upload returned HTTP ${res.statusCode}: ${res.body}');
    } catch (e) {
      debugPrint('[KycService] Error uploading blob to $resolvedUrl: $e');
    }
    return false;
  }

  /// Submit verification request once all slots are uploaded
  Future<KycVerificationResult> verifySubmission({
    required String submissionId,
    required String idType,
    String? declaredName,
    String? declaredDob,
    String? declaredIdNumber,
  }) async {
    final token = _resolveAuthToken();
    final client = httpClient ?? http.Client();
    final payload = jsonEncode({
      'submissionId': submissionId,
      'idType': idType,
      if (declaredName != null && declaredName.isNotEmpty) 'declaredName': declaredName,
      if (declaredDob != null && declaredDob.isNotEmpty) 'declaredDob': declaredDob,
      if (declaredIdNumber != null && declaredIdNumber.isNotEmpty) 'declaredIdNumber': declaredIdNumber,
    });

    for (final base in _candidateEndpoints) {
      try {
        final uri = Uri.parse('$base/api/v1/kyc/verify');
        final headers = <String, String>{
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        };
        final res = await client.post(uri, headers: headers, body: payload).timeout(const Duration(seconds: 8));
        if (res.statusCode >= 200 && res.statusCode < 300) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final result = KycVerificationResult.fromJson(data);
          BankService().setKycStatus(
            result.kycStatus,
            reason: result.reasons.isNotEmpty ? result.reasons.first : null,
          );
          return result;
        } else {
          final data = jsonDecode(res.body);
          final msg = data['message'] ?? 'Verification request failed (${res.statusCode})';
          return KycVerificationResult.error(msg);
        }
      } catch (e) {
        debugPrint('[KycService] verify failed on $base: $e');
      }
    }
    return KycVerificationResult.error('Unable to reach identity verification service. Please try again.');
  }
}
