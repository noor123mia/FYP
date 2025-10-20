import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer' as developer; // For debugPrint
import '../services/matching_service.dart'; // Adjust path to your MatchingService

class CandidateMatchScreen extends StatefulWidget {
  @override
  _CandidateMatchScreenState createState() => _CandidateMatchScreenState();
}

class _CandidateMatchScreenState extends State<CandidateMatchScreen> {
  String? searchQuery;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String recruiterId = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          "Job Listings",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('JobsPosted')
                  .where('recruiterId', isEqualTo: recruiterId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF1E3A8A)),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.sentiment_dissatisfied_outlined,
                            size: 100, color: Colors.grey[400]),
                        const SizedBox(height: 20),
                        Text(
                          "No Jobs Posted Yet",
                          style: TextStyle(
                            fontSize: 22,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Filter jobs based on search query
                var filteredDocs = snapshot.data!.docs.where((doc) {
                  var job = doc.data() as Map<String, dynamic>;
                  if (searchQuery == null || searchQuery!.isEmpty) return true;

                  return (job['title']?.toString().toLowerCase() ?? '')
                      .contains(searchQuery!);
                }).toList();

                return ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    var job =
                        filteredDocs[index].data() as Map<String, dynamic>;
                    var jobId = filteredDocs[index].id;

                    return _buildJobCardWithCandidateCount(context, job, jobId);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobCardWithCandidateCount(
      BuildContext context, Map<String, dynamic> job, String jobId) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E3A8A), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    job['title'] ?? 'No Title',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildDetailRow(
              icon: Icons.business_rounded,
              text:
                  '   ${job['company_name'] ?? 'Unknown Company'}     • ${job['location'] ?? 'Location Not Specified'}',
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              icon: Icons.work_rounded,
              text:
                  '   ${job['job_type'] ?? 'Not Specified'}     • ${job['contract_type'] ?? 'Not Specified'}',
            ),
            const SizedBox(
                height: 24), // Increased spacing to push candidates lower

            // Candidate count stream builder, centered
            Center(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('AppliedCandidates')
                    .where('jobId', isEqualTo: jobId)
                    .snapshots(),
                builder: (context, snapshot) {
                  int candidatesCount = 0;
                  if (snapshot.hasData) {
                    candidatesCount = snapshot.data!.docs.length;
                  }

                  return InkWell(
                    onTap: () {
                      if (candidatesCount > 0) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AppliedCandidatesScreen(
                              jobId: jobId,
                              jobTitle: job['title'] ?? 'Unknown Job',
                            ),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                "No candidates have applied for this job yet."),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(0xFF1E3A8A), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.people, color: Color(0xFF1E3A8A)),
                          const SizedBox(width: 8),
                          Text(
                            "Applied Candidates: $candidatesCount",
                            style: const TextStyle(
                              color: Color(0xFF1E3A8A),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({required IconData icon, required String text}) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF1E3A8A), size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.grey[800],
              fontSize: 16,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// New screen to display the list of applied candidates with match scores
class AppliedCandidatesScreen extends StatefulWidget {
  final String jobId;
  final String jobTitle;

  const AppliedCandidatesScreen({
    Key? key,
    required this.jobId,
    required this.jobTitle,
  }) : super(key: key);

  @override
  State<AppliedCandidatesScreen> createState() =>
      _AppliedCandidatesScreenState();
}

class _AppliedCandidatesScreenState extends State<AppliedCandidatesScreen> {
  List<dynamic> matches = [];
  bool _isLoading = true;
  String selectedFilter = 'all';
  final TextEditingController _topNController = TextEditingController();
  final Set<String> selectedApplications = <String>{};

  @override
  void initState() {
    super.initState();
    _loadMatches();
  }

  @override
  void dispose() {
    _topNController.dispose();
    super.dispose();
  }

  Future<void> _loadMatches() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Fetch job data
      DocumentSnapshot jobDoc = await FirebaseFirestore.instance
          .collection('JobsPosted')
          .doc(widget.jobId)
          .get();
      if (!jobDoc.exists) {
        throw Exception('Job not found');
      }
      Map<String, dynamic> job = jobDoc.data() as Map<String, dynamic>;

      // Fetch applied candidates
      QuerySnapshot candSnap = await FirebaseFirestore.instance
          .collection('AppliedCandidates')
          .where('jobId', isEqualTo: widget.jobId)
          .get();

      List<Map<String, dynamic>> candidates = [];
      for (var doc in candSnap.docs) {
        var cand = doc.data() as Map<String, dynamic>;
        var candidateMap = {
          'id': cand['candidateId'],
          'name': cand['applicantName'],
          'email': cand['applicantEmail'], // Add for completeness
          'technicalSkills': cand['technicalSkills'] ?? [],
          'softSkills': cand['softSkills'] ?? [],
          'educations': cand['educations'] ?? [],
          'workExperiences': cand['workExperiences'] ?? [],
          'languages': cand['languages'] ?? [],
          'summary': '', // No summary in applied data
          'applicantResumeUrl': cand['applicantResumeUrl'],
          'status': cand['status'],
          'appliedAt': cand['appliedAt'],
          'applicantPhone': cand['applicantPhone'],
          'applicationId': doc.id, // Add application ID for status update
        };
        candidates.add(candidateMap);
      }

      if (candidates.isEmpty) {
        setState(() {
          matches = [];
          _isLoading = false;
        });
        return;
      }

      // Use MatchingService for batch matching
      final service = MatchingService();
      final result = await service.batchMatchCandidates(job, candidates);

      if (result['matches'] != null && (result['matches'] as List).isNotEmpty) {
        setState(() {
          matches = result['matches'];
          matches.sort((a, b) =>
              (b['match_score'] as num).compareTo(a['match_score'] as num));
          _isLoading = false;
        });
      } else {
        throw Exception(result['error'] ?? 'No matches found');
      }
    } catch (e) {
      developer.log('Error loading matches: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load match scores: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        matches = [];
        _isLoading = false;
      });
    }
  }

  void _selectTopN() {
    int? n = int.tryParse(_topNController.text);
    if (n == null || n <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid number.')),
      );
      return;
    }
    setState(() {
      selectedApplications.clear();
      var tempFiltered = matches.where((match) {
        var cand = Map<String, dynamic>.from(match['candidate']);
        var status = cand['status'] ?? 'pending';
        return selectedFilter == 'all' || status == selectedFilter;
      }).toList();
      tempFiltered.sort((a, b) =>
          (b['match_score'] as num).compareTo(a['match_score'] as num));
      for (int i = 0; i < n && i < tempFiltered.length; i++) {
        var appId = Map<String, dynamic>.from(
                tempFiltered[i]['candidate'])['applicationId'] ??
            '';
        if (appId.isNotEmpty) selectedApplications.add(appId);
      }
    });
    if (selectedApplications.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Selected top ${selectedApplications.length} candidates.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No candidates to select.')),
      );
    }
  }

  void _showBulkStatusUpdateDialog(BuildContext context) {
    String newStatus = 'shortlisted';
    final List<String> statusOptions = [
      'pending',
      'shortlisted',
      'interviewed',
      'accepted',
      'rejected'
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Bulk Update Status',
          style: TextStyle(color: Color(0xFF1E3A8A)),
        ),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: statusOptions
                .map((status) => RadioListTile<String>(
                      title: Text(_capitalizeStatus(status)),
                      value: status,
                      groupValue: newStatus,
                      activeColor: const Color(0xFF1E3A8A),
                      onChanged: (value) => setState(() => newStatus = value!),
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A)),
            onPressed: () {
              Navigator.pop(context);
              _bulkUpdateApplicationStatus(context, newStatus);
            },
            child:
                const Text('Update All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _bulkUpdateApplicationStatus(
      BuildContext context, String newStatus) async {
    List<Future> updates = [];
    for (String appId in selectedApplications) {
      updates.add(
        FirebaseFirestore.instance
            .collection('AppliedCandidates')
            .doc(appId)
            .update({'status': newStatus}),
      );
    }
    try {
      await Future.wait(updates);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Bulk status updated successfully!"),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {
        selectedApplications.clear();
      });
      // Refresh
      _loadMatches();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to bulk update: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<dynamic> _getFilteredMatches() {
    var filtered = matches.where((match) {
      String status =
          Map<String, dynamic>.from(match['candidate'])['status'] ?? 'pending';
      return selectedFilter == 'all' || status == selectedFilter;
    }).toList();
    filtered.sort(
        (a, b) => (b['match_score'] as num).compareTo(a['match_score'] as num));
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    List<dynamic> filteredMatches = _getFilteredMatches();
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text(
          "Candidates for ${widget.jobTitle}",
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
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E3A8A)),
              ),
            )
          : matches.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_off_outlined,
                          size: 100, color: Colors.grey[400]),
                      const SizedBox(height: 20),
                      Text(
                        "No Candidates Yet",
                        style: TextStyle(
                          fontSize: 22,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Filter and Selection Container
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Filter Dropdown
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: selectedFilter,
                                  decoration: const InputDecoration(
                                    labelText: 'Filter by Status',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: [
                                    const DropdownMenuItem<String>(
                                      value: 'all',
                                      child: Text('All Statuses'),
                                    ),
                                    ...[
                                      'pending',
                                      'shortlisted',
                                      'interviewed',
                                      'accepted',
                                      'rejected'
                                    ].map(
                                      (String value) =>
                                          DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(_capitalizeStatus(value)),
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      selectedFilter = value!;
                                      selectedApplications
                                          .clear(); // Clear selection on filter change
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Top N Selection
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _topNController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Enter number for Top N',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.trending_up),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton.icon(
                                onPressed: _selectTopN,
                                icon: const Icon(Icons.select_all),
                                label: const Text('Select Top'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E3A8A),
                                ),
                              ),
                              if (selectedApplications.isNotEmpty) ...[
                                const SizedBox(width: 10),
                                ElevatedButton.icon(
                                  onPressed: () =>
                                      _showBulkStatusUpdateDialog(context),
                                  icon: const Icon(Icons.update),
                                  label: Text(
                                      'Bulk Update (${selectedApplications.length})'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    // List or Empty Message
                    if (filteredMatches.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Center(
                          child: Text(
                            selectedFilter == 'all'
                                ? 'No candidates yet.'
                                : 'No candidates with status ${_capitalizeStatus(selectedFilter)}.',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredMatches.length,
                          itemBuilder: (context, index) {
                            var match = filteredMatches[index];
                            var candidateData =
                                Map<String, dynamic>.from(match['candidate']);
                            String applicationId =
                                candidateData['applicationId'] ?? '';
                            return _buildCandidateCard(
                              context,
                              candidateData,
                              match,
                              applicationId,
                            );
                          },
                        ),
                      ),
                  ],
                ),
    );
  }

  Widget _buildCandidateCard(
    BuildContext context,
    Map<String, dynamic> candidateData,
    Map<String, dynamic> matchData,
    String applicationId,
  ) {
    String name = candidateData['name'] ?? 'Unknown';
    String email = candidateData['email'] ?? 'No Email';
    String phone = candidateData['applicantPhone'] ?? 'No Phone';
    String appliedDate = _formatDate(candidateData['appliedAt']);
    String status = candidateData['status'] ?? 'pending';
    String resume = candidateData['applicantResumeUrl'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
          color: _getStatusColor(status).withOpacity(0.5),
          width: 1,
        ),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row with Checkbox
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF1E3A8A),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(status).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _capitalizeStatus(status),
                              style: TextStyle(
                                color: _getStatusColor(status),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Applied on $appliedDate",
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Checkbox(
                  value: selectedApplications.contains(applicationId),
                  onChanged: (value) {
                    setState(() {
                      if (value ?? false) {
                        selectedApplications.add(applicationId);
                      } else {
                        selectedApplications.remove(applicationId);
                      }
                    });
                  },
                  activeColor: const Color(0xFF1E3A8A),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Match Score Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade50, Colors.blue.shade50],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Overall Match Score: ${matchData['match_score'].toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: matchData['match_score'] / 100,
                    backgroundColor: Colors.grey[300],
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Category Scores:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ...(matchData['category_scores'] as Map)
                      .entries
                      .map((e) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(e.key.replaceAll('_', ' ').toUpperCase()),
                                Text('${e.value}%'),
                              ],
                            ),
                          ))
                      .toList(),
                  if (matchData['matching_skills'] != null &&
                      (matchData['matching_skills'] as List).isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        const Text('Matching Skills:'),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: (matchData['matching_skills'] as List)
                              .map((s) => Chip(
                                    label: Text(s.toString()),
                                    backgroundColor: Colors.blue.shade100,
                                  ))
                              .toList(),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.email, email),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.phone, phone),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.visibility),
                    label: const Text('View Details'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1E3A8A),
                      side: const BorderSide(color: Color(0xFF1E3A8A)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      _showCandidateDetailsModal(context, candidateData, null);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Update Status'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      _showStatusUpdateDialog(context, applicationId, status);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF1E3A8A), size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.grey[800],
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return 'Not Specified';

    try {
      if (dateValue is Timestamp) {
        return DateFormat('dd MMM yyyy').format(dateValue.toDate());
      }
      if (dateValue is String) {
        return DateFormat('dd MMM yyyy').format(DateTime.parse(dateValue));
      }
      return 'Invalid Date';
    } catch (e) {
      return 'Invalid Date';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'interviewed':
        return Colors.blue;
      case 'shortlisted':
        return Colors.amber[700]!;
      default:
        return Colors.grey;
    }
  }

  String _capitalizeStatus(String status) {
    if (status.isEmpty) return 'Pending';
    return status[0].toUpperCase() + status.substring(1);
  }
// For Timestamp handling
// For opening resume URL
// For Supabase

// Assume Supabase is initialized elsewhere
  final _supabase = Supabase.instance.client;

// Custom widget to build a detail field
  Widget _buildDetailField(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A8A),
            ),
          ),
          const SizedBox(height: 4),
          if (label == "Education" && value is List)
            // Handle educations (array of maps)
            Column(
              children: (value as List).asMap().entries.map((entry) {
                final education = entry.value as Map<String, dynamic>;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: const Color(0xFF1E3A8A), width: 1),
                    ),
                    child: Text(
                      "${education['degree'] ?? 'Unknown Degree'} in ${education['fieldOfStudy'] ?? education['field'] ?? 'Unknown Field'} from ${education['institution'] ?? education['school'] ?? 'Unknown School'}, ${education['startYear'] ?? 'N/A'} - ${education['endYear'] ?? education['endDate'] ?? 'N/A'}",
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                );
              }).toList(),
            )
          else if (value is List)
            // Handle technicalSkills and softSkills (array of strings)
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: (value as List).map((skill) {
                return Chip(
                  label: Text(
                    skill.toString(),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                  backgroundColor: const Color(0xFFEFF6FF),
                  side: const BorderSide(color: Color(0xFF1E3A8A), width: 1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                );
              }).toList(),
            )
          else
            // Handle simple fields (e.g., Name, Email, Cover Letter)
            Text(
              value?.toString() ?? 'N/A',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
        ],
      ),
    );
  }

// Updated modal function
  void _showCandidateDetailsModal(
    BuildContext context,
    Map<String, dynamic> candidateData,
    Map<String, dynamic>? userData,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Candidate Details",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    _buildDetailField("Name",
                        candidateData['name'] ?? 'Unknown'), // Fixed key
                    _buildDetailField("Email",
                        candidateData['email'] ?? 'No Email'), // Fixed key
                    _buildDetailField(
                        "Phone", candidateData['applicantPhone'] ?? 'No Phone'),
                    _buildDetailField(
                        "Applied On", _formatDate(candidateData['appliedAt'])),
                    _buildDetailField(
                        "Status",
                        _capitalizeStatus(
                            candidateData['status'] ?? 'pending')),
                    if (candidateData['technicalSkills'] != null)
                      _buildDetailField(
                          "Technical Skills", candidateData['technicalSkills']),
                    if (candidateData['softSkills'] != null)
                      _buildDetailField(
                          "Soft Skills", candidateData['softSkills']),
                    if (candidateData['educations'] != null)
                      _buildDetailField(
                          "Education", candidateData['educations']),
                    if (candidateData['applicantResumeUrl'] != null &&
                        candidateData['applicantResumeUrl']
                            .toString()
                            .isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.file_download),
                            label: const Text('View Resume'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E3A8A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () async {
                              final resumeUrl =
                                  candidateData['applicantResumeUrl']
                                      as String?;
                              if (resumeUrl == null || resumeUrl.isEmpty) {
                                developer.log('Resume URL is null or empty');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('No resume URL available'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }
                              String?
                                  publicUrl; // Ye declare karo try ke bahar, taaki catch mein accessible ho
                              try {
                                developer.log('Resume URL: $resumeUrl');
                                String filePath = resumeUrl;
                                if (resumeUrl.contains(
                                    '/storage/v1/object/public/smartrecruitfiles/')) {
                                  filePath = resumeUrl
                                      .split(
                                          '/storage/v1/object/public/smartrecruitfiles/')
                                      .last;
                                }
                                developer.log('File Path: $filePath');
                                publicUrl = _supabase.storage
                                    .from('smartrecruitfiles')
                                    .getPublicUrl(
                                        filePath); // Assign karo variable mein
                                developer.log(
                                    'Public URL: $publicUrl'); // Ye log check karo – URL sahi hai ya nahi?
                                final uri = Uri.parse(
                                    publicUrl!); // ! use karo kyunki ab defined hai
// canLaunchUrl check HATAYO – directly launch try karo
                                await launchUrl(
                                  uri,
                                  mode: LaunchMode
                                      .externalApplication, // Ya try karo LaunchMode.platformDefault agar external na chale
                                );
                              } on PlatformException catch (e) {
                                // Specific exception catch karo url_launcher ka
                                developer.log('Failed to open resume: $e');
// publicUrl fallback ke liye resumeUrl use karo agar null hai
                                final urlToCopy = publicUrl ?? resumeUrl ?? '';
                                await Clipboard.setData(
                                    ClipboardData(text: urlToCopy));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Cannot open resume. Please ensure a browser or PDF viewer is installed. URL copied to clipboard.'),
                                    backgroundColor: Colors.orange,
                                    duration: const Duration(seconds: 5),
                                  ),
                                );
                              } catch (e) {
                                developer.log('Unexpected error: $e');
// Same fallback
                                final urlToCopy = publicUrl ?? resumeUrl ?? '';
                                await Clipboard.setData(
                                    ClipboardData(text: urlToCopy));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to open resume: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                            // onPressed: () async {
                            //   final resumeUrl =
                            //       candidateData['applicantResumeUrl']
                            //           as String?;
                            //   if (resumeUrl == null || resumeUrl.isEmpty) {
                            //     developer.log('Resume URL is null or empty');
                            //     ScaffoldMessenger.of(context).showSnackBar(
                            //       const SnackBar(
                            //         content: Text('No resume URL available'),
                            //         backgroundColor: Colors.red,
                            //       ),
                            //     );
                            //     return;
                            //   }

                            //   try {
                            //     developer.log('Resume URL: $resumeUrl');
                            //     String filePath = resumeUrl;
                            //     if (resumeUrl.contains(
                            //         '/storage/v1/object/public/smartrecruitfiles/')) {
                            //       filePath = resumeUrl
                            //           .split(
                            //               '/storage/v1/object/public/smartrecruitfiles/')
                            //           .last;
                            //     }
                            //     developer.log('File Path: $filePath');

                            //     final publicUrl = _supabase.storage
                            //         .from('smartrecruitfiles')
                            //         .getPublicUrl(filePath);
                            //     developer.log('Public URL: $publicUrl');

                            //     final uri = Uri.parse(publicUrl);
                            //     if (!await canLaunchUrl(uri)) {
                            //       await Clipboard.setData(
                            //           ClipboardData(text: publicUrl));
                            //       ScaffoldMessenger.of(context).showSnackBar(
                            //         const SnackBar(
                            //           content: Text(
                            //               'Cannot open resume. Please ensure a browser or PDF viewer (e.g., Chrome, Adobe Acrobat) is installed. URL copied to clipboard.'),
                            //           backgroundColor: Colors.orange,
                            //           duration: Duration(seconds: 5),
                            //         ),
                            //       );
                            //       return;
                            //     }

                            //     await launchUrl(
                            //       uri,
                            //       mode: LaunchMode.externalApplication,
                            //     );
                            //   } catch (e) {
                            //     developer.log('Failed to open resume: $e');
                            //     await Clipboard.setData(
                            //         ClipboardData(text: resumeUrl));
                            //     ScaffoldMessenger.of(context).showSnackBar(
                            //       SnackBar(
                            //         content: Text('Failed to open resume: $e'),
                            //         backgroundColor: Colors.red,
                            //       ),
                            //     );
                            //   }
                            // },
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showStatusUpdateDialog(
      BuildContext context, String applicationId, String currentStatus) {
    String newStatus = currentStatus;
    final List<String> statusOptions = [
      'pending',
      'shortlisted',
      'interviewed',
      'accepted',
      'rejected',
    ];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Update Application Status',
              style: TextStyle(color: Color(0xFF1E3A8A))),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: statusOptions.map((status) {
                  return RadioListTile<String>(
                    title: Text(_capitalizeStatus(status)),
                    value: status,
                    groupValue: newStatus,
                    activeColor: const Color(0xFF1E3A8A),
                    onChanged: (value) {
                      setState(() {
                        newStatus = value!;
                      });
                    },
                  );
                }).toList(),
              );
            },
          ),
          actions: [
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child:
                  const Text('Update', style: TextStyle(color: Colors.white)),
              onPressed: () {
                _updateApplicationStatus(context, applicationId, newStatus);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _updateApplicationStatus(
      BuildContext context, String applicationId, String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('AppliedCandidates')
          .doc(applicationId)
          .update({'status': newStatus});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Application status updated successfully!"),
          backgroundColor: Colors.green,
        ),
      );

      // Remove from selected if present
      if (selectedApplications.contains(applicationId)) {
        setState(() {
          selectedApplications.remove(applicationId);
        });
      }

      // Optionally refresh matches after status update
      _loadMatches();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to update status: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
