import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:splitwise/theme.dart';
import 'package:splitwise/l10n/strings.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:splitwise/widgets/reset_password.dart';
// google_sign_in and kIsWeb not required for the email/password sign-in screen
// firebase_auth aliases/imports not needed here

class SignIn extends StatefulWidget {
  const SignIn({super.key});

  @override
  State<SignIn> createState() => _SignInState();
}

class _SignInState extends State<SignIn> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  void _loadSavedCredentials() async {
    // Load saved email from secure storage. Do NOT store or load plaintext
    // passwords locally. For session persistence rely on FirebaseAuth or
    // store tokens in secure storage (flutter_secure_storage).
    try {
      const secureStorage = FlutterSecureStorage();
      String? savedEmail = await secureStorage.read(key: 'saved_email');
      if (savedEmail != null) {
        _emailController.text = savedEmail;
      }
    } catch (e) {
      if (e.toString().contains('MissingPluginException')) {
        debugPrint('[SignIn] SecureStorage plugin missing on read: $e');
      } else {
        rethrow;
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  void _signInUser() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all the fields'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      FirebaseAuth.instance.setLanguageCode('en');
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
      final user = userCredential.user;

      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email not verified. Verification email sent.'), backgroundColor: Colors.red),
        );
        await FirebaseAuth.instance.signOut();
      } else {
        try {
          const secureStorage = FlutterSecureStorage();
          await secureStorage.write(key: 'refresh_token', value: 'signed_in');
        } catch (e) {
          if (e.toString().contains('MissingPluginException')) {
            debugPrint('[SignIn] SecureStorage plugin missing on write: $e');
          } else {
            rethrow;
          }
        }

        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.message}'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // Google sign-in removed from this screen. Email/password sign-in remains.

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.md + bottomInset),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back),
                  tooltip: 'Back',
                  onPressed: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    } else {
                      Navigator.pushReplacementNamed(context, '/login_signup');
                    }
                  },
                ),
                SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: _emailController,
                  enabled: !_isSubmitting,
                  style: Theme.of(context).textTheme.bodyMedium,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Enter email';
                    final emailRegex = RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}");
                    if (!emailRegex.hasMatch(v.trim())) return 'Enter a valid email';
                    return null;
                  },
                  decoration: InputDecoration(labelText: Strings.emailAddress),
                ),
                SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _passwordController,
                  enabled: !_isSubmitting,
                  obscureText: _obscurePassword,
                  style: Theme.of(context).textTheme.bodyMedium,
                  validator: (v) => (v == null || v.isEmpty) ? 'Enter password' : null,
                  decoration: InputDecoration(
                    labelText: Strings.password,
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                      tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                      onPressed: _togglePasswordVisibility,
                    ),
                  ),
                ),
                SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : () {
                      if (_formKey.currentState!.validate()) _signInUser();
                    },
          child: _isSubmitting
            ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(Strings.signIn),
                  ),
                ),
                SizedBox(height: AppSpacing.md),
                Center(
                  child: TextButton(
                    onPressed: _isSubmitting ? null : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => ResetPasswordScreen()),
                      );
                    },
                    child: Text('Forgot Password?'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}