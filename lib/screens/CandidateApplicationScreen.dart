import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_2/screens/JobDetailsViewScreen.dart';
import 'package:flutter_application_2/screens/ApplicationFormScreen.dart';

class CandidateApplicationScreen extends StatefulWidget {
  @override
  _CandidateApplicationScreenState createState() =>
      _CandidateApplicationScreenState();
}

class _CandidateApplicationScreenState
    extends State<CandidateApplicationScreen> {
  String? searchQuery;
  String? selectedFilter;
  final List<String> filterOptions = [
    'All',
    'Full-time',
    'Part-time',
    'Contract',
    'Remote'
  ];
  bool isLoading = false;
  String? sortBy = 'relevance';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text(
          "Available Jobs",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        backgroundColor: Color(0xFF1E3A8A),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list_rounded, color: Colors.white),
            onPressed: () {
              _showFilterDialog();
            },
          ),
          IconButton(
            icon: Icon(Icons.sort, color: Colors.white),
            onPressed: () {
              _showSortOptions();
            },
          )
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  searchQuery = value.isEmpty ? null : value.toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search by Title, Company or Location',
                prefixIcon: Icon(Icons.search, color: Color(0xFF1E3A8A)),
                filled: true,
                fillColor: Color(0xFFF3F4F6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    EdgeInsets.symmetric(vertical: 0, horizontal: 20),
              ),
            ),
          ),

          // Selected Filter Chip (if any)
          if (selectedFilter != null && selectedFilter != 'All')
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  Chip(
                    label: Text(selectedFilter!),
                    backgroundColor: Color(0xFFE0E7FF),
                    labelStyle: TextStyle(color: Color(0xFF1E3A8A)),
                    deleteIconColor: Color(0xFF1E3A8A),
                    onDeleted: () {
                      setState(() {
                        selectedFilter = 'All';
                      });
                    },
                  ),
                  SizedBox(width: 8),
                  if (sortBy != null && sortBy != 'newest')
                    Chip(
                      label:
                          Text(sortBy == 'salary' ? 'Salary' : 'Most Relevant'),
                      backgroundColor: Color(0xFFE0E7FF),
                      labelStyle: TextStyle(color: Color(0xFF1E3A8A)),
                      deleteIconColor: Color(0xFF1E3A8A),
                      onDeleted: () {
                        setState(() {
                          sortBy = 'newest';
                        });
                      },
                    ),
                ],
              ),
            ),

          // Job Listings
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('JobsPosted')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF1E3A8A)),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState(
                      icon: Icons.work_off_rounded,
                      title: "No Jobs Available",
                      message: "Check back later for new opportunities");
                }

                // Filter jobs based on search query and selected filter
                var filteredDocs = snapshot.data!.docs.where((doc) {
                  var job = doc.data() as Map<String, dynamic>;

                  // Apply search filter
                  bool matchesSearch = searchQuery == null ||
                      job['title']
                              ?.toString()
                              .toLowerCase()
                              .contains(searchQuery!) ==
                          true ||
                      job['company_name']
                              ?.toString()
                              .toLowerCase()
                              .contains(searchQuery!) ==
                          true ||
                      job['location']
                              ?.toString()
                              .toLowerCase()
                              .contains(searchQuery!) ==
                          true;

                  // Apply job type filter
                  bool matchesJobType = selectedFilter == null ||
                      selectedFilter == 'All' ||
                      job['job_type'] == selectedFilter;

                  return matchesSearch && matchesJobType;
                }).toList();

                // Sort jobs based on selected sort option
                if (sortBy == 'salary') {
                  filteredDocs.sort((a, b) {
                    var jobA = a.data() as Map<String, dynamic>;
                    var jobB = b.data() as Map<String, dynamic>;

                    String salaryA = jobA['salary_range'] ?? '0';
                    String salaryB = jobB['salary_range'] ?? '0';

                    // Extract numeric values from salary strings (assuming format like "$50,000-$70,000")
                    int valueA = _extractHighestSalary(salaryA);
                    int valueB = _extractHighestSalary(salaryB);

                    return valueB.compareTo(valueA); // Sort by highest salary
                  });
                } else if (sortBy == 'relevance') {
                  // Sort by relevance logic (could be based on skills match, location, etc.)
                  // For now, just sort by job title relevance to search query
                  if (searchQuery != null && searchQuery!.isNotEmpty) {
                    filteredDocs.sort((a, b) {
                      var jobA = a.data() as Map<String, dynamic>;
                      var jobB = b.data() as Map<String, dynamic>;

                      bool titleAContains = jobA['title']
                              ?.toString()
                              .toLowerCase()
                              .contains(searchQuery!) ??
                          false;
                      bool titleBContains = jobB['title']
                              ?.toString()
                              .toLowerCase()
                              .contains(searchQuery!) ??
                          false;

                      if (titleAContains && !titleBContains) return -1;
                      if (!titleAContains && titleBContains) return 1;
                      return 0;
                    });
                  }
                } else {
                  // Default sort by newest
                  filteredDocs.sort((a, b) {
                    var jobA = a.data() as Map<String, dynamic>;
                    var jobB = b.data() as Map<String, dynamic>;

                    var timeA = jobA['createdAt'] is Timestamp
                        ? (jobA['createdAt'] as Timestamp).toDate()
                        : DateTime.now();
                    var timeB = jobB['createdAt'] is Timestamp
                        ? (jobB['createdAt'] as Timestamp).toDate()
                        : DateTime.now();

                    return timeB.compareTo(timeA);
                  });
                }

                if (filteredDocs.isEmpty) {
                  return _buildEmptyState(
                      icon: Icons.search_off_rounded,
                      title: "No Matching Jobs Found",
                      message: "Try adjusting your search criteria");
                }

                return ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    var job =
                        filteredDocs[index].data() as Map<String, dynamic>;
                    var jobId = filteredDocs[index].id;

                    return _buildJobCard(context, job, jobId);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
      {required IconData icon,
      required String title,
      required String message}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey[400]),
          SizedBox(height: 20),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 10),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  int _extractHighestSalary(String salaryRange) {
    // Handle common salary formats
    if (salaryRange.isEmpty) return 0;

    // Extract all numeric parts from the string
    RegExp regExp = RegExp(r'[0-9,]+');
    var matches = regExp.allMatches(salaryRange);

    if (matches.isEmpty) return 0;

    // Find the highest value in case of a range
    int highestValue = 0;
    for (var match in matches) {
      String numStr = match.group(0)!.replaceAll(',', '');
      int value = int.tryParse(numStr) ?? 0;
      if (value > highestValue) highestValue = value;
    }

    return highestValue;
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Container(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Sort Jobs By",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildSortOption(
                    title: 'Newest First',
                    icon: Icons.access_time,
                    isSelected: sortBy == 'newest',
                    onTap: () {
                      this.setState(() {
                        sortBy = 'newest';
                      });
                      Navigator.pop(context);
                    },
                  ),
                  _buildSortOption(
                    title: 'Highest Salary',
                    icon: Icons.attach_money,
                    isSelected: sortBy == 'salary',
                    onTap: () {
                      this.setState(() {
                        sortBy = 'salary';
                      });
                      Navigator.pop(context);
                    },
                  ),
                  _buildSortOption(
                    title: 'Most Relevant',
                    icon: Icons.trending_up,
                    isSelected: sortBy == 'relevance',
                    onTap: () {
                      this.setState(() {
                        sortBy = 'relevance';
                      });
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSortOption({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? Color(0xFF1E3A8A) : Color(0xFFE0E7FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : Color(0xFF1E3A8A),
                size: 20,
              ),
            ),
            SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                color: isSelected ? Color(0xFF1E3A8A) : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            Spacer(),
            if (isSelected)
              Icon(Icons.check_circle, color: Color(0xFF1E3A8A), size: 20),
          ],
        ),
      ),
    );
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Container(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Filter Jobs",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          this.setState(() {
                            selectedFilter = 'All';
                          });
                        },
                        child: Text(
                          "Clear All",
                          style: TextStyle(
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Text(
                    "Job Type",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: filterOptions.map((filter) {
                      bool isSelected = selectedFilter == filter;
                      return ChoiceChip(
                        label: Text(filter),
                        selected: isSelected,
                        selectedColor: Color(0xFFBFDBFE),
                        backgroundColor: Colors.grey[200],
                        labelStyle: TextStyle(
                          color: isSelected ? Color(0xFF1E3A8A) : Colors.black,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (selected) {
                          setState(() {
                            this.selectedFilter = filter;
                          });
                          this.setState(() {});
                        },
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      // Filter is already applied via setState
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF1E3A8A),
                      minimumSize: Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Apply Filter',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildJobCard(
      BuildContext context, Map<String, dynamic> job, String jobId) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 7,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Job Title and Company Logo
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Color(0xFFE0E7FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      job['company_name']?.substring(0, 1) ?? 'C',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job['title'] ?? 'No Title',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A8A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Text(
                        job['company_name'] ?? 'Unknown Company',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Color(0xFFE0E7FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getPostedTimeAgo(job['posted_on']),
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF3151A6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Location row
            _buildDetailRow(
              icon: Icons.location_on_rounded,
              label: "Location",
              text: job['location'] ?? 'Location Not Specified',
            ),
            SizedBox(height: 8),

            // Job Type row
            _buildDetailRow(
              icon: Icons.work_outline_rounded,
              label: "Job Type",
              text: job['job_type'] ?? 'Not Specified',
            ),
            SizedBox(height: 8),

            // Contract Type row
            _buildDetailRow(
              icon: Icons.description_outlined,
              label: "Contract",
              text: job['contract_type'] ?? 'Not Specified',
            ),
            SizedBox(height: 8),

            // Salary row
            _buildDetailRow(
              icon: Icons.attach_money_rounded,
              label: "Salary",
              text: job['salary_range'] ?? 'Salary Not Defined',
            ),

            if (job['skills'] != null && (job['skills'] as List).isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 12),
                  Text(
                    "Required Skills",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,

                    // Show "+X more" if there are more than 3 skills
                    children: [
                      ...(job['skills'] as List).take(3).map<Widget>((skill) {
                        return Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Text(
                            skill.toString(),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                        );
                      }).toList(),
                      if ((job['skills'] as List).length > 3)
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Text(
                            "+${(job['skills'] as List).length - 3} more",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),

            SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => JobDetailsViewScreen(
                                  jobId: jobId,
                                )),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFF3F4F6),
                      foregroundColor: Color(0xFF1E3A8A),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                      padding: EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      'View Details',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isLoading
                        ? null
                        : () => _handleApplyJob(context, jobId, job),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF1E3A8A),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                              strokeWidth: 2,
                            ))
                        : Text(
                            'Apply Now',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleApplyJob(
      BuildContext context, String jobId, Map<String, dynamic> jobData) async {
    if (isLoading) return;

    setState(() {
      isLoading = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        _showErrorDialog('You need to log in to apply for jobs.');
        return;
      }

      final String jobSeekerId = currentUser.uid;
      final String jobTitle = jobData['title'] ?? 'Unknown Job';
      final String companyName = jobData['company_name'] ?? 'Unknown Company';

      // Check if already applied
      final appliedSnapshot = await FirebaseFirestore.instance
          .collection('AppliedCandidates')
          .where('jobId', isEqualTo: jobId)
          .where('candidateId', isEqualTo: jobSeekerId)
          .get();

      if (appliedSnapshot.docs.isNotEmpty) {
        _showInfoDialog('Application Already Submitted',
            'You have already applied for this job. You can check the status in your applications page.');
        return;
      }

      // Check if profile exists with required fields
      final profileSnapshot = await FirebaseFirestore.instance
          .collection('JobSeekersProfiles')
          .doc(jobSeekerId)
          .get();

      if (!profileSnapshot.exists) {
        // Profile doesn't exist, show application form
        _navigateToApplicationForm(jobId, jobTitle, companyName);
        return;
      }

      final profileData = profileSnapshot.data() as Map<String, dynamic>;

      // Check for mandatory fields
      final List<String> mandatoryFields = [
        'educations',
        'name',
        'phone',
        'profilePicUrl',
        'resumeUrl',
        'softSkills',
        'technicalSkills',
        'languages',
        'workExperiences',
      ];

      List<String> missingFields = [];

      for (String field in mandatoryFields) {
        if (profileData[field] == null ||
            (profileData[field] is String &&
                (profileData[field] as String).isEmpty) ||
            (profileData[field] is List &&
                (profileData[field] as List).isEmpty)) {
          missingFields.add(field);
        }
      }

      if (missingFields.isNotEmpty) {
        // Missing required profile fields, show application form
        _navigateToApplicationForm(jobId, jobTitle, companyName);
        return;
      }

      // Profile is complete, proceed with application
      await FirebaseFirestore.instance.collection('AppliedCandidates').add({
        'jobId': jobId,
        'candidateId': jobSeekerId,
        'appliedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        'jobTitle': jobTitle,
        'companyName': companyName,
        'applicantName': profileData['name'],
        'applicantEmail': currentUser.email,
        'applicantResumeUrl': profileData['resumeUrl'],
        'applicantProfileUrl': profileData['profilePicUrl'],
        'applicantPhone': profileData['phone'],
        'educations': profileData['educations'],
        'languages': profileData['languages'],
        'technicalSkills': profileData['technicalSkills'],
        'softSkills': profileData['softSkills'],
        'workExperiences': profileData['workExperiences'],
      });

      _showSuccessDialog('Application Successfully Submitted!',
          'Your application for $jobTitle at $companyName has been submitted. You can check the status in your applications page.');
    } catch (e) {
      _showErrorDialog('Failed to apply: ${e.toString()}');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _navigateToApplicationForm(
      String jobId, String jobTitle, String companyName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ApplicationFormScreen(
          jobId: jobId,
          jobTitle: jobTitle,
          companyName: companyName,
          onApplicationSubmitted: () {
            setState(() {
              isLoading = false;
            });
            _showSuccessDialog('Application Successfully Submitted!',
                'Your application for $jobTitle at $companyName has been submitted. You can check the status in your applications page.');
          },
        ),
      ),
    );
  }

  void _showSuccessDialog(String title, String message) {
    setState(() {
      isLoading = false;
    });

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Column(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 48),
              SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A8A),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          content: Text(
            message,
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          actions: [
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF1E3A8A),
                  minimumSize: Size(200, 45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('OK', style: TextStyle(fontSize: 16)),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    setState(() {
      isLoading = false;
    });

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Column(
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 48),
              SizedBox(height: 16),
              Text(
                'Error',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[700],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          content: Text(
            message,
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          actions: [
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF1E3A8A),
                  minimumSize: Size(200, 45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('OK', style: TextStyle(fontSize: 16)),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _showInfoDialog(String title, String message) {
    setState(() {
      isLoading = false;
    });

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Column(
            children: [
              Icon(Icons.info_outline, color: Color(0xFF1E3A8A), size: 48),
              SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A8A),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          content: Text(
            message,
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          actions: [
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF1E3A8A),
                  minimumSize: Size(200, 45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('OK', style: TextStyle(fontSize: 16)),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

Widget _buildDetailRow(
    {required IconData icon, required String text, required String label}) {
  return Row(
    children: [
      Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Color(0xFF3151A6), size: 18),
      ),
      SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              text,
              style: TextStyle(
                color: Color(0xFF1F2937),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    ],
  );
}

String _getPostedTimeAgo(dynamic timestamp) {
  if (timestamp == null) return 'Recently';

  DateTime postedDate;

  if (timestamp is Timestamp) {
    postedDate = timestamp.toDate();
  } else if (timestamp is String) {
    try {
      postedDate = DateTime.parse(timestamp);
    } catch (e) {
      return 'Recently';
    }
  } else {
    return 'Recently';
  }

  final difference = DateTime.now().difference(postedDate);

  if (difference.inDays > 30) {
    return '${(difference.inDays / 30).floor()} month${(difference.inDays / 30).floor() == 1 ? '' : 's'} ago';
  } else if (difference.inDays > 0) {
    return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
  } else if (difference.inHours > 0) {
    return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
  } else if (difference.inMinutes > 0) {
    return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
  } else {
    return 'Just now';
  }
}
