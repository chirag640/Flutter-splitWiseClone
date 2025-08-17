import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:splitwise/screens/home.dart';
import 'package:splitwise/screens/login_signup.dart';
import 'package:splitwise/screens/sign_in.dart';
import 'package:splitwise/screens/sign_up.dart';
import 'package:splitwise/theme.dart';
import 'package:splitwise/services/notification_service.dart';
import 'package:splitwise/widgets/user_profile.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:logging/logging.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  // Configure logging
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((record) {
    // Simple console output for logs; adapt to your logging backend if needed
    // Avoid using print() directly so logs can be filtered by level
    // Example format: [LEVEL] LoggerName: message
    // Use stderr to separate from normal stdout if desired
    final ts = record.time.toIso8601String();
    print('[$ts] [${record.level.name}] ${record.loggerName}: ${record.message}');
    if (record.error != null) {
      print(record.error);
    }
    if (record.stackTrace != null) {
      print(record.stackTrace);
    }
  });
  await NotificationService.initialize(); // Use the class name to call the static method
  await FirebaseMessaging.instance.requestPermission();

  // Listen for foreground messages
  final _logger = Logger('MainApp');
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    _logger.info('Foreground message received: ${message.notification?.title}, ${message.notification?.body}');
  });

  // Handle background messages
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const MainApp());
}

// Background message handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final _logger = Logger('MainApp');
  _logger.info('Background message received: ${message.notification?.title}, ${message.notification?.body}');
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Splitwise",
  theme: AppTheme.darkTheme,
  darkTheme: AppTheme.darkTheme,
  themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
  home: const SplashScreen(),
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
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
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

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkCurrentUser();
  }

  Future<void> _checkCurrentUser() async {
    // Short delay to show splash and allow any native plugins to initialize
    await Future.delayed(const Duration(milliseconds: 700));

    final user = FirebaseAuth.instance.currentUser;

    if (user != null && user.emailVerified) {
      // User already signed in and verified — go to Home
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      // Not signed in or not verified — go to login/signup
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login_signup');
    }
  }

  @override
  Widget build(BuildContext context) {
  return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              // Simple spinner + app title; replace with logo if desired
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading...', style: TextStyle()),
            ],
          ),
        ),
      ),
    );
  }
}