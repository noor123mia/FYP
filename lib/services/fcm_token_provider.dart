import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class FCMTokenProvider extends ChangeNotifier {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _token;

  String? get token => _token;

  FCMTokenProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    await refreshToken();

    _firebaseMessaging.onTokenRefresh.listen((newToken) async {
      await _saveTokenToFirestore(newToken);
      _token = newToken;
      notifyListeners();
    });
  }

  Future<void> subscribeToTopics() async {
    await subscribeToTopic('all_users');
    if (_auth.currentUser != null) {
      await subscribeToTopic('user_${_auth.currentUser!.uid}');
    }
  }

  Future<void> refreshToken() async {
    try {
      final String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        await _saveTokenToFirestore(token);
        _token = token;
        print('FCM Token: $token'); // Added for debugging
        notifyListeners();
      }
    } catch (e) {
      print('Error refreshing token: $e');
    }
  }

  Future<void> _saveTokenToFirestore(String token) async {
    try {
      if (_auth.currentUser != null) {
        final String userId = _auth.currentUser!.uid;
        final docSnapshot =
            await _firestore.collection('Users').doc(userId).get();

        if (docSnapshot.exists) {
          await _firestore.collection('Users').doc(userId).update({
            'fcmToken': token,
            'lastTokenUpdate': FieldValue.serverTimestamp(),
            'platform': _getPlatform(),
          });
        } else {
          await _firestore.collection('Users').doc(userId).set({
            'fcmToken': token,
            'userId': userId,
            'createdAt': FieldValue.serverTimestamp(),
            'lastTokenUpdate': FieldValue.serverTimestamp(),
            'platform': _getPlatform(),
          });
        }
        print('FCM token saved to Firestore for user $userId');
      }
    } catch (e) {
      print('Error saving token to Firestore: $e');
    }
  }

  String _getPlatform() {
    if (kIsWeb) return 'web';
    if (defaultTargetPlatform == TargetPlatform.android) return 'android';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    return 'unknown';
  }

  Future<void> subscribeToTopic(String topic) async {
    await _firebaseMessaging.subscribeToTopic(topic);
    print('Subscribed to topic: $topic');
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    await _firebaseMessaging.unsubscribeFromTopic(topic);
    print('Unsubscribed from topic: $topic');
  }

  Future<void> clearToken() async {
    try {
      if (_auth.currentUser != null) {
        await _firestore
            .collection('Users')
            .doc(_auth.currentUser!.uid)
            .update({
          'fcmToken': null,
        });
        _token = null;
        notifyListeners();
        print('FCM token cleared for user ${_auth.currentUser!.uid}');
      }
    } catch (e) {
      print('Error clearing token: $e');
    }
  }
}
