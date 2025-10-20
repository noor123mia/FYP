import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CandidatesNotificationScreen extends StatefulWidget {
  const CandidatesNotificationScreen({Key? key}) : super(key: key);

  @override
  State<CandidatesNotificationScreen> createState() =>
      _CandidatesNotificationScreenState();
}

class _CandidatesNotificationScreenState
    extends State<CandidatesNotificationScreen> {
  late String candidateId;
  bool isLoading = true;
  List<Map<String, dynamic>> notifications = [];

  @override
  void initState() {
    super.initState();
    loadNotifications();
  }

  Future<void> loadNotifications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      candidateId = user.uid;

      final snapshot = await FirebaseFirestore.instance
          .collection('Notifications')
          .where('candidateId', isEqualTo: candidateId)
          .get();

      notifications = snapshot.docs.map((doc) {
        final data = doc.data();
        data.remove('recruiterId'); // 🔥 Hide recruiter_id
        return data;
      }).toList();

      setState(() {
        isLoading = false;
      });
    }
  }

  String formatTimestamp(Timestamp timestamp) {
    return DateFormat.yMMMd().add_jm().format(timestamp.toDate());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : notifications.isEmpty
              ? const Center(child: Text('No notifications found.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    return Card(
                      elevation: 6,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notification['jobTitle'] ?? 'No Title',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              notification['companyName'] ?? 'No Company Name',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              notification['message'] ?? 'No Message',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              formatTimestamp(notification['timestamp']),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
