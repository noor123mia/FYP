// applied_candidates_matching_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_application_2/services/matching_service2.dart';

class AppliedCandidatesMatchingScreen extends StatefulWidget {
  final Map<String, dynamic> job;
  final List<Map<String, dynamic>> appliedCandidates;

  const AppliedCandidatesMatchingScreen({
    Key? key,
    required this.job,
    required this.appliedCandidates,
  }) : super(key: key);

  @override
  _AppliedCandidatesMatchingScreenState createState() =>
      _AppliedCandidatesMatchingScreenState();
}

class _AppliedCandidatesMatchingScreenState
    extends State<AppliedCandidatesMatchingScreen>
    with TickerProviderStateMixin {
  final MatchingService _matchingService = MatchingService();

  List<Map<String, dynamic>> matchResults = [];
  List<Map<String, dynamic>> duplicateGroups = [];
  bool isLoading = false;
  bool showingDuplicates = false;
  String? errorMessage;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _performMatching();
    _detectDuplicates();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _performMatching() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final result = await _matchingService.matchAppliedCandidatesWithJob(
        widget.job,
        widget.appliedCandidates,
      );

      if (result.containsKey('error')) {
        setState(() {
          errorMessage = result['error'];
        });
      } else {
        setState(() {
          matchResults =
              List<Map<String, dynamic>>.from(result['matches'] ?? []);
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error performing matching: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _detectDuplicates() async {
    try {
      final result = await _matchingService.detectDuplicateCandidates(
        widget.appliedCandidates,
        similarityThreshold: 0.85,
      );

      if (!result.containsKey('error')) {
        setState(() {
          duplicateGroups =
              List<Map<String, dynamic>>.from(result['duplicate_groups'] ?? []);
        });
      }
    } catch (e) {
      print('Error detecting duplicates: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Applied Candidates Matching'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Match Results', icon: Icon(Icons.assessment)),
            Tab(text: 'Duplicates', icon: Icon(Icons.content_copy)),
            Tab(text: 'Job Details', icon: Icon(Icons.work)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMatchResultsTab(),
          _buildDuplicatesTab(),
          _buildJobDetailsTab(),
        ],
      ),
    );
  }

  Widget _buildMatchResultsTab() {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Analyzing candidates...'),
          ],
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text('Error: $errorMessage'),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _performMatching,
              child: Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (matchResults.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No matching results found'),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(16),
          color: Colors.blue.shade50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatCard('Total Candidates',
                  widget.appliedCandidates.length.toString(), Icons.people),
              _buildStatCard('Matched', matchResults.length.toString(),
                  Icons.check_circle),
              _buildStatCard('Avg Score',
                  _calculateAverageScore().toStringAsFixed(1), Icons.star),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: matchResults.length,
            itemBuilder: (context, index) {
              final match = matchResults[index];
              return _buildMatchCard(match);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDuplicatesTab() {
    if (duplicateGroups.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.verified, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text('No duplicate candidates found'),
            SizedBox(height: 8),
            Text('All candidates appear to be unique',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(16),
          color: Colors.orange.shade50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatCard('Duplicate Groups',
                  duplicateGroups.length.toString(), Icons.content_copy),
              _buildStatCard('Total Duplicates',
                  _getTotalDuplicates().toString(), Icons.warning),
              _buildStatCard('Unique Candidates',
                  _getUniqueCandidates().toString(), Icons.person),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: duplicateGroups.length,
            itemBuilder: (context, index) {
              final group = duplicateGroups[index];
              return _buildDuplicateGroupCard(group, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildJobDetailsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.job['title'] ?? 'Job Title',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.business, size: 16, color: Colors.grey),
                      SizedBox(width: 8),
                      Text(widget.job['company_name'] ?? 'Company Name'),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: Colors.grey),
                      SizedBox(width: 8),
                      Text(widget.job['location'] ?? 'Location'),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.work, size: 16, color: Colors.grey),
                      SizedBox(width: 8),
                      Text(widget.job['job_type'] ?? 'Job Type'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (widget.job['description'] != null) ...[
            SizedBox(height: 16),
            _buildJobSection('Position Summary',
                widget.job['description']['position_summary']),
            _buildJobSection('Required Skills',
                widget.job['description']['required_skills']),
            _buildJobSection('Preferred Skills',
                widget.job['description']['preferred_skills']),
            _buildJobSection('Responsibilities',
                widget.job['description']['responsibilities']),
            if (widget.job['description']['technical_skills'] != null)
              _buildTechnicalSkillsSection(
                  widget.job['description']['technical_skills']),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Colors.blue),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(
          title,
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildMatchCard(Map<String, dynamic> match) {
    final candidateData = match['candidate_data'];
    final matchScore = (match['match_score'] as num?)?.toDouble() ?? 0.0;
    final categoryScores =
        match['category_scores'] as Map<String, dynamic>? ?? {};

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _getScoreColor(matchScore),
          child: Text(
            '${matchScore.round()}%',
            style: TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          candidateData['applicantName'] ?? 'Unknown Candidate',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(candidateData['applicantEmail'] ?? ''),
            Text('Status: ${match['status'] ?? 'Pending'}'),
          ],
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Category Scores:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                ...categoryScores.entries.map((entry) {
                  final score = (entry.value as num?)?.toDouble() ?? 0.0;
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_formatCategoryName(entry.key)),
                        Row(
                          children: [
                            Container(
                              width: 100,
                              height: 6,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: score / 100,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: _getScoreColor(score),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text('${score.round()}%'),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
                if (match['matching_skills'] != null &&
                    match['matching_skills'].isNotEmpty) ...[
                  SizedBox(height: 16),
                  Text('Matching Skills:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children:
                        (match['matching_skills'] as List).map<Widget>((skill) {
                      return Chip(
                        label: Text(skill.toString(),
                            style: TextStyle(fontSize: 12)),
                        backgroundColor: Colors.blue.shade100,
                      );
                    }).toList(),
                  ),
                ],
                if (candidateData['technicalSkills'] != null) ...[
                  SizedBox(height: 16),
                  Text('Technical Skills:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: (candidateData['technicalSkills'] as List)
                        .map<Widget>((skill) {
                      return Chip(
                        label: Text(skill.toString(),
                            style: TextStyle(fontSize: 12)),
                        backgroundColor: Colors.green.shade100,
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDuplicateGroupCard(Map<String, dynamic> group, int groupIndex) {
    final candidates = group['candidates'] as List? ?? [];
    final primaryCandidate = group['primary_candidate'];

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Colors.orange,
          child: Text(
            '${candidates.length}',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text('Duplicate Group ${groupIndex + 1}'),
        subtitle: Text('${candidates.length} similar candidates'),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Primary Candidate:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                _buildCandidateInfo(primaryCandidate, isPrimary: true),
                SizedBox(height: 16),
                Text('Similar Candidates:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                ...candidates
                    .where((c) => c != primaryCandidate)
                    .map((candidate) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: _buildCandidateInfo(candidate),
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCandidateInfo(Map<String, dynamic> candidate,
      {bool isPrimary = false}) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isPrimary ? Colors.blue.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: isPrimary ? Border.all(color: Colors.blue.shade200) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            candidate['applicantName'] ?? 'Unknown',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 4),
          Text('Email: ${candidate['applicantEmail'] ?? 'N/A'}'),
          Text('Phone: ${candidate['applicantPhone'] ?? 'N/A'}'),
          Text('Location: ${candidate['location'] ?? 'N/A'}'),
        ],
      ),
    );
  }

  Widget _buildJobSection(String title, dynamic content) {
    if (content == null) return SizedBox.shrink();

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            if (content is List)
              ...content
                  .map<Widget>((item) => Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('• '),
                            Expanded(child: Text(item.toString())),
                          ],
                        ),
                      ))
                  .toList()
            else
              Text(content.toString()),
          ],
        ),
      ),
    );
  }

  Widget _buildTechnicalSkillsSection(Map<String, dynamic> technicalSkills) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Technical Skills',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            ...technicalSkills.entries.map((entry) {
              return Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.key,
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: (entry.value as List).map<Widget>((skill) {
                        return Chip(
                          label: Text(skill.toString(),
                              style: TextStyle(fontSize: 12)),
                          backgroundColor: Colors.blue.shade100,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    if (score >= 40) return Colors.yellow.shade700;
    return Colors.red;
  }

  String _formatCategoryName(String category) {
    return category
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.substring(0, 1).toUpperCase() + word.substring(1))
        .join(' ');
  }

  double _calculateAverageScore() {
    if (matchResults.isEmpty) return 0.0;

    double total = 0.0;
    for (final match in matchResults) {
      total += (match['match_score'] as num?)?.toDouble() ?? 0.0;
    }
    return total / matchResults.length;
  }

  int _getTotalDuplicates() {
    int total = 0;
    for (final group in duplicateGroups) {
      final candidates = group['candidates'] as List? ?? [];
      total += candidates.length;
    }
    return total;
  }

  int _getUniqueCandidates() {
    return widget.appliedCandidates.length -
        (_getTotalDuplicates() - duplicateGroups.length);
  }
}
