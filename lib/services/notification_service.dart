import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:logging/logging.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static String custom_value = 'itsnotification';
  static final Logger _logger = Logger('NotificationService');

  static Future<void> initialize() async {
    _logger.info('Initializing');
    try {
      final settings = await _messaging.requestPermission();
      _logger.fine('Permission status - ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        _logger.info('Notification permissions granted.');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        _logger.info('Notification permissions granted provisionally.');
      } else {
        _logger.warning('Notification permissions denied.');
        return; // Exit if permissions are not granted
      }

      String? token = await _messaging.getToken();
      if (token != null) {
        _logger.fine('Generated FCM Token: $token');
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({'token': token}, SetOptions(merge: true));
          _logger.fine('Token saved to Firestore for user: ${user.uid}');
        }
      } else {
        _logger.warning('Failed to generate FCM token.');
      }
    } catch (e) {
      _logger.severe('Error during initialization: $e');
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
  _logger.fine('Access token generated successfully.');
      return authClient.credentials.accessToken.data;
    } catch (e) {
  _logger.severe('Error generating access token: $e');
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
      _logger.fine('Sending notification to token: $token');
      if (response.statusCode == 200) {
        _logger.fine('Message sent successfully: ${response.body}');
      } else {
        _logger.warning('Failed to send message. Status: ${response.statusCode}');
        _logger.fine('Response body: ${response.body}');
      }
    } catch (e) {
      _logger.severe('Error sending notification: $e');
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
          _logger.warning('Failed to send notification to $token. Status: ${response.statusCode}');
        }
      }
    } catch (e) {
      _logger.severe('Error sending notifications: $e');
    }
  }
}