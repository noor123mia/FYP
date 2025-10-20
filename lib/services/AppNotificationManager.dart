import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_application_2/services/fcm_token_provider.dart';
import 'package:flutter_application_2/services/job_notification_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';

class AppNotificationManager {
  static final AppNotificationManager _instance =
      AppNotificationManager._internal();
  factory AppNotificationManager() => _instance;
  AppNotificationManager._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  int _notificationCount = 0;
  final ValueNotifier<int> notificationCounter = ValueNotifier<int>(0);

  // Initialize on app startup
  Future<void> initialize(BuildContext context) async {
    // Request permissions
    await _requestPermissions();

    // Configure FCM for foreground notifications
    await _configureForegroundNotifications();

    // Initialize local notifications
    await _initializeLocalNotifications();

    // Set up message handlers
    _setupMessageHandlers(context);

    // Load notification count from Firestore
    await _loadNotificationCount();
  }

  Future<void> _requestPermissions() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    print('User granted permission: ${settings.authorizationStatus}');
  }

  Future<void> _configureForegroundNotifications() async {
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iOSSettings =
        DarwinInitializationSettings();
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iOSSettings,
    );

    await _localNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
        _handleNotificationTap(response.payload);
      },
    );
  }

  void _setupMessageHandlers(BuildContext context) {
    // Handle terminated state messages
    FirebaseMessaging.instance
        .getInitialMessage()
        .then((RemoteMessage? message) {
      if (message != null) {
        _handleMessage(message, context);
      }
    });

    // Handle background messages
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleMessage(message, context);
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
      _incrementNotificationCount();
    });
  }

  void _handleMessage(RemoteMessage message, BuildContext context) {
    if (message.data.containsKey('job_id')) {
      // Navigate to job details page
      // Navigator.pushNamed(context, '/job-details', arguments: message.data['job_id']);
    } else if (message.data.containsKey('notification_type')) {
      // Handle based on notification type
      switch (message.data['notification_type']) {
        case 'job_match':
          // Navigator.pushNamed(context, '/notifications');
          break;
        default:
          // Navigator.pushNamed(context, '/notifications');
          break;
      }
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      await _localNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'job_channel',
            'Job Notifications',
            channelDescription:
                'Notifications about job matches and applications',
            importance: Importance.high,
            priority: Priority.high,
            icon: android.smallIcon,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: message.data['job_id'],
      );
    }
  }

  void _handleNotificationTap(String? payload) {
    if (payload != null) {
      // Handle notification tap based on payload
      // Navigate to appropriate screen
    }
  }

  Future<void> _loadNotificationCount() async {
    try {
      final FirebaseAuth auth = FirebaseAuth.instance;
      final FirebaseFirestore firestore = FirebaseFirestore.instance;

      if (auth.currentUser != null) {
        // Get unread notification count
        final querySnapshot = await firestore
            .collection('UserNotifications')
            .where('userId', isEqualTo: auth.currentUser!.uid)
            .where('read', isEqualTo: false)
            .get();

        _notificationCount = querySnapshot.docs.length;
        notificationCounter.value = _notificationCount;
      }
    } catch (e) {
      print('Error loading notification count: $e');
    }
  }

  void _incrementNotificationCount() {
    _notificationCount++;
    notificationCounter.value = _notificationCount;
  }

  void resetNotificationCount() {
    _notificationCount = 0;
    notificationCounter.value = 0;
  }

  // Mark notifications as read in Firestore
  Future<void> markNotificationsAsRead() async {
    try {
      final FirebaseAuth auth = FirebaseAuth.instance;
      final FirebaseFirestore firestore = FirebaseFirestore.instance;

      if (auth.currentUser != null) {
        final batch = firestore.batch();

        final querySnapshot = await firestore
            .collection('UserNotifications')
            .where('userId', isEqualTo: auth.currentUser!.uid)
            .where('read', isEqualTo: false)
            .get();

        for (var doc in querySnapshot.docs) {
          batch.update(doc.reference, {'read': true});
        }

        await batch.commit();
        resetNotificationCount();
      }
    } catch (e) {
      print('Error marking notifications as read: $e');
    }
  }
}
