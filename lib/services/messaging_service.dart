import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MessagingService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // For handling foreground notifications
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Initialize the FCM service
  Future<void> initialize(BuildContext context) async {
    try {
      // Request permission for notifications (iOS)
      NotificationSettings settings =
          await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      print(
          'User notification permission status: ${settings.authorizationStatus}');

      // Set up foreground notification channel for Android
      if (!kIsWeb) {
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          'job_match_channel', // ID
          'Job Match Notifications', // Title
          description: 'Notifications for new job matches', // Description
          importance: Importance.high,
        );

        await _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);
      }

      // Initialize local notifications
      await _flutterLocalNotificationsPlugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          _handleNotificationTap(response.payload, context);
        },
      );

      // Handle FCM message when the app is in the foreground
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('Got a message whilst in the foreground!');
        print('Message data: ${message.data}');

        if (message.notification != null) {
          print(
              'Message also contained a notification: ${message.notification}');

          // Show local notification
          _showLocalNotification(message);
        }
      });

      // Handle when a notification is tapped to open the app from terminated state
      FirebaseMessaging.instance
          .getInitialMessage()
          .then((RemoteMessage? message) {
        if (message != null) {
          print('App opened from terminated state via notification');
          _handleNotificationTap(jsonEncode(message.data), context);
        }
      });

      // Handle when a notification is tapped to open the app from background state
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('App opened from background state via notification');
        _handleNotificationTap(jsonEncode(message.data), context);
      });

      // Get and store the FCM token
      _getFcmToken();
    } catch (e) {
      print('Error initializing messaging service: $e');
    }
  }

  // Get and store FCM token
  Future<void> _getFcmToken() async {
    try {
      String? token = await _firebaseMessaging.getToken();

      if (token != null && _auth.currentUser != null) {
        // Store token in Firestore
        await _firestore
            .collection('Users')
            .doc(_auth.currentUser!.uid)
            .update({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });

        print('FCM Token stored: $token');

        // Set up token refresh listener
        _firebaseMessaging.onTokenRefresh.listen((newToken) async {
          await _firestore
              .collection('Users')
              .doc(_auth.currentUser!.uid)
              .update({
            'fcmToken': newToken,
            'lastTokenUpdate': FieldValue.serverTimestamp(),
          });

          print('FCM Token refreshed: $newToken');
        });
      }
    } catch (e) {
      print('Error getting/storing FCM token: $e');
    }
  }

  // Show a local notification when the app is in the foreground
  Future<void> _showLocalNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null && !kIsWeb) {
      await _flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'job_match_channel',
            'Job Match Notifications',
            channelDescription: 'Notifications for new job matches',
            icon: android.smallIcon ?? '@mipmap/ic_launcher',
            importance: Importance.high,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: jsonEncode(message.data),
      );
    }
  }

  // Handle notification tap
  void _handleNotificationTap(String? payload, BuildContext context) {
    if (payload != null) {
      try {
        final data = jsonDecode(payload);

        if (data.containsKey('notification_type')) {
          if (data['notification_type'] == 'job_match') {
            // Navigate to job details screen
            Navigator.of(context, rootNavigator: true).pushNamed(
              '/job-details',
              arguments: {
                'jobId': data['job_id'],
                'fromNotification': true,
              },
            );
          }
        }
      } catch (e) {
        print('Error handling notification tap: $e');
      }
    }
  }

  // Subscribe to a topic
  Future<void> subscribeToTopic(String topic) async {
    await _firebaseMessaging.subscribeToTopic(topic);
    print('Subscribed to topic: $topic');
  }

  // Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _firebaseMessaging.unsubscribeFromTopic(topic);
    print('Unsubscribed from topic: $topic');
  }
}
