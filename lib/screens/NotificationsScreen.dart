/*import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_2/services/matching_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationscreenState();
}

class _NotificationscreenState extends State<NotificationsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final MatchingService _matchingService;

  bool _isLoading = true;
  String? _errorMessage;

  // Results tracking
  int _totalJobsProcessed = 0;
  int _totalNotificationsSent = 0;
  List<String> _jobsProcessed = [];
  List<String> _notifiedCandidates = [];
  Map<String, List<String>> _jobToCandidateNotifications = {};

  @override
  void initState() {
    super.initState();
    _matchingService = MatchingService();
    WidgetsBinding.instance.addPostFrameCallback(
      (timeStamp) {
        _processAllJobs();
      },
    );
  }

  Map<String, dynamic> _sanitizeDocument(Map<String, dynamic> doc) {
    final result = <String, dynamic>{};

    doc.forEach((key, value) {
      if (value is Timestamp) {
        result[key] = value.toDate().toIso8601String();
      } else if (value is Map) {
        result[key] = _sanitizeDocument(Map<String, dynamic>.from(value));
      } else if (value is List) {
        result[key] = value.map((item) {
          if (item is Map) {
            return _sanitizeDocument(Map<String, dynamic>.from(item));
          } else if (item is Timestamp) {
            return item.toDate().toIso8601String();
          } else {
            return item;
          }
        }).toList();
      } else {
        result[key] = value;
      }
    });

    return result;
  }

  Future<void> _processAllJobs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _totalJobsProcessed = 0;
      _totalNotificationsSent = 0;
      _jobsProcessed = [];
      _notifiedCandidates = [];
      _jobToCandidateNotifications = {};
    });

    try {
      // Step 1: Get existing notifications to avoid duplicates
      Map<String, Set<String>> existingNotifications = {};
      final notificationsSnapshot =
          await _firestore.collection('Notifications').get();

      for (var doc in notificationsSnapshot.docs) {
        final data = doc.data();
        if (data.containsKey('jobId') && data.containsKey('candidateId')) {
          String jobId = data['jobId'];
          String candidateId = data['candidateId'];

          if (!existingNotifications.containsKey(jobId)) {
            existingNotifications[jobId] = {};
          }
          existingNotifications[jobId]!.add(candidateId);
        }
      }

      // Step 2: Get all jobs
      final jobsQuery = await _firestore.collection('JobsPosted').get();

      if (jobsQuery.docs.isEmpty) {
        setState(() {
          _errorMessage = 'No jobs found';
          _isLoading = false;
        });
        return;
      }

      // Step 3: Get all candidates
      final candidatesQuery =
          await _firestore.collection('JobSeekersProfiles').get();

      if (candidatesQuery.docs.isEmpty) {
        setState(() {
          _errorMessage = 'No candidates found in the system';
          _isLoading = false;
        });
        return;
      }

      List<Map<String, dynamic>> candidates = [];
      for (var doc in candidatesQuery.docs) {
        Map<String, dynamic> data = _sanitizeDocument(doc.data());
        data['id'] = doc.id;
        candidates.add(data);
      }

      // Step 4: Process each job and match with candidates
      for (var jobDoc in jobsQuery.docs) {
        Map<String, dynamic> job = _sanitizeDocument(jobDoc.data());
        job['id'] = jobDoc.id;

        try {
          // Match candidates for this job
          final response =
              await _matchingService.batchMatchCandidates(job, candidates);

          if (response is Map<String, dynamic> &&
              response.containsKey('matches') &&
              response['matches'] is List) {
            List<Map<String, dynamic>> matches = (response['matches'] as List)
                .cast<Map<String, dynamic>>()
                .toList();

            // Filter candidates with match score > 0.4 (40%)
            final eligibleMatches = matches.where((match) {
              final rawMatchScore = match['match_score'] as num? ?? 0.0;
              final double matchScore = rawMatchScore > 1
                  ? rawMatchScore / 100.0
                  : rawMatchScore.toDouble();
              return matchScore > 0.4;
            }).toList();

            // Send notifications to eligible candidates if not already sent
            List<String> notifiedForThisJob = [];
            for (var match in eligibleMatches) {
              final candidate =
                  match['candidate'] as Map<String, dynamic>? ?? {};
              final candidateId = candidate['id'] as String? ?? '';

              if (candidateId.isNotEmpty) {
                // Check if notification already sent for this job-candidate pair
                bool alreadySent =
                    existingNotifications.containsKey(job['id']) &&
                        existingNotifications[job['id']]!.contains(candidateId);

                if (!alreadySent) {
                  final rawMatchScore = match['match_score'] as num? ?? 0.0;
                  final double matchScore = rawMatchScore > 1
                      ? rawMatchScore / 100.0
                      : rawMatchScore.toDouble();

                  await _sendNotification(job, candidate, matchScore);

                  // Update tracking information
                  _totalNotificationsSent++;
                  final candidateName = candidate['name'] ?? candidateId;
                  _notifiedCandidates.add(candidateName);
                  notifiedForThisJob.add(candidateName);

                  // Make sure we don't send this notification again in this session
                  if (!existingNotifications.containsKey(job['id'])) {
                    existingNotifications[job['id']] = {};
                  }
                  existingNotifications[job['id']]!.add(candidateId);
                }
              }
            }

            if (notifiedForThisJob.isNotEmpty) {
              _jobToCandidateNotifications[job['title'] ?? 'Untitled Job'] =
                  notifiedForThisJob;
            }
          }

          // Update job processing tracking
          _totalJobsProcessed++;
          _jobsProcessed.add(job['title'] ?? 'Untitled Job');

          // Update UI periodically to show progress
          if (_totalJobsProcessed % 2 == 0 ||
              _totalJobsProcessed == jobsQuery.docs.length) {
            setState(() {});
          }
        } catch (e) {
          print('Error processing job ${job['title']}: $e');
          // Continue to next job
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error processing jobs: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _sendNotification(Map<String, dynamic> job,
      Map<String, dynamic> candidate, double matchScore) async {
    try {
      // Create notification document
      await _firestore.collection('Notifications').add({
        'candidateId': candidate['id'],
        'jobId': job['id'],
        'jobTitle': job['title'],
        'companyName': job['company_name'],
        'matchScore': matchScore,
        'message': 'This job matches your profile. You should apply for it!',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'recruiterId': _auth.currentUser!.uid,
      });
    } catch (e) {
      print(
          'Failed to send notification to ${candidate['id']} for job ${job['id']}: $e');
    }
  }

  // Firebase listener setup for automatic processing of new jobs and candidates
  void _setupFirebaseListeners() {
    // Listen for new jobs
    _firestore
        .collection('JobsPosted')
        .where('recruiterId', isEqualTo: _auth.currentUser!.uid)
        .snapshots()
        .listen((snapshot) {
      // Process any new jobs that appear
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          // A new job was added, process it
          _processNewJob(change.doc);
        }
      }
    });

    // Listen for new candidate profiles
    _firestore.collection('JobSeekersProfiles').snapshots().listen((snapshot) {
      // Process any new candidates against all jobs
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          // A new candidate was added, process them against all jobs
          _processNewCandidate(change.doc);
        }
      }
    });
  }

  Future<void> _processNewJob(DocumentSnapshot jobDoc) async {
    try {
      Map<String, dynamic> job =
          _sanitizeDocument(jobDoc.data() as Map<String, dynamic>);
      job['id'] = jobDoc.id;

      // Get all candidates
      final candidatesQuery =
          await _firestore.collection('JobSeekersProfiles').get();

      List<Map<String, dynamic>> candidates = [];
      for (var doc in candidatesQuery.docs) {
        Map<String, dynamic> data = _sanitizeDocument(doc.data());
        data['id'] = doc.id;
        candidates.add(data);
      }

      // Match candidates for this new job
      final response =
          await _matchingService.batchMatchCandidates(job, candidates);

      if (response is Map<String, dynamic> &&
          response.containsKey('matches') &&
          response['matches'] is List) {
        List<Map<String, dynamic>> matches =
            (response['matches'] as List).cast<Map<String, dynamic>>().toList();

        // Filter candidates with match score > 0.4 (40%)
        final eligibleMatches = matches.where((match) {
          final rawMatchScore = match['match_score'] as num? ?? 0.0;
          final double matchScore = rawMatchScore > 1
              ? rawMatchScore / 100.0
              : rawMatchScore.toDouble();
          return matchScore > 0.4;
        }).toList();

        // Send notifications to eligible candidates
        for (var match in eligibleMatches) {
          final candidate = match['candidate'] as Map<String, dynamic>? ?? {};
          final candidateId = candidate['id'] as String? ?? '';

          if (candidateId.isNotEmpty) {
            // Check if notification already sent
            final existingNotifs = await _firestore
                .collection('Notifications')
                .where('jobId', isEqualTo: job['id'])
                .where('candidateId', isEqualTo: candidateId)
                .get();

            if (existingNotifs.docs.isEmpty) {
              final rawMatchScore = match['match_score'] as num? ?? 0.0;
              final double matchScore = rawMatchScore > 1
                  ? rawMatchScore / 100.0
                  : rawMatchScore.toDouble();

              await _sendNotification(job, candidate, matchScore);
            }
          }
        }
      }
    } catch (e) {
      print('Error processing new job: $e');
    }
  }

  Future<void> _processNewCandidate(DocumentSnapshot candidateDoc) async {
    try {
      Map<String, dynamic> candidate =
          _sanitizeDocument(candidateDoc.data() as Map<String, dynamic>);
      candidate['id'] = candidateDoc.id;

      // Get all jobs for this recruiter
      final jobsQuery = await _firestore
          .collection('JobsPosted')
          .where('recruiterId', isEqualTo: _auth.currentUser!.uid)
          .get();

      for (var jobDoc in jobsQuery.docs) {
        Map<String, dynamic> job = _sanitizeDocument(jobDoc.data());
        job['id'] = jobDoc.id;

        // Match this candidate with the job
        final response = await _matchingService.matchCandidate(job, candidate);

        if (response is Map<String, dynamic> &&
            response.containsKey('match_score')) {
          final rawMatchScore = response['match_score'] as num? ?? 0.0;
          final double matchScore = rawMatchScore > 1
              ? rawMatchScore / 100.0
              : rawMatchScore.toDouble();

          // If match score > 40%, send notification if not already sent
          if (matchScore > 0.4) {
            // Check if notification already sent
            final existingNotifs = await _firestore
                .collection('Notifications')
                .where('jobId', isEqualTo: job['id'])
                .where('candidateId', isEqualTo: candidate['id'])
                .get();

            if (existingNotifs.docs.isEmpty) {
              await _sendNotification(job, candidate, matchScore);
            }
          }
        }
      }
    } catch (e) {
      print('Error processing new candidate: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          "Automatic Job Matching",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _processAllJobs,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _errorMessage != null
              ? _buildErrorState()
              : _buildResultScreen(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Set up listeners for automatic processing of new jobs and candidates
          _setupFirebaseListeners();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Automatic monitoring for new jobs and candidates is active'),
              backgroundColor: Colors.green,
            ),
          );
        },
        backgroundColor: const Color(0xFF1E3A8A),
        child: const Icon(Icons.sync),
        tooltip: 'Start Automatic Monitoring',
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          const Text(
            'Processing jobs and sending notifications...',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          if (_totalJobsProcessed > 0)
            Text(
              'Jobs processed: $_totalJobsProcessed\nNotifications sent: $_totalNotificationsSent',
              style: const TextStyle(fontSize: 14),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? 'An error occurred',
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _processAllJobs,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
              foregroundColor: Colors.white,
              elevation: 3,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultScreen() {
    return SingleChildScrollView(
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 5,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _totalNotificationsSent > 0 ? Icons.check_circle : Icons.info,
                size: 72,
                color: _totalNotificationsSent > 0 ? Colors.green : Colors.blue,
              ),
              const SizedBox(height: 24),
              Text(
                _totalNotificationsSent > 0
                    ? 'Job Matching Complete!'
                    : 'No New Notifications Sent',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A8A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Processed $_totalJobsProcessed jobs and sent $_totalNotificationsSent notifications to candidates with match scores greater than 40%.',
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (_jobToCandidateNotifications.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Notifications Sent:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._jobToCandidateNotifications.entries.map((entry) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Job: ${entry.key}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Candidates Notified:',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            ...entry.value.map((candidateName) {
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.person,
                                      size: 16,
                                      color: Colors.green,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(candidateName),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _processAllJobs,
                icon: const Icon(Icons.refresh),
                label: const Text('Process Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  elevation: 3,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Click the sync button to enable automatic processing of new jobs and candidates.',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
*/
