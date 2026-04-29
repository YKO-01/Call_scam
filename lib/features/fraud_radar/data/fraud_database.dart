import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:my_app/features/fraud_radar/domain/models/call_check_result.dart';
import 'package:my_app/features/fraud_radar/domain/models/fraud_entry.dart';

class FraudDatabase {
  FraudDatabase({required this.entries, required this.lookup});

  final List<FraudEntry> entries;
  final Map<String, FraudEntry> lookup;
  static const String _remoteDataUrl =
      'https://vehpmilchkfhfyaogvog.supabase.co/storage/v1/object/sign/data_numbers/betrugsnummern_2016_2026.json?token=eyJraWQiOiJzdG9yYWdlLXVybC1zaWduaW5nLWtleV9jNTI4ODA5Mi02ODlhLTQ5NjUtOTY5Zi0wNGVmYzA3M2FlZTMiLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJkYXRhX251bWJlcnMvYmV0cnVnc251bW1lcm5fMjAxNl8yMDI2Lmpzb24iLCJpYXQiOjE3Nzc0OTYwOTQsImV4cCI6MTgwOTAzMjA5NH0.Lwhic0m1O-MG6gnUCKRsS1CdcNv5r5kbtvliE2w0PLI';
  static Future<FraudDatabase> load() async {
    final uri = Uri.parse(_remoteDataUrl);
    final response = await http.get(uri).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception(
        'Remote data could not be loaded (HTTP ${response.statusCode}).',
      );
    }

    final rawJson = utf8.decode(response.bodyBytes);
    final decoded = await compute(_decodeFraudEntries, rawJson);
    final lookup = <String, FraudEntry>{
      for (final entry in decoded) normalize(entry.number): entry,
    };

    return FraudDatabase(entries: decoded, lookup: lookup);
  }

  CallCheckResult checkNumber(String input) {
    final normalized = normalize(input);

    if (normalized.isEmpty) {
      return const CallCheckResult(
        number: '',
        isFraud: false,
        statusText: 'No number entered',
        reasonText: 'Please enter a phone number first.',
        category: null,
        riskScore: 0,
        sourceYear: null,
        action: null,
      );
    }

    final match = lookup[normalized];
    if (match != null) {
      return CallCheckResult(
        number: input,
        isFraud: true,
        statusText: 'Betrug',
        reasonText: 'Die Nummer wurde in der Betrugsdatenbank gefunden.',
        category: match.category,
        riskScore: match.riskScore,
        sourceYear: match.sourceYear,
        action: match.action,
      );
    }

    return CallCheckResult(
      number: input,
      isFraud: false,
      statusText: 'Safe',
      reasonText: 'Die Nummer wurde in unserer geladenen Liste nicht gefunden.',
      category: null,
      riskScore: 8,
      sourceYear: null,
      action: null,
    );
  }

  static String normalize(String raw) {
    return raw.replaceAll(RegExp(r'[^0-9]'), '');
  }
}

List<FraudEntry> _decodeFraudEntries(String rawJson) {
  final list = jsonDecode(rawJson) as List<dynamic>;
  return list
      .map((item) => FraudEntry.fromJson(item as Map<String, dynamic>))
      .toList();
}
