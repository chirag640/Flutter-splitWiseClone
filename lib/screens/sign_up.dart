import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:splitwise/theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform; // For platform detection (not available on web)
import 'package:flutter/foundation.dart'; // For kIsWeb

class SignUp extends StatefulWidget {
  const SignUp({super.key});

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  bool _obscurePassword = true;
  String _fullName = '';
  String _email = '';
  String _password = '';
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

String? _isPasswordStrong(String password) {
  // Require: min 8 chars, at least one upper, one lower, one digit and one special char
    final regex = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&]).{8,}$');
    if (!regex.hasMatch(password)) {
    return 'Password must be 8+ chars and include upper, lower, number and special char.';
  }
  return null;
}

  void _registerUser() async {
  if (!_formKey.currentState!.validate()) return;
  _fullName = _fullNameController.text.trim();
  _email = _emailController.text.trim();
  _password = _passwordController.text;

  try {
    // Set the locale for Firebase Authentication
    FirebaseAuth.instance.setLanguageCode('en'); // Change 'en' to your desired locale

    UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: _email,
      password: _password,
    );

    User? user = userCredential.user;
    if (user != null) {
      await user.sendEmailVerification();

      // Obtain FCM token safely (will return null on unsupported platforms or if plugin missing)
      final token = await _getFcmTokenSafely();

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'displayName': _fullName,
        'email': _email,
        'uid': user.uid,
        'token': token, // May be null if unsupported / unavailable
      });

  // Save email only. DO NOT save plaintext passwords to SharedPreferences.
  // Storing raw passwords locally is insecure and unnecessary. If you need
  // a persistent "remember me" behavior, rely on FirebaseAuth persistence
  // (which keeps the user signed in) or use a secure storage backed by
  // platform keystore/Keychain (e.g. flutter_secure_storage) to store tokens
  // — never store raw passwords.
  // Save email securely using platform-backed secure storage.
  // We keep SharedPreferences for other non-sensitive prefs, but use
  // flutter_secure_storage to persist sensitive items like tokens or
  // emails when desired.
  await _secureWrite('saved_email', _email);
  await _secureWrite('refresh_token', 'signed_in');

  _showSnackBar('Verification email sent. Please check your inbox.', backgroundColor: AppColors.success);

      Navigator.pushNamedAndRemoveUntil(context, '/login_signup', (route) => false);
    }
  } on FirebaseAuthException catch (e) {
    _showSnackBar('Auth error: ${e.message}');
  } catch (e) {
    final err = e.toString();
    // Suppress user-facing SnackBar for MissingPluginException (common on unsupported desktop platforms)
    if (err.contains('MissingPluginException')) {
      // Optionally log silently. Do not show SnackBar to avoid confusion.
      debugPrint('[SignUp] Missing plugin (likely firebase_messaging unsupported on this platform): $e');
      // Continue without failing signup entirely.
      return;
    }
    _showSnackBar('Error: $e');
  }
}

  // Helper to safely show SnackBars only when the widget is mounted.
  void _showSnackBar(String message, {Color backgroundColor = Colors.red}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
      ),
    );
  }

  // Returns FCM token or null if unsupported / missing plugin.
  Future<String?> _getFcmTokenSafely() async {
    // firebase_messaging supports Android, iOS, macOS & web. Skip others (e.g., Windows/Linux) to avoid MissingPluginException.
    final supportsFcm = kIsWeb || (!kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS));
    if (!supportsFcm) return null;
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      final err = e.toString();
      if (err.contains('MissingPluginException')) {
        debugPrint('[SignUp] FCM plugin not available on this platform: $e');
        return null; // Gracefully degrade
      }
      rethrow; // Other errors propagate to outer catch
    }
  }

  // Safe secure-storage write (suppresses MissingPlugin on unsupported platforms / tests)
  Future<void> _secureWrite(String key, String value) async {
    try {
      // flutter_secure_storage supports mobile, web, macOS, Linux, Windows (with proper setup). If plugin missing, catch below.
      const storage = FlutterSecureStorage();
      await storage.write(key: key, value: value);
    } catch (e) {
      final err = e.toString();
      if (err.contains('MissingPluginException')) {
        debugPrint('[SignUp] SecureStorage plugin missing when writing $key: $e');
        return; // Silently ignore in dev environments without plugin.
      }
      rethrow;
    }
  }
  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScaleFactorOf(context);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
                SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: _fullNameController,
                  style: Theme.of(context).textTheme.bodyMedium,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your full name' : null,
                  decoration: InputDecoration(labelText: 'Full name'),
                ),
                SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _emailController,
                  style: Theme.of(context).textTheme.bodyMedium,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Enter email';
                    final emailRegex = RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}");
                    if (!emailRegex.hasMatch(v.trim())) return 'Enter a valid email';
                    return null;
                  },
                  decoration: InputDecoration(labelText: 'Email address'),
                ),
                SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: Theme.of(context).textTheme.bodyMedium,
                  validator: (v) => _isPasswordStrong(v ?? '') ,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                      onPressed: _togglePasswordVisibility,
                    ),
                    helperText: 'Minimum 8 characters',
                  ),
                  onChanged: (val) => setState(() {}),
                ),
                SizedBox(height: AppSpacing.xs),
                // Password strength indicator
                Builder(builder: (ctx) {
                  final pw = _passwordController.text;
                  final err = _isPasswordStrong(pw);
                  final strength = pw.isEmpty ? 0 : (err == null ? 3 : 1);
                  Color color;
                  String label;
                  if (strength == 0) {
                    color = Colors.grey;
                    label = '';
                  } else if (strength == 1) {
                    color = Colors.orangeAccent;
                    label = 'Weak';
                  } else {
                    color = AppColors.success;
                    label = 'Strong';
                  }
                  return Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: FractionallySizedBox(
                            widthFactor: strength == 0 ? 0 : (strength == 1 ? 0.4 : 1.0),
                            alignment: Alignment.centerLeft,
                            child: Container(color: color),
                          ),
                        ),
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Text(label, style: TextStyle(color: color, fontSize: 12 * textScale)),
                    ],
                  );
                }),
                SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _registerUser,
                    child: Text('Done'),
                  ),
                ),
                SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}