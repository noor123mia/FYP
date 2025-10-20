// Updated MatchingService.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // For Timestamp handling

class MatchingService {
  final String apiUrl;

  MatchingService({this.apiUrl = "http://192.168.10.8:7860"});

  Future<Map<String, dynamic>> matchCandidate(
      Map<String, dynamic> job, Map<String, dynamic> candidate) async {
    try {
      if (kDebugMode) {
        print('--- Match Candidate Called ---');
        print('Job ID: ${job['id']}'); 
        print('Candidate Name: ${candidate['name']}');
      }
 
      final sanitizedJob = _sanitizeDataForApi(job);
      final sanitizedCandidate = _sanitizeDataForApi(candidate);

      final response = await http.post(
        Uri.parse('$apiUrl/match/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'job': sanitizedJob,
          'candidate': sanitizedCandidate,
        }),
      );

      if (kDebugMode) {
        print('API Response Status: ${response.statusCode}');
        print('Raw Response Body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return _normalizeMatchResult(result, candidate);
      } else {
        throw Exception('API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error in matchCandidate: $e');
      }
      return _createDefaultMatchResult(candidate);
    }
  }

  Future<Map<String, dynamic>> batchMatchCandidates(
      Map<String, dynamic> job, List<Map<String, dynamic>> candidates) async {
    try {
      if (kDebugMode) {
        print('--- Batch Match Candidates Called ---');
        print('Candidates Count: ${candidates.length}');
        print('Job Title/ID: ${job['title'] ?? job['id']}');
      }

      final sanitizedJob = _sanitizeDataForApi(job);
      final sanitizedCandidates =
          candidates.map((c) => _sanitizeDataForApi(c)).toList();

      final payload = {
        "job": sanitizedJob,
        "candidates": sanitizedCandidates,
      };

      if (kDebugMode) {
        print('Final Payload sent to API:');
        print(jsonEncode(payload));
      }

      final response = await http.post(
        Uri.parse('$apiUrl/batch-match/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (kDebugMode) {
        print('Batch API Response Status: ${response.statusCode}');
        print('Raw Response Body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data.containsKey('matches') && data['matches'] is List) {
          return {
            'matches': List<Map<String, dynamic>>.from(data['matches']),
            'rawResponse': response.body,
          };
        } else {
          throw Exception('Invalid response format from batch API');
        }
      } else {
        throw Exception(
            'Batch API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error in batchMatchCandidates: $e');
        print('Falling back to individual matching');
      }

      List<Map<String, dynamic>> results = [];
      for (int i = 0; i < candidates.length; i += 5) {
        final batch = candidates.sublist(
            i, i + 5 > candidates.length ? candidates.length : i + 5);
        final batchResults = await Future.wait(
            batch.map((candidate) => matchCandidate(job, candidate)));
        results.addAll(batchResults);
      }
      return {
        'matches': results,
        'rawResponse': '',
      };
    }
  }

  // Updated: Recursively sanitize data and convert Timestamps to ISO strings
  Map<String, dynamic> _sanitizeDataForApi(Map<String, dynamic> data) {
    final result = <String, dynamic>{};
    data.forEach((key, value) {
      if (key == 'reference' || key == 'createdAt' || key == 'updatedAt') {
        return; // Skip these fields
      }
      result[key] = _convertToEncodable(value);
    });
    return result;
  }

  // Helper: Recursively convert Timestamps and nested structures to JSON-encodable types
  dynamic _convertToEncodable(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) {
      return value.toDate().toIso8601String(); // Fixed: Use toDate() first
    }
    if (value is Map<String, dynamic>) {
      return value.map((k, v) => MapEntry(k, _convertToEncodable(v)));
    }
    if (value is List) {
      return value.map((v) => _convertToEncodable(v)).toList();
    }
    // For other types like DateTime, convert if needed
    if (value is DateTime) {
      return value.toIso8601String();
    }
    return value;
  }

  Map<String, dynamic> _createDefaultMatchResult(
      Map<String, dynamic> candidate) {
    return {
      'candidate': candidate,
      'match_score': 0.0,
      'category_scores': {
        'required_skills': 0.0,
        'qualification': 0.0,
        'work_experience': 0.0,
        'tech_stack': 0.0,
      },
      'matching_skills': [],
    };
  }

  Map<String, dynamic> _normalizeMatchResult(
      Map<String, dynamic> result, Map<String, dynamic> candidate) {
    return {
      'candidate': candidate,
      'match_score': (result['overall_match_score'] as num?)?.toDouble() ?? 0.0,
      'category_scores': result['category_scores'] as Map<String, dynamic>? ??
          {
            'required_skills': 0.0,
            'qualification': 0.0,
            'work_experience': 0.0,
            'tech_stack': 0.0,
          },
      'matching_skills': result['matching_skills'] as List? ?? [],
    };
  }
}
