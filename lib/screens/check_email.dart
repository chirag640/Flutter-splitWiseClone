import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:splitwise/l10n/strings.dart';

class CheckEmailScreen extends StatefulWidget {
  const CheckEmailScreen({super.key});

  @override
  State<CheckEmailScreen> createState() => _CheckEmailScreenState();
}

class _CheckEmailScreenState extends State<CheckEmailScreen> {
  bool _isResending = false;
  bool _isChecking = false;

  Future<void> _resend() async {
    if (_isResending) return;
    setState(() => _isResending = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Verification email resent')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to resend verification')));
    }
    if (mounted) setState(() => _isResending = false);
  }

  Future<void> _checkVerified() async {
    if (_isChecking) return;
    setState(() => _isChecking = true);
    try {
      await FirebaseAuth.instance.currentUser?.reload();
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.emailVerified) {
        Navigator.pushReplacementNamed(context, '/login_signup');
        return;
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Email not verified yet')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to check verification')));
    }
    if (mounted) setState(() => _isChecking = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(Strings.checkYourEmail)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.email, size: 72),
            SizedBox(height: 16),
            Text('We sent a verification email. Please open it and click the link to verify.' , textAlign: TextAlign.center,),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isResending ? null : _resend,
              child: _isResending ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(Strings.resendEmail),
            ),
            SizedBox(height: 12),
            OutlinedButton(
              onPressed: _isChecking ? null : _checkVerified,
              child: _isChecking ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text('I verified'),
            ),
          ],
        ),
      ),
    );
  }
}
