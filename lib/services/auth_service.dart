/*import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_2/services/messaging_service.dart';
import 'package:flutter_application_2/services/fcm_token_provider.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final MessagingService _messagingService;
  late final FCMTokenProvider _fcmTokenProvider;

  AuthService({
    required MessagingService messagingService,
    required FCMTokenProvider fcmTokenProvider,
  })  : _messagingService = messagingService,
        _fcmTokenProvider = fcmTokenProvider;

  Future<UserCredential> loginWithEmailAndPassword(
      String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _setupFCMForUser(userCredential.user);

      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  Future<UserCredential> registerWithEmailAndPassword(
      String email, String password) async {
    try {
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _setupFCMForUser(userCredential.user);

      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _setupFCMForUser(User? user) async {
    if (user == null) return;

    // Refresh FCM token (instead of calling _initialize, which is private and already called)
    await _fcmTokenProvider.refreshToken();

    // Subscribe to topics
    await _fcmTokenProvider.subscribeToTopics();
  }

  Future<void> signOut() async {
    await _fcmTokenProvider.clearToken();
    await _auth.signOut();
  }
}
*/
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_2/services/messaging_service.dart';
import 'package:flutter_application_2/services/fcm_token_provider.dart';
import 'package:flutter_application_2/services/AppNotificationManager.dart';
import 'package:flutter/material.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final MessagingService _messagingService;
  late final FCMTokenProvider _fcmTokenProvider;
  final AppNotificationManager _notificationManager = AppNotificationManager();

  AuthService({
    required MessagingService messagingService,
    required FCMTokenProvider fcmTokenProvider,
  })  : _messagingService = messagingService,
        _fcmTokenProvider = fcmTokenProvider;

  Future<UserCredential> loginWithEmailAndPassword(
      String email, String password, BuildContext context) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _setupFCMForUser(userCredential.user);

      // Initialize notifications
      await _notificationManager.initialize(context);

      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  Future<UserCredential> registerWithEmailAndPassword(
      String email, String password, BuildContext context) async {
    try {
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _setupFCMForUser(userCredential.user);

      // Initialize notifications
      await _notificationManager.initialize(context);

      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _setupFCMForUser(User? user) async {
    if (user == null) return;

    // Refresh FCM token
    await _fcmTokenProvider.refreshToken();

    // Subscribe to topics
    await _fcmTokenProvider.subscribeToTopics();
  }

  Future<void> signOut() async {
    await _fcmTokenProvider.clearToken();
    await _auth.signOut();
  }
}
