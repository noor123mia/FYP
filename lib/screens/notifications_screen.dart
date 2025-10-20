import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_2/screens/JobDetailsViewScreen.dart';
import 'package:flutter_application_2/services/matching_service.dart';
import 'package:flutter_application_2/services/messaging_service.dart';
import 'package:flutter_application_2/services/job_notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final MatchingService _matchingService;
  late final MessagingService _messagingService;
  late final JobNotificationService _jobNotificationService;

  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _matchedJobs = [];
  Map<String, dynamic>? _userProfile;
  Map<String, String> _applicationStatus = {};

  @override
  void initState() {
    super.initState();
    _matchingService = MatchingService();
    _messagingService = MessagingService();
    _jobNotificationService = JobNotificationService();

    WidgetsBinding.instance.addPostFrameCallback(
      (timeStamp) {
        _messagingService.initialize(context);
        _loadUserProfile();
        _setupFirebaseListeners();
      },
    );
  }

  Future<void> _loadUserProfile() async {
    try {
      final userProfileSnapshot = await _firestore
          .collection('JobSeekersProfiles')
          .doc(_auth.currentUser!.uid)
          .get();

      if (!userProfileSnapshot.exists) {
        setState(() {
          _errorMessage = 'No Notifications regarding Job. Profile Not Set';
          _isLoading = false;
        });
        return;
      }

      _userProfile = _sanitizeDocument(userProfileSnapshot.data()!);
      _userProfile!['id'] = userProfileSnapshot.id;

      // Now match with jobs
      await _matchUserWithJobs();

      // Check which jobs the user has already applied for
      await _checkAppliedJobs();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading profile: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _checkAppliedJobs() async {
    try {
      final appliedJobsQuery = await _firestore
          .collection('AppliedCandidates')
          .where('candidateId', isEqualTo: _auth.currentUser!.uid)
          .get();

      Map<String, String> newStatus = {};
      for (var doc in appliedJobsQuery.docs) {
        final data = doc.data();
        if (data.containsKey('jobId')) {
          newStatus[data['jobId']] = 'applied';
        }
      }

      setState(() {
        _applicationStatus = newStatus;
      });
    } catch (e) {
      print('Error checking applied jobs: $e');
    }
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

  Future<void> _matchUserWithJobs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _matchedJobs = [];
    });

    try {
      if (_userProfile == null) {
        setState(() {
          _errorMessage = 'User profile not loaded';
          _isLoading = false;
        });
        return;
      }

      Map<String, dynamic> candidate = _userProfile!;

      // Get all jobs
      final jobsQuery = await _firestore.collection('JobsPosted').get();

      if (jobsQuery.docs.isEmpty) {
        setState(() {
          _errorMessage = 'No jobs found';
          _isLoading = false;
        });
        return;
      }

      // Track processed job IDs to avoid duplicates
      final Set<String> processedJobIds = {};

      // Match user with each job
      for (var jobDoc in jobsQuery.docs) {
        Map<String, dynamic> job = _sanitizeDocument(jobDoc.data());
        job['id'] = jobDoc.id;

        // Skip if job already processed
        if (processedJobIds.contains(job['id'])) continue;

        try {
          final response =
              await _matchingService.matchCandidate(job, candidate);

          if (response is Map<String, dynamic> &&
              response.containsKey('match_score')) {
            final rawMatchScore = response['match_score'] as num? ?? 0.0;
            final double matchScore = rawMatchScore > 1
                ? rawMatchScore / 100.0
                : rawMatchScore.toDouble();

            if (matchScore > 0.4) {
              // Check if notification already exists
              final existingNotifs = await _firestore
                  .collection('Notifications')
                  .where('jobId', isEqualTo: job['id'])
                  .where('candidateId', isEqualTo: candidate['id'])
                  .limit(1)
                  .get();

              String notificationId;
              if (existingNotifs.docs.isEmpty) {
                // Save new notification
                notificationId =
                    await _saveNotification(job, candidate, matchScore);

                // Send push notification
                await _jobNotificationService.sendJobMatchNotification(
                  candidateId: candidate['id'],
                  job: job,
                  matchScore: matchScore,
                );
              } else {
                notificationId = existingNotifs.docs.first.id;
              }

              // Only add to matched jobs if not already present
              if (!_matchedJobs.any((m) => m['job']['id'] == job['id'])) {
                _matchedJobs.add({
                  'notificationId': notificationId,
                  'job': job,
                  'matchScore': matchScore,
                });
                processedJobIds.add(job['id']);
              }
            }
          }
        } catch (e) {
          print('Error matching job ${job['title']}: $e');
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

  Future<String> _saveNotification(Map<String, dynamic> job,
      Map<String, dynamic> candidate, double matchScore) async {
    try {
      final docRef = await _firestore.collection('Notifications').add({
        'candidateId': candidate['id'],
        'jobId': job['id'],
        'jobTitle': job['title'],
        'companyName': job['company_name'],
        'matchScore': matchScore,
        'message': 'This job matches your profile. You should apply for it!',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'recruiterId': job['recruiterId'] ?? '',
      });

      await _jobNotificationService.saveNotificationToFirestore(
        userId: candidate['id'],
        title: 'New Job Match',
        body:
            'A job at ${job['company_name']} matches your profile with a ${(matchScore * 100).round()}% match score.',
        type: 'job_match',
        data: {
          'jobId': job['id'],
          'jobTitle': job['title'],
          'companyName': job['company_name'],
          'matchScore': matchScore,
        },
      );

      return docRef.id;
    } catch (e) {
      print('Failed to save notification: $e');
      return '';
    }
  }

  Future<void> _deleteNotification(String notificationId, int index) async {
    try {
      await _firestore.collection('Notifications').doc(notificationId).delete();
      setState(() {
        _matchedJobs.removeAt(index);
      });
    } catch (e) {
      print('Error deleting notification: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete notification: $e')),
      );
    }
  }

  Future<void> _applyForJob(Map<String, dynamic> job, int index) async {
    if (_applicationStatus[job['id']] == 'applied') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You have already applied for this job')),
      );
      return;
    }

    try {
      setState(() {
        // Show loading state on the button
        _applicationStatus[job['id']] = 'loading'; // loading state
      });

      final user = _auth.currentUser;
      if (user == null || _userProfile == null) {
        throw Exception('User not authenticated or profile not loaded');
      }

      // Check if already applied
      final existingApplication = await _firestore
          .collection('AppliedCandidates')
          .where('candidateId', isEqualTo: user.uid)
          .where('jobId', isEqualTo: job['id'])
          .limit(1)
          .get();

      if (existingApplication.docs.isNotEmpty) {
        setState(() {
          _applicationStatus[job['id']] = 'applied';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You have already applied for this job')),
        );
        return;
      }

      // Extract required fields from user profile
      final userProfile = _userProfile!;

      // Create application document
      await _firestore.collection('AppliedCandidates').add({
        'applicantEmail': user.email ?? '',
        'applicantName': userProfile['name'] ?? '',
        'applicantPhone': userProfile['phone'] ?? '',
        'applicantProfileUrl': userProfile['profilePicUrl'] ?? '',
        'applicantResumeUrl': userProfile['resumeUrl'] ?? '',
        'appliedAt': FieldValue.serverTimestamp(),
        'candidateId': user.uid,
        'companyName': job['company_name'] ?? '',
        'educations': userProfile['educations'] ?? [],
        'jobId': job['id'],
        'jobTitle': job['title'] ?? '',
        'languages': userProfile['languages'] ?? [],
        'softSkills': userProfile['softSkills'] ?? [],
        'status': 'pending',
        'technicalSkills': userProfile['technicalSkills'] ?? [],
      });

      setState(() {
        _applicationStatus[job['id']] = 'applied';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Successfully applied for the job')),
      );
    } catch (e) {
      print('Error applying for job: $e');
      setState(() {
        _applicationStatus[job['id']] = 'error';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to apply for job: $e')),
      );
    }
  }

  void _setupFirebaseListeners() {
    // Listen for new jobs
    _firestore.collection('JobsPosted').snapshots().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          _processNewJob(change.doc);
        }
      }
    });
  }

  Future<void> _processNewJob(DocumentSnapshot jobDoc) async {
    try {
      Map<String, dynamic> job =
          _sanitizeDocument(jobDoc.data() as Map<String, dynamic>);
      job['id'] = jobDoc.id;

      // Skip if job already in matched jobs
      if (_matchedJobs.any((m) => m['job']['id'] == job['id'])) return;

      // Skip if user profile not loaded
      if (_userProfile == null) return;

      Map<String, dynamic> candidate = _userProfile!;

      // Match with new job
      final response = await _matchingService.matchCandidate(job, candidate);

      if (response is Map<String, dynamic> &&
          response.containsKey('match_score')) {
        final rawMatchScore = response['match_score'] as num? ?? 0.0;
        final double matchScore = rawMatchScore > 1
            ? rawMatchScore / 100.0
            : rawMatchScore.toDouble();

        if (matchScore > 0.4) {
          final existingNotifs = await _firestore
              .collection('Notifications')
              .where('jobId', isEqualTo: job['id'])
              .where('candidateId', isEqualTo: candidate['id'])
              .limit(1)
              .get();

          String notificationId;
          if (existingNotifs.docs.isEmpty) {
            notificationId =
                await _saveNotification(job, candidate, matchScore);

            await _jobNotificationService.sendJobMatchNotification(
              candidateId: candidate['id'],
              job: job,
              matchScore: matchScore,
            );
          } else {
            notificationId = existingNotifs.docs.first.id;
          }

          // Only add if not already present
          if (!_matchedJobs.any((m) => m['job']['id'] == job['id'])) {
            setState(() {
              _matchedJobs.add({
                'notificationId': notificationId,
                'job': job,
                'matchScore': matchScore,
              });
            });
          }
        }
      }
    } catch (e) {
      print('Error processing new job: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : _buildNotificationsView(),
    );
  }

  Widget _buildNotificationsView() {
    return _matchedJobs.isEmpty
        ? const Center(child: Text('No matching jobs found'))
        : ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: _matchedJobs.length,
            itemBuilder: (context, index) {
              final match = _matchedJobs[index];
              final job = match['job'] as Map<String, dynamic>;
              final matchScore = match['matchScore'] as double;
              final notificationId = match['notificationId'] as String;
              final bool alreadyApplied =
                  _applicationStatus[job['id']] == 'applied';
              final bool isLoading = _applicationStatus[job['id']] == 'loading';
              final jobId = job['id'];

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  job['title'] ?? 'Untitled Job',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Company: ${job['company_name'] ?? 'Unknown'}',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Match Score: ${(matchScore * 100).round()}%',
                                  style: const TextStyle(color: Colors.blue),
                                ),
                                if (job['description'] != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Description: ${job['description']}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 14),
                                  ),
                                ],
                                if (job['requirements'] != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Requirements: ${job['requirements']}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 14),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () =>
                                _deleteNotification(notificationId, index),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ElevatedButton(
                            onPressed: alreadyApplied || isLoading
                                ? null
                                : () => _applyForJob(job, index),
                            child: isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    alreadyApplied ? 'Applied' : 'Apply Now'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: alreadyApplied
                                  ? Colors.grey
                                  : Theme.of(context).primaryColor,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              MaterialPageRoute(
                                  builder: (context) =>
                                      JobDetailsViewScreen(jobId: jobId));
                            },
                            child: const Text('View Details'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
  }
}
