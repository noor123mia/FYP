// TODO Implement this library.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

// Model class for Applied Job
class AppliedJob {
  final String id;
  final String candidateId;
  final String jobId;
  final String status;
  final DateTime appliedDate;

  AppliedJob({
    required this.id,
    required this.candidateId,
    required this.jobId,
    required this.status,
    required this.appliedDate,
  });

  factory AppliedJob.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return AppliedJob(
      id: doc.id,
      candidateId: data['candidateId'] ?? '',
      jobId: data['jobId'] ?? '',
      status: data['status'] ?? 'Pending',
      appliedDate: data['appliedDate']?.toDate() ?? DateTime.now(),
    );
  }
}

// Model class for Job details
class Job {
  final String id;
  final String title;
  final String companyName;
  final String location;
  final String jobType;
  final String contractType;
  final String salaryRange;
  final DateTime postedOn;
  final DateTime lastDateToApply;
  final String recruiterId;
  final dynamic description;

  Job({
    required this.id,
    required this.title,
    required this.companyName,
    required this.location,
    required this.jobType,
    required this.contractType,
    required this.salaryRange,
    required this.postedOn,
    required this.lastDateToApply,
    required this.recruiterId,
    required this.description,
  });

  factory Job.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Job(
      id: doc.id,
      title: data['title'] ?? 'Untitled Position',
      companyName: data['company_name'] ?? 'Unknown Company',
      location: data['location'] ?? 'Remote',
      jobType: data['job_type'] ?? 'Full-time',
      contractType: data['contract_type'] ?? 'Permanent',
      salaryRange: data['salary_range'] ?? 'Negotiable',
      postedOn: data['posted_on']?.toDate() ?? DateTime.now(),
      lastDateToApply: data['last_date_to_apply']?.toDate() ??
          DateTime.now().add(const Duration(days: 30)),
      recruiterId: data['recruiterId'] ?? '',
      description: data['description'] ?? '',
    );
  }

  // Helper method to parse description based on its type
  Map<String, dynamic> parseDescription() {
    if (description is String) {
      try {
        if (description.toString().startsWith('{')) {
          return Map<String, dynamic>.from(
              jsonDecode(description.toString()) as Map<String, dynamic>);
        }
        return {'position_summary': description};
      } catch (e) {
        return {'position_summary': description};
      }
    } else if (description is Map) {
      return Map<String, dynamic>.from(description as Map<String, dynamic>);
    }
    return {'position_summary': 'No description available.'};
  }
}

// Import for JSON parsing
