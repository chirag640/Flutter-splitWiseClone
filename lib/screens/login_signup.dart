import 'package:flutter/material.dart';
import 'package:splitwise/theme.dart';

class LoginSignup extends StatelessWidget {
  const LoginSignup({super.key});


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Spacer(),
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
            Spacer(),
            // Sign up button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/sign_up');
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                ),
                child: Text('Sign up'),
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
                  minimumSize: Size(double.infinity, 50),
                ),
                child: Text('Log in'),
              ),
            ),
            SizedBox(height: AppSpacing.lg),
            // Terms and privacy
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(onPressed: () {}, child: Text('Terms')),
                Text('|'),
                TextButton(onPressed: () {}, child: Text('Privacy Policy')),
                Text('|'),
                TextButton(onPressed: () {}, child: Text('Contact us')),
              ],
            ),
            SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}
