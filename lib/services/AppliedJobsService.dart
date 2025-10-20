import 'package:cloud_firestore/cloud_firestore.dart';
import 'models.dart';

class AppliedJobsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all applied jobs for a candidate
  Stream<List<AppliedJob>> getAppliedJobs(String candidateId) {
    return _firestore
        .collection('AppliedCandidates')
        .where('candidateId', isEqualTo: candidateId)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => AppliedJob.fromFirestore(doc)).toList());
  }

  // Get job details by job ID
  Future<Job?> getJobById(String jobId) async {
    try {
      final docSnapshot =
          await _firestore.collection('JobsPosted').doc(jobId).get();

      if (docSnapshot.exists) {
        return Job.fromFirestore(docSnapshot);
      } else {
        return null;
      }
    } catch (e) {
      print('Error fetching job details: $e');
      return null;
    }
  }

  // Get all jobs applied by a candidate
  Future<List<Map<String, dynamic>>> getAppliedJobsWithDetails(
      String candidateId) async {
    try {
      // Get all applied jobs for the candidate
      final appliedJobsSnapshot = await _firestore
          .collection('AppliedCandidates')
          .where('candidateId', isEqualTo: candidateId)
          .get();

      List<Map<String, dynamic>> appliedJobsWithDetails = [];

      // For each applied job, get the job details
      for (var doc in appliedJobsSnapshot.docs) {
        final appliedJob = AppliedJob.fromFirestore(doc);
        final jobDetails = await getJobById(appliedJob.jobId);

        if (jobDetails != null) {
          appliedJobsWithDetails.add({
            'appliedJob': appliedJob,
            'jobDetails': jobDetails,
          });
        }
      }

      return appliedJobsWithDetails;
    } catch (e) {
      print('Error getting applied jobs with details: $e');
      return [];
    }
  }
}
