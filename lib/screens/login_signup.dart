import 'package:flutter/material.dart';
import 'package:splitwise/theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:io' show Platform;

class LoginSignup extends StatefulWidget {
  const LoginSignup({super.key});

  @override
  State<LoginSignup> createState() => _LoginSignupState();
}

class _LoginSignupState extends State<LoginSignup> {
  bool _isSubmitting = false;

  Future<void> _signInWithGoogle() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        final userCredential = await FirebaseAuth.instance.signInWithPopup(provider);
        if (userCredential.user != null) {
          final u = userCredential.user!;
          // create or update Firestore user doc
            try {
              final token = await _getFcmTokenSafely();
              await FirebaseFirestore.instance.collection('users').doc(u.uid).set({
                'displayName': u.displayName ?? '',
                'email': u.email ?? '',
                'uid': u.uid,
                'photoURL': u.photoURL ?? '',
                'token': token,
                'provider': 'google',
                'createdAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
            } catch (e) {
              debugPrint('[LoginSignup] Failed to write user doc: $e');
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Warning: failed to save user data: $e')));
            }
          if (!mounted) return;
          Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false);
        }
      } else {
        final googleSignIn = GoogleSignIn();
        final googleUser = await googleSignIn.signIn();
        if (googleUser == null) return; // cancelled
        final auth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(accessToken: auth.accessToken, idToken: auth.idToken);
        final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
        if (userCredential.user != null) {
          final u = userCredential.user!;
            try {
              final token = await _getFcmTokenSafely();
              await FirebaseFirestore.instance.collection('users').doc(u.uid).set({
                'displayName': u.displayName ?? '',
                'email': u.email ?? '',
                'uid': u.uid,
                'photoURL': u.photoURL ?? '',
                'token': token,
                'provider': 'google',
                'createdAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
            } catch (e) {
              debugPrint('[LoginSignup] Failed to write user doc: $e');
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Warning: failed to save user data: $e')));
            }
          if (!mounted) return;
          Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false);
        }
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Google sign-in failed: ${e.message}'), backgroundColor: Colors.red));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Google sign-in error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // Returns FCM token or null if unsupported / missing plugin.
  Future<String?> _getFcmTokenSafely() async {
    final supportsFcm = kIsWeb || (!kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS));
    if (!supportsFcm) return null;
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      final err = e.toString();
      if (err.contains('MissingPluginException')) {
        debugPrint('[LoginSignup] FCM plugin not available on this platform: $e');
        return null;
      }
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            // Logo
            Image.asset(
              'assets/images/logo.png',
              height: 120,
            ),
            SizedBox(height: AppSpacing.md),
            // Title
            Text(
              'Splitwise',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: AppSpacing.sm),
            // Subtitle / brief value prop
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Text(
                'Split bills & track balances with friends',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onBackground.withOpacity(0.85)),
              ),
            ),
            const Spacer(),
            // Sign up button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/sign_up');
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('Sign up'),
              ),
            ),
            SizedBox(height: AppSpacing.sm),
            // Log in button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/sign_in');
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('Log in'),
              ),
            ),
            SizedBox(height: AppSpacing.md),
            // Google sign-in button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _signInWithGoogle,
                  icon: const Icon(Icons.login, color: Colors.redAccent),
                  label: _isSubmitting
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Continue with Google'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ),
            ),
            SizedBox(height: AppSpacing.lg),
            // Terms and privacy
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(onPressed: () {}, child: const Text('Terms')),
                const Text('|'),
                TextButton(onPressed: () {}, child: const Text('Privacy Policy')),
                const Text('|'),
                TextButton(onPressed: () {}, child: const Text('Contact us')),
              ],
            ),
            SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}
