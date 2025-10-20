import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_application_2/utils/fcm_config.dart';

class JobNotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get server key from config
  final String _serverKey = FCMConfig.serverKey;

  // FCM API endpoint
  final String _fcmEndpoint = FCMConfig.fcmEndpoint;

  // Send job match notification to a candidate
  Future<void> sendJobMatchNotification({
    required String candidateId,
    required Map<String, dynamic> job,
    required double matchScore,
  }) async {
    try {
      // Step 1: Get candidate's FCM token from Firestore
      final userDoc =
          await _firestore.collection('Users').doc(candidateId).get();

      if (!userDoc.exists) {
        print('User $candidateId not found in database');
        return;
      }

      final userData = userDoc.data();
      if (userData == null ||
          !userData.containsKey('fcmToken') ||
          userData['fcmToken'] == null) {
        print('No FCM token found for user $candidateId');
        return;
      }

      final String fcmToken = userData['fcmToken'];
      if (fcmToken.isEmpty) {
        print('Empty FCM token for user $candidateId');
        return;
      }

      // Step 2: Format the notification data
      final int matchPercentage = (matchScore * 100).round();
      final String title = 'New job match found!';
      final String body =
          'A job at ${job['company_name']} matches your profile with a $matchPercentage% match score.';

      // Step 3: Prepare the FCM message
      final Map<String, dynamic> message = {
        'notification': {
          'title': title,
          'body': body,
        },
        'data': {
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          'job_id': job['id'],
          'job_title': job['title'],
          'company_name': job['company_name'],
          'match_score': matchScore.toString(),
          'notification_type': 'job_match'
        },
        'to': fcmToken,
      };

      // Step 4: Send the FCM message
      final response = await http.post(
        Uri.parse(_fcmEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$_serverKey',
        },
        body: jsonEncode(message),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == 1) {
          print('Notification sent successfully to user $candidateId');
        } else {
          print('Failed to send notification: ${response.body}');
        }
      } else {
        print(
            'Failed to send FCM message: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error sending job match notification: $e');
    }
  }

  // Save notification to Firestore for in-app display
  Future<void> saveNotificationToFirestore({
    required String userId,
    required String title,
    required String body,
    required String type,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _firestore.collection('UserNotifications').add({
        'userId': userId,
        'title': title,
        'body': body,
        'type': type,
        'data': data,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      print('Notification saved to Firestore for user $userId');
    } catch (e) {
      print('Error saving notification to Firestore: $e');
    }
  }
}
