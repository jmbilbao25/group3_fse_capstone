import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_api_service.dart' show defaultBackendHost;

String get defaultMailHogHost => defaultBackendHost;

class MailHogEmail {
  final String id;
  final String from;
  final String to;
  final String subject;
  final String body;
  final String? otpCode;
  final DateTime createdAt;

  const MailHogEmail({
    required this.id,
    required this.from,
    required this.to,
    required this.subject,
    required this.body,
    this.otpCode,
    required this.createdAt,
  });
}

/// Service that interacts directly with MailHog Web API (:8025)
/// to fetch the actual emails dispatched by backend notification-service.
class OtpService {
  static final OtpService _instance = OtpService._internal();
  factory OtpService() => _instance;
  OtpService._internal();

  /// MailHog Web/API endpoint
  String mailHogApiUrl = 'http://$defaultMailHogHost:8025';
  http.Client? httpClient;

  http.Client get _client => httpClient ?? http.Client();

  /// Fetches the latest email caught by MailHog for the given recipient email.
  Future<MailHogEmail?> fetchLatestEmail({String? recipientEmail}) async {
    final endpoints = [
      'http://$defaultMailHogHost:8025/api/v2/messages',
      'http://$defaultMailHogHost:8080/api/v2/messages',
    ];

    bool isMatch(String address, String query) {
      if (query.trim().isEmpty) return true;
      final addr = address.trim().toLowerCase();
      final q = query.trim().toLowerCase();
      if (addr == q) return true;
      if (q.contains('*')) {
        final qParts = q.split('@');
        final aParts = addr.split('@');
        if (qParts.length == 2 && aParts.length == 2) {
          if (qParts[1] != aParts[1]) return false;
          final prefix = qParts[0].split('*').first;
          final suffix = qParts[0].split('*').last;
          return aParts[0].startsWith(prefix) && aParts[0].endsWith(suffix);
        }
      }
      return false;
    }

    for (final endpoint in endpoints) {
      try {
        final url = Uri.parse(endpoint);
        final response = await _client.get(url).timeout(const Duration(seconds: 3));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final items = (data['items'] as List<dynamic>?) ?? [];

        for (final item in items) {
          final toList = (item['To'] as List<dynamic>?) ?? [];
          final bool matchesRecipient = recipientEmail == null ||
              toList.any((to) {
                final mailbox = to['Mailbox'] as String? ?? '';
                final domain = to['Domain'] as String? ?? '';
                final address = '$mailbox@$domain'.toLowerCase();
                return isMatch(address, recipientEmail);
              });

          if (matchesRecipient) {
            final headers = item['Content']?['Headers'] as Map<String, dynamic>?;
            final subjectList = headers?['Subject'] as List<dynamic>?;
            final subject = subjectList?.isNotEmpty == true
                ? subjectList!.first.toString()
                : 'AuraBank Notification';

            final body = item['Content']?['Body'] as String? ?? '';

            // Extract 6-digit numeric OTP code safely (never match CSS hex color codes like #475569)
            String? otpCode;

            // 1. Explicit OTP match in Subject (e.g. "Aura Bank: 112233 is your ...")
            final subjectCodeMatch = RegExp(r'(?:Aura Bank:\s*|code(?:\s+is)?\s*|otp[:\s]+)(\d{6})\b', caseSensitive: false).firstMatch(subject) ??
                RegExp(r'\b(\d{6})\b').firstMatch(subject);
            if (subjectCodeMatch != null) {
              otpCode = subjectCodeMatch.group(1);
            }

            // 2. HTML container match: <div class="otp-code">112233</div> (handles quoted-printable "=3D")
            if (otpCode == null) {
              final htmlCodeMatch = RegExp(
                r'class=(?:"|3D")?otp-code(?:"|3D")?[^>]*>\s*(\d{6})\s*<',
                caseSensitive: false,
              ).firstMatch(body);
              if (htmlCodeMatch != null) {
                otpCode = htmlCodeMatch.group(1);
              }
            }

            // 3. Keyword-associated OTP match in body text
            if (otpCode == null) {
              final keywordMatch = RegExp(
                r'(?:code is|verification code(?:\s+is)?|otp[:\s]+|one-time (?:password|code)(?:\s+is)?)[^\d]{0,20}(\d{6})\b',
                caseSensitive: false,
              ).firstMatch(body);
              if (keywordMatch != null) {
                otpCode = keywordMatch.group(1);
              }
            }

            // 4. Safe fallback: Strip HTML tags, <head>, <style>, and CSS hex color codes before general 6-digit match
            if (otpCode == null) {
              final cleanBody = body
                  .replaceAll(RegExp(r'<style[^>]*>[\s\S]*?<\/style>', caseSensitive: false), ' ')
                  .replaceAll(RegExp(r'<head[^>]*>[\s\S]*?<\/head>', caseSensitive: false), ' ')
                  .replaceAll(RegExp(r'#[0-9a-fA-F]{3,8}\b'), ' ');
              final fallbackMatch = RegExp(r'\b(\d{6})\b').firstMatch(cleanBody);
              otpCode = fallbackMatch?.group(1);
            }

            final fromMap = item['From'] as Map<String, dynamic>?;
            final fromMailbox = fromMap?['Mailbox'] as String? ?? 'noreply';
            final fromDomain = fromMap?['Domain'] as String? ?? 'corebank.ph';

            final createdStr = item['Created'] as String? ?? '';
            final createdAt = DateTime.tryParse(createdStr) ?? DateTime.now();

            return MailHogEmail(
              id: item['ID']?.toString() ?? '',
              from: '$fromMailbox@$fromDomain',
              to: recipientEmail ?? 'recipient',
              subject: subject,
              body: body,
              otpCode: otpCode,
              createdAt: createdAt,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('MailHog fetch error ($e)');
    }
    }
    return null;
  }
}
