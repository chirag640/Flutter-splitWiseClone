import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:test_firebase/screens/home.dart';
import 'package:test_firebase/screens/login_signup.dart';
import 'package:test_firebase/screens/sign_in.dart';
import 'package:test_firebase/screens/sign_up.dart';
import 'package:test_firebase/widgets/user_profile.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Splitwise Clone",
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
          return const Home();
        } else {
          return const LoginSignup();
        }
      },
    );
  }
}