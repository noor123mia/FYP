import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_2/services/matching_service.dart'; // Assuming MatchingService is in this file/path

class CandidateMatchDetailScreen extends StatefulWidget {
  const CandidateMatchDetailScreen({
    Key? key,
  }) : super(key: key);

  @override
  State<CandidateMatchDetailScreen> createState() =>
      _CandidateMatchDetailScreenState();
}

class _CandidateMatchDetailScreenState
    extends State<CandidateMatchDetailScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _allMatches =
      []; // Will hold all top matches per job

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final MatchingService _matchingService;

  @override
  void initState() {
    super.initState();
    _matchingService = MatchingService(); // Initialize service
    _performMatching();
  }

  // Helper to sanitize document data (from previous code)
  Map<String, dynamic> _sanitizeDocument(Map<String, dynamic> data) {
    // Remove or handle any unwanted fields if needed
    return Map<String, dynamic>.from(data);
  }

  Future<void> _performMatching() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Step 1: Get all jobs
      final jobsQuery = await _firestore.collection('JobsPosted').get();

      if (jobsQuery.docs.isEmpty) {
        setState(() {
          _errorMessage = 'No jobs found';
          _isLoading = false;
        });
        return;
      }

      // Step 2: Get all candidates
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

      // Step 3: Process each job and match with candidates, collect top match per job
      List<Map<String, dynamic>> allTopMatches = [];

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

            // Sort matches by match_score descending
            matches.sort((a, b) =>
                (b['match_score'] as num).compareTo(a['match_score'] as num));

            // Find the highest score match for this job and add to list
            if (matches.isNotEmpty) {
              final bestForJob = matches.first;
              bestForJob['job'] = job; // Attach job info
              allTopMatches.add(bestForJob);
            }
          }
        } catch (e) {
          // Handle per-job error
          print('Error matching for job ${job['id']}: $e');
        }
      }

      // Step 4: Sort all top matches globally by score
      allTopMatches.sort((a, b) =>
          (b['match_score'] as num).compareTo(a['match_score'] as num));

      setState(() {
        _allMatches = allTopMatches;
        _isLoading = false;
      });

      if (_allMatches.isEmpty) {
        setState(() {
          _errorMessage = 'No matches found';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error performing matching: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Candidate Matches"),
          backgroundColor: const Color(0xFF1E3A8A),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(_errorMessage!, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _performMatching,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text(
          "All Candidate Matches (${_allMatches.length})",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _allMatches.length,
        itemBuilder: (context, index) {
          final match = _allMatches[index];
          final candidateData = match['candidate'] as Map<String, dynamic>;
          final jobData = match['job'] as Map<String, dynamic>?;

          // Properly handle match score
          final rawMatchScore = match['match_score'];
          final double matchScore = rawMatchScore is num
              ? (rawMatchScore > 1
                  ? rawMatchScore / 100
                  : rawMatchScore.toDouble())
              : 0.0;

          // Handle category scores properly
          final categoryScores =
              match['category_scores'] as Map<String, dynamic>? ?? {};

          // Normalize category scores to ensure they're in the 0-1 range
          double normalizeScore(dynamic score) {
            if (score == null) return 0.0;
            double numScore = score is num ? score.toDouble() : 0.0;
            return numScore > 1 ? numScore / 100 : numScore;
          }

          final skillsScore = normalizeScore(categoryScores['required_skills']);
          final experienceScore =
              normalizeScore(categoryScores['work_experience']);
          final educationScore =
              normalizeScore(categoryScores['qualification']);
          final techScore = normalizeScore(categoryScores['tech_stack']);

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Candidate and Job Header
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: candidateData['profilePicUrl'] != null
                            ? NetworkImage(candidateData['profilePicUrl'])
                            : null,
                        child: candidateData['profilePicUrl'] == null
                            ? const Icon(Icons.person,
                                size: 30, color: Colors.grey)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              candidateData['name'] ?? 'No Name',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              jobData != null
                                  ? jobData['title'] ?? 'No Job Title'
                                  : 'No Job',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Overall Score Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: matchScore >= 0.7
                              ? Colors.green[100]
                              : matchScore >= 0.5
                                  ? Colors.orange[100]
                                  : Colors.red[100],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: matchScore >= 0.7
                                ? Colors.green
                                : matchScore >= 0.5
                                    ? Colors.orange
                                    : Colors.red,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${(matchScore * 100).round()}%',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: matchScore >= 0.7
                                    ? Colors.green[800]
                                    : matchScore >= 0.5
                                        ? Colors.orange[800]
                                        : Colors.red[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Match Breakdown
                  const Text(
                    'Match Breakdown',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildScoreItem(context, 'Skills', skillsScore, 0.5),
                  _buildScoreItem(context, 'Experience', experienceScore, 0.3),
                  _buildScoreItem(context, 'Education', educationScore, 0.2),

                  const SizedBox(height: 16),

                  // Quick Skills Peek
                  if (match['matching_skills'] != null &&
                      (match['matching_skills'] as List).isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Matching Skills',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: (match['matching_skills'] as List)
                              .map((skill) => Chip(
                                    label: Text(skill.toString()),
                                    backgroundColor: Colors.green[100],
                                  ))
                              .toList(),
                        ),
                      ],
                    ),

                  const SizedBox(height: 16),

                  // Action buttons for this candidate
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Contact functionality not implemented')),
                            );
                          },
                          icon: const Icon(Icons.email),
                          label: const Text('Contact'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 40),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'View Full Details not implemented')),
                            );
                          },
                          icon: const Icon(Icons.visibility),
                          label: const Text('View Details'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E3A8A),
                            minimumSize: const Size(0, 40),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildScoreItem(
      BuildContext context, String title, double score, double weight) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title),
              Text(
                '${(score * 100).round()}% (Weight: ${(weight * 100).round()}%)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearPercentIndicator(
            percent: score,
            lineHeight: 10,
            progressColor: score >= 0.7
                ? Colors.green
                : score >= 0.5
                    ? Colors.orange
                    : Colors.red,
            backgroundColor: Colors.grey[200],
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
