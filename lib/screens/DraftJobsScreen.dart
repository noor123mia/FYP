import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_2/screens/JobDescriptionScreen.dart';
import 'package:flutter_application_2/screens/JobDetailsEditScreen.dart';
import 'package:flutter_application_2/screens/PostedJobsScreen.dart';
import 'package:intl/intl.dart';

class DraftJobsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    String recruiterId = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Draft Jobs",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => PostedJobsScreen()),
              );
            },
            icon: const Icon(Icons.work_outline, color: Colors.white),
            label: const Text(
              "Posted Jobs",
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF0D9488),
        elevation: 4,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => JobDescriptionScreen()),
          );
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF0F4F8), Color(0xFFE6EEF5)],
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('JobsInDraft')
              .where('recruiterId', isEqualTo: recruiterId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF0D9488),
                ),
              );
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.description_outlined,
                      size: 70,
                      color: const Color(0xFF1E3A8A).withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "No Draft Jobs Available",
                      style: TextStyle(
                        fontSize: 18,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                var jobDoc = snapshot.data!.docs[index];
                var job = jobDoc.data() as Map<String, dynamic>;
                String jobId = jobDoc.id;

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
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
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Color(0xFFEF4444),
                                size: 24,
                              ),
                              onPressed: () {
                                _showDeleteConfirmation(context, jobId);
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(
                              Icons.business,
                              size: 16,
                              color: Color(0xFF64748B),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              job['company_name'] ?? 'Unknown Company',
                              style: const TextStyle(
                                fontSize: 15,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 16,
                              color: Color(0xFF64748B),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              job['location'] ?? 'Unknown Location',
                              style: const TextStyle(
                                fontSize: 15,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2FE),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                job['job_type'] ?? 'Not Specified',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF0369A1),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                size: 16,
                                color: Color(0xFFDC2626),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "Apply by: ${job['last_date_to_apply'] is Timestamp ? DateFormat('dd/MM/yyyy').format((job['last_date_to_apply'] as Timestamp).toDate()) : job['last_date_to_apply'] ?? 'Not Set'}",
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFDC2626),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(
                                  Icons.visibility_outlined,
                                  size: 18,
                                ),
                                label: const Text("Edit Job"),
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: const Color(0xFF1E3A8A),
                                  backgroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: const BorderSide(
                                      color: Color(0xFF1E3A8A),
                                      width: 1,
                                    ),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          JobDetailsEditScreen(jobId: jobId),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(
                                  Icons.send_outlined,
                                  size: 18,
                                ),
                                label: const Text("Post Job"),
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  backgroundColor: const Color(0xFF0D9488),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: () {
                                  _postJob(context, job, jobId, recruiterId);
                                },
                              ),
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
        ),
      ),
    );
  }

  Future<void> _postJob(BuildContext context, Map<String, dynamic> job,
      String jobId, String recruiterId) async {
    try {
      DateTime now = DateTime.now();
      DateTime lastDateToApply;
      var lastDateField = job['last_date_to_apply'];

      if (lastDateField is Timestamp) {
        lastDateToApply = lastDateField.toDate();
      } else if (lastDateField is String) {
        lastDateToApply = DateFormat("dd/MM/yyyy").parse(lastDateField);
      } else {
        throw Exception("Invalid last_date_to_apply format.");
      }

      if (lastDateToApply.isBefore(now)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text("Please modify the last date to apply before posting."),
            backgroundColor: Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
        JobDetailsEditScreen(jobId: jobId);
        return;
      }

      await FirebaseFirestore.instance.collection('JobsPosted').doc(jobId).set({
        'title': job['title'],
        'company_name': job['company_name'],
        'location': job['location'],
        'job_type': job['job_type'],
        'contract_type': job['contract_type'],
        'salary_range': job['salary_range'],
        'description': job['description'],
        'last_date_to_apply': Timestamp.fromDate(lastDateToApply),
        'posted_on': Timestamp.fromDate(now),
        'recruiterId': recruiterId,
      });

      await FirebaseFirestore.instance
          .collection('JobsInDraft')
          .doc(jobId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Job posted successfully!"),
          backgroundColor: Color(0xFF0D9488),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("An error occurred while posting the job."),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

void _showDeleteConfirmation(BuildContext context, String jobId) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Delete Job', style: TextStyle(color: Color(0xFF1E3A8A))),
        content: Text('Are you sure you want to delete this job?'),
        actions: [
          TextButton(
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text('Delete'),
            onPressed: () {
              _deleteJob(context, jobId);
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}

void _deleteJob(BuildContext context, String jobId) async {
  try {
    await FirebaseFirestore.instance
        .collection('JobsInDraft')
        .doc(jobId)
        .delete();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Job deleted successfully!"),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Failed to delete job: ${e.toString()}"),
        backgroundColor: Colors.red,
      ),
    );
  }
}
