import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:googleapis_auth/auth_io.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static String custom_value = 'itsnotification';

  static Future<void> initialize() async {
    print("NotificationService: Initializing...");
    try {
      final settings = await _messaging.requestPermission();
      print("NotificationService: Permission status - ${settings.authorizationStatus}");

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print("NotificationService: Notification permissions granted.");
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        print("NotificationService: Notification permissions granted provisionally.");
      } else {
        print("NotificationService: Notification permissions denied.");
        return; // Exit if permissions are not granted
      }

      String? token = await _messaging.getToken();
      if (token != null) {
        print("NotificationService: Generated FCM Token: $token");
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({'token': token}, SetOptions(merge: true));
          print("NotificationService: Token saved to Firestore for user: ${user.uid}");
        }
      } else {
        print("NotificationService: Failed to generate FCM token.");
      }
    } catch (e) {
      print("NotificationService: Error during initialization: $e");
    }
  }

  static Future<String> _getAccessToken() async {
    try {
      // Load the service account key
      final keyData = await rootBundle.loadString('assets/service_account_key.json');
      final serviceAccount = json.decode(keyData);

      // Validate the service account key
      if (!serviceAccount.containsKey('private_key') || !serviceAccount.containsKey('client_email')) {
        throw Exception("Invalid service account key: Missing required fields.");
      }

      final privateKey = serviceAccount['private_key'];
      if (!privateKey.startsWith('-----BEGIN PRIVATE KEY-----') ||
          !privateKey.endsWith('-----END PRIVATE KEY-----\n')) {
        throw Exception("Invalid private key format in service account key.");
      }

      final accountCredentials = ServiceAccountCredentials.fromJson(serviceAccount);
      final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];

      // Generate the access token
      final authClient = await clientViaServiceAccount(accountCredentials, scopes);
      print("Access token generated successfully.");
      return authClient.credentials.accessToken.data;
    } catch (e) {
      print("Error generating access token: $e");
      throw Exception("Failed to generate access token.");
    }
  }

  Future<void> sendNotification({
    required String token,
    required String title,
    required String body,
  }) async {
    try {
      final accessToken = await _getAccessToken();
      final url = 'https://fcm.googleapis.com/v1/projects/testapp-5ffca/messages:send';
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      };
      final payload = {
        'message': {
          'token': token,
          'notification': {
            'title': title,
            'body': body,
          },
          'data': {
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            'custom_key': custom_value,
          },
        }
      };

      final response = await http.post(Uri.parse(url), headers: headers, body: json.encode(payload));
      print("Sending notification to token: $token");
      if (response.statusCode == 200) {
        print("Message sent successfully: ${response.body}");
      } else {
        print("Failed to send message. Status: ${response.statusCode}");
        print("Response body: ${response.body}");
      }
    } catch (e) {
      print("Error sending notification: $e");
    }
  }

  Future<void> sendNotificationToMultiple({
    required List<String> tokens,
    required String title,
    required String body,
  }) async {
    try {
      final accessToken = await _getAccessToken();
      final url = 'https://fcm.googleapis.com/v1/projects/testapp-5ffca/messages:send';
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      };

      for (String token in tokens) {
        final payload = {
          'message': {
            'token': token,
            'notification': {
              'title': title,
              'body': body,
            },
            'data': {
              'click_action': 'FLUTTER_NOTIFICATION_CLICK',
              'custom_key': custom_value,
            },
          }
        };

        final response = await http.post(Uri.parse(url), headers: headers, body: json.encode(payload));
        if (response.statusCode != 200) {
          print("Failed to send notification to $token. Status: ${response.statusCode}");
        }
      }
    } catch (e) {
      print("Error sending notifications: $e");
    }
  }
}