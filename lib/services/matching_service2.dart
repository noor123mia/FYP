// MatchingService.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MatchingService {
  final String apiUrl;

  // MatchingService({this.apiUrl = "http://172.0.5.121:7860"});
  MatchingService({this.apiUrl = "http://192.168.10.4:7860"});
  // Constructor with default URL or custom URL
  // MatchingService({this.apiUrl = "https://MIA1924-job-matching-api.hf.space"});

  /// Match applied candidates with a specific job
  Future<Map<String, dynamic>> matchAppliedCandidatesWithJob(
      Map<String, dynamic> job,
      List<Map<String, dynamic>> appliedCandidates) async {
    try {
      if (kDebugMode) {
        print('--- Match Applied Candidates With Job Called ---');
        print('Job Title: ${job['title']}');
        print('Applied Candidates Count: ${appliedCandidates.length}');
      }

      final sanitizedJob = _sanitizeDataForApi(job);
      final sanitizedCandidates =
          appliedCandidates.map((c) => _sanitizeDataForApi(c)).toList();

      final payload = {
        "job": sanitizedJob,
        "applied_candidates": sanitizedCandidates,
      };

      if (kDebugMode) {
        print('Applied Candidates Match Payload:');
        print(jsonEncode(payload));
      }

      final response = await http.post(
        Uri.parse('$apiUrl/applied-candidates-match/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (kDebugMode) {
        print(
            'Applied Candidates Match API Response Status: ${response.statusCode}');
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
          throw Exception(
              'Invalid response format from applied candidates match API');
        }
      } else {
        throw Exception(
            'Applied Candidates Match API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error in matchAppliedCandidatesWithJob: $e');
      }
      return {
        'matches': [],
        'error': e.toString(),
        'rawResponse': '',
      };
    }
  }

  /// Detect duplicate candidates in applied candidates list
  Future<Map<String, dynamic>> detectDuplicateCandidates(
      List<Map<String, dynamic>> appliedCandidates,
      {double similarityThreshold = 0.85}) async {
    try {
      if (kDebugMode) {
        print('--- Detect Duplicate Candidates Called ---');
        print('Applied Candidates Count: ${appliedCandidates.length}');
        print('Similarity Threshold: $similarityThreshold');
      }

      final sanitizedCandidates =
          appliedCandidates.map((c) => _sanitizeDataForApi(c)).toList();

      final payload = {
        "applied_candidates": sanitizedCandidates,
        "similarity_threshold": similarityThreshold,
      };

      final response = await http.post(
        Uri.parse('$apiUrl/detect-duplicates/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (kDebugMode) {
        print(
            'Duplicate Detection API Response Status: ${response.statusCode}');
        print('Raw Response Body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'duplicate_groups': data['duplicate_groups'] ?? [],
          'total_duplicates': data['total_duplicates'] ?? 0,
          'unique_candidates':
              data['unique_candidates'] ?? appliedCandidates.length,
          'rawResponse': response.body,
        };
      } else {
        throw Exception(
            'Duplicate Detection API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error in detectDuplicateCandidates: $e');
      }
      return {
        'duplicate_groups': [],
        'total_duplicates': 0,
        'unique_candidates': appliedCandidates.length,
        'error': e.toString(),
        'rawResponse': '',
      };
    }
  }

  /// Compare two specific candidates
  Future<Map<String, dynamic>> compareTwoCandidates(
      Map<String, dynamic> candidate1, Map<String, dynamic> candidate2) async {
    try {
      if (kDebugMode) {
        print('--- Compare Two Candidates Called ---');
        print('Candidate 1: ${candidate1['applicantName']}');
        print('Candidate 2: ${candidate2['applicantName']}');
      }

      final sanitizedCandidate1 = _sanitizeDataForApi(candidate1);
      final sanitizedCandidate2 = _sanitizeDataForApi(candidate2);

      final payload = {
        "candidate1": sanitizedCandidate1,
        "candidate2": sanitizedCandidate2,
      };

      final response = await http.post(
        Uri.parse('$apiUrl/compare-candidates/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (kDebugMode) {
        print('Compare Candidates API Response Status: ${response.statusCode}');
        print('Raw Response Body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'similarity_score': data['similarity_score'] ?? 0.0,
          'is_likely_duplicate': data['is_likely_duplicate'] ?? false,
          'candidate1_name': data['candidate1_name'] ?? '',
          'candidate2_name': data['candidate2_name'] ?? '',
          'rawResponse': response.body,
        };
      } else {
        throw Exception(
            'Compare Candidates API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error in compareTwoCandidates: $e');
      }
      return {
        'similarity_score': 0.0,
        'is_likely_duplicate': false,
        'candidate1_name': candidate1['applicantName'] ?? '',
        'candidate2_name': candidate2['applicantName'] ?? '',
        'error': e.toString(),
        'rawResponse': '',
      };
    }
  }

  /// Original match candidate method (for backward compatibility)
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

  /// Original batch match candidates method (for backward compatibility)
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

  /// Helper method to sanitize data before sending to API
  Map<String, dynamic> _sanitizeDataForApi(Map<String, dynamic> data) {
    final result = Map<String, dynamic>.from(data);
    result.remove('reference');
    result.remove('createdAt');
    result.remove('updatedAt');
    return result;
  }

  /// Helper method to create default match result
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

  /// Helper method to normalize match result
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
