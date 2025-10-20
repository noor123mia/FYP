import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

class AppliedJobsScreen extends StatefulWidget {
  const AppliedJobsScreen({Key? key}) : super(key: key);

  @override
  State<AppliedJobsScreen> createState() => _AppliedJobsScreenState();
}

class _AppliedJobsScreenState extends State<AppliedJobsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Selected job for detailed view
  Map<String, dynamic>? selectedJob;
  String? selectedJobStatus;

  @override
  Widget build(BuildContext context) {
    String? currentUserId = _auth.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Applied Jobs'),
        backgroundColor: Color(0xFF1E3A8A),
        elevation: 0,
      ),
      body: currentUserId == null
          ? const Center(child: Text('Please log in to view your applied jobs'))
          : Column(
              children: [
                Expanded(
                  flex: selectedJob != null ? 1 : 2,
                  child: _buildAppliedJobsList(currentUserId),
                ),
                if (selectedJob != null)
                  Expanded(
                    flex: 2,
                    child: _buildJobDetailsCard(),
                  ),
              ],
            ),
    );
  }

  Widget _buildAppliedJobsList(String currentUserId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('AppliedCandidates')
          .where('candidateId', isEqualTo: currentUserId)
          .snapshots(),
      builder: (context, appliedSnapshot) {
        if (appliedSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (appliedSnapshot.hasError) {
          return Center(child: Text('Error: ${appliedSnapshot.error}'));
        }

        if (!appliedSnapshot.hasData || appliedSnapshot.data!.docs.isEmpty) {
          return const Center(
              child: Text('You haven\'t applied to any jobs yet.'));
        }

        // Create a list of Future for each job
        List<Future<Map<String, dynamic>>> jobFutures = [];
        Map<String, String> jobStatusMap = {};

        for (var doc in appliedSnapshot.data!.docs) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          String jobId = data['jobId'] ?? '';
          String status = data['status'] ?? 'Pending';

          if (jobId.isNotEmpty) {
            jobStatusMap[jobId] = status;
            jobFutures.add(_firestore
                .collection('JobsPosted')
                .doc(jobId)
                .get()
                .then((jobDoc) {
              if (jobDoc.exists) {
                Map<String, dynamic> jobData =
                    jobDoc.data() as Map<String, dynamic>;
                jobData['id'] =
                    jobDoc.id; // Add the document ID to the job data
                return jobData;
              }
              return <String, dynamic>{};
            }));
          }
        }

        return FutureBuilder<List<Map<String, dynamic>>>(
          future: Future.wait(jobFutures),
          builder: (context, jobsSnapshot) {
            if (jobsSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (jobsSnapshot.hasError) {
              return Center(child: Text('Error: ${jobsSnapshot.error}'));
            }

            List<Map<String, dynamic>> jobs =
                jobsSnapshot.data!.where((job) => job.isNotEmpty).toList();

            if (jobs.isEmpty) {
              return const Center(child: Text('No job details found.'));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: jobs.length,
              itemBuilder: (context, index) {
                Map<String, dynamic> job = jobs[index];
                String jobId = job['id'] ?? '';
                String status = jobStatusMap[jobId] ?? 'Pending';

                return Card(
                  elevation: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: _getStatusColor(status),
                      width: 2,
                    ),
                  ),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        selectedJob = job;
                        selectedJobStatus = status;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  job['title'] ?? 'Unknown Position',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Chip(
                                label: Text(
                                  status,
                                  style: TextStyle(
                                    color: status == 'Rejected'
                                        ? Colors.white
                                        : Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                backgroundColor: _getStatusColor(status),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            job['company_name'] ?? 'Unknown Company',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.location_on, size: 16),
                              const SizedBox(width: 4),
                              Text(job['location'] ?? 'Remote'),
                              const SizedBox(width: 16),
                              const Icon(Icons.work, size: 16),
                              const SizedBox(width: 4),
                              Text(job['job_type'] ?? 'Full-time'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.attach_money, size: 16),
                              const SizedBox(width: 4),
                              Text(job['salary_range'] ?? 'Negotiable'),
                              const Spacer(),
                              if (job['last_date_to_apply'] != null)
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today, size: 16),
                                    const SizedBox(width: 4),
                                    Text(_formatTimestamp(
                                        job['last_date_to_apply'])),
                                  ],
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildJobDetailsCard() {
    if (selectedJob == null) return Container();

    // Parse description based on its type
    dynamic description = selectedJob!['description'];
    Map<String, dynamic> descriptionMap = {};

    if (description is String) {
      try {
        if (description.startsWith('{')) {
          // Parse JSON string
          final parsedJson = jsonDecode(description);
          if (parsedJson is Map) {
            // Extract the "description" field if it exists
            final nestedDescription = parsedJson['description'];
            if (nestedDescription is Map) {
              descriptionMap = Map<String, dynamic>.from(nestedDescription);
            } else {
              // If no valid "description" field, treat the string as position_summary
              descriptionMap = {'position_summary': description};
            }
          } else {
            // If parsed JSON is not a Map, treat the string as position_summary
            descriptionMap = {'position_summary': description};
          }
        } else {
          // Non-JSON string, treat as position_summary
          descriptionMap = {'position_summary': description};
        }
      } catch (e) {
        // If parsing fails, treat the string as position_summary
        descriptionMap = {'position_summary': description};
      }
    } else if (description is Map) {
      // If input is a Map, check for nested "description" field
      final nestedDescription = description['description'];
      if (nestedDescription is Map) {
        descriptionMap = Map<String, dynamic>.from(nestedDescription);
      } else {
        // If no nested "description", use the entire map
        descriptionMap = Map<String, dynamic>.from(description);
      }
    }

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedJob!['title'] ?? 'Unknown Position',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        selectedJob!['company_name'] ?? 'Unknown Company',
                        style: const TextStyle(
                          fontSize: 18,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(
                    selectedJobStatus ?? 'Pending',
                    style: TextStyle(
                      color: selectedJobStatus == 'Rejected'
                          ? Colors.white
                          : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  backgroundColor:
                      _getStatusColor(selectedJobStatus ?? 'Pending'),
                ),
              ],
            ),
            const Divider(height: 32),

            // Job info row
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _buildInfoChip(
                    Icons.location_on, selectedJob!['location'] ?? 'Remote'),
                _buildInfoChip(
                    Icons.work, selectedJob!['job_type'] ?? 'Full-time'),
                _buildInfoChip(Icons.business,
                    selectedJob!['contract_type'] ?? 'Permanent'),
                _buildInfoChip(Icons.attach_money,
                    selectedJob!['salary_range'] ?? 'Negotiable'),
              ],
            ),

            const SizedBox(height: 16),
            _buildDateInfo(),

            const Divider(height: 32),

            // Position Summary
            if (descriptionMap.containsKey('position_summary') &&
                descriptionMap['position_summary'] != null)
              _buildSectionWithTitle(
                'Position Summary',
                descriptionMap['position_summary'],
              ),

            // Responsibilities
            if (descriptionMap.containsKey('responsibilities') &&
                descriptionMap['responsibilities'] != null)
              _buildListSection(
                'Responsibilities',
                descriptionMap['responsibilities'],
              ),

            // Required Skills
            if (descriptionMap.containsKey('required_skills') &&
                descriptionMap['required_skills'] != null)
              _buildListSection(
                'Required Skills',
                descriptionMap['required_skills'],
              ),

            // Preferred Skills
            if (descriptionMap.containsKey('preferred_skills') &&
                descriptionMap['preferred_skills'] != null)
              _buildListSection(
                'Preferred Skills',
                descriptionMap['preferred_skills'],
              ),

            // Technical Skills
            if (descriptionMap.containsKey('technical_skills') &&
                descriptionMap['technical_skills'] != null)
              _buildTechnicalSkills(descriptionMap['technical_skills']),

            // What We Offer
            if (descriptionMap.containsKey('what_we_offer') &&
                descriptionMap['what_we_offer'] != null)
              _buildListSection(
                'What We Offer',
                descriptionMap['what_we_offer'],
              ),

            const SizedBox(height: 16),

            // Close button
            Center(
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    selectedJob = null;
                    selectedJobStatus = null;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: const Text(
                  'Close Details',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: Color(0xFF1E3A8A),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: Color(0xFF1E3A8A),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateInfo() {
    final postedDate = selectedJob!['posted_on'] != null
        ? _formatTimestamp(selectedJob!['posted_on'])
        : 'Unknown';

    final lastDate = selectedJob!['last_date_to_apply'] != null
        ? _formatTimestamp(selectedJob!['last_date_to_apply'])
        : 'Unknown';

    return Row(
      children: [
        Expanded(
          child: _buildInfoItem(
            'Posted On',
            postedDate,
            Icons.calendar_today,
          ),
        ),
        Expanded(
          child: _buildInfoItem(
            'Apply Before',
            lastDate,
            Icons.timer,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem(String title, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.blue),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionWithTitle(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildListSection(String title, dynamic items) {
    List<dynamic> itemsList = [];

    if (items is List) {
      itemsList = items;
    } else if (items is String) {
      itemsList = [items];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 8),
        ...itemsList.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Text(
                      item.toString(),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            )),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildTechnicalSkills(Map<String, dynamic> techSkills) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Technical Skills',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 12),
        ...techSkills.entries.map((entry) {
          String category = entry.key;
          List<dynamic> skills =
              entry.value is List ? entry.value : [entry.value];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: skills
                    .map((skill) => Chip(
                          label: Text(skill.toString()),
                          backgroundColor: Colors.grey.shade200,
                        ))
                    .toList(),
              ),
              const SizedBox(height: 12),
            ],
          );
        }).toList(),
        const SizedBox(height: 8),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
      case 'hired':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'interviewed':
      case 'shortlisted':
        return Colors.amber;
      case 'pending':
      default:
        return const Color.fromARGB(255, 26, 135, 224);
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';

    DateTime dateTime;
    if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    } else if (timestamp is String) {
      try {
        dateTime = DateTime.parse(timestamp);
      } catch (e) {
        return timestamp;
      }
    } else {
      return 'N/A';
    }

    return DateFormat('MMM dd, yyyy').format(dateTime);
  }
}

// Helper extension to parse JSON safely

extension StringExtension on String {
  dynamic tryJsonDecode() {
    try {
      return jsonDecode(this);
    } catch (e) {
      return this;
    }
  }
}
