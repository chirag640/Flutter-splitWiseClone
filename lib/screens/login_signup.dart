import 'package:flutter/material.dart';

class LoginSignup extends StatelessWidget {
  const LoginSignup({super.key});


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
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
            SizedBox(height: 20),
            // Title
            Text(
              'Splitwise',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
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
                  backgroundColor: Color(0xFF21A179), // Green color
                  minimumSize: Size(double.infinity, 50),
                ),
                child: Text('Sign up' , style: TextStyle(color: Colors.white)),
              ),
            ),
            SizedBox(height: 12),
            // Log in button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/sign_in');
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white),
                  minimumSize: Size(double.infinity, 50),
                ),
                child: Text(
                  'Log in',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
            SizedBox(height: 24),
            // Terms and privacy
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () {},
                  child: Text('Terms', style: TextStyle(color: Colors.white)),
                ),
                Text('|', style: TextStyle(color: Colors.white)),
                TextButton(
                  onPressed: () {},
                  child: Text('Privacy Policy', style: TextStyle(color: Colors.white)),
                ),
                Text('|', style: TextStyle(color: Colors.white)),
                TextButton(
                  onPressed: () {},
                  child: Text('Contact us', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
