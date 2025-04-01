import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:splitwise/screens/home.dart';
import 'package:splitwise/screens/login_signup.dart';
import 'package:splitwise/screens/sign_in.dart';
import 'package:splitwise/screens/sign_up.dart';
import 'package:splitwise/services/notification_service.dart';
import 'package:splitwise/widgets/user_profile.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await NotificationService.initialize(); // Use the class name to call the static method
  await FirebaseMessaging.instance.requestPermission();

  // Listen for foreground messages
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print("Foreground message received: ${message.notification?.title}, ${message.notification?.body}");
  });

  // Handle background messages
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const MainApp());
}

// Background message handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Background message received: ${message.notification?.title}, ${message.notification?.body}");
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Splitwise",
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.green,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.green,
      ),
      themeMode: ThemeMode.dark,
      debugShowCheckedModeBanner: false,
      home: const AuthWrapper(),
      routes: {
        '/sign_in': (context) => SignIn(),
        '/login_signup': (context) => LoginSignup(),
        '/sign_up': (context) => SignUp(),
        '/home': (context) => Home(),
        '/user_profile': (context) => UserProfileScreen(),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        } else if (snapshot.hasData) {
          User? user = snapshot.data;
          if (user != null && user.emailVerified) {
            return const Home();
          } else {
            return const LoginSignup();
          }
        } else {
          return const LoginSignup();
        }
      },
    );
  }
}