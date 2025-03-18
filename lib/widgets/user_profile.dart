import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  _UserProfileScreenState createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  late Future<Map<String, dynamic>?> _userDataFuture;

  @override
  void initState() {
    super.initState();
    _userDataFuture = _getUserData();
  }

  Future<Map<String, dynamic>?> _getUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userData = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      return userData.data();
    }
    return null;
  }

  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushNamedAndRemoveUntil(context, '/login_signup', (route) => false);
  }

  Future<void> _updateUserName(BuildContext context, String newName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'displayName': newName,
        });

        // Update the name in groups where the user is a member
        final userGroups = await FirebaseFirestore.instance
            .collectionGroup('members')
            .where('id', isEqualTo: user.uid)
            .get();

        for (var group in userGroups.docs) {
          await group.reference.update({
            'fullName': newName,
          });
        }

        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('Name updated successfully.'),
            backgroundColor: Colors.green,
          ),
        );

        // Refresh user data
        setState(() {
          _userDataFuture = _getUserData();
        });
      } catch (e) {
        print('Error updating name: $e');
        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showUpdateNameDialog(BuildContext context, String currentName) {
    final TextEditingController _nameController = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Update Name'),
          content: TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Full Name',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final newName = _nameController.text;
                if (newName.isNotEmpty) {
                  _updateUserName(context, newName);
                  Navigator.of(context).pop();
                } else {
                  _scaffoldMessengerKey.currentState?.showSnackBar(
                    SnackBar(
                      content: Text('Name cannot be empty'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: Text('Update'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: FutureBuilder<Map<String, dynamic>?>(
          future: _userDataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data == null) {
              return const Center(child: Text('No user data found.'));
            }

            final userData = snapshot.data!;
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      child: ListTile(
                        leading: Icon(Icons.person),
                        title: Text('Full Name', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        subtitle: Text(userData['displayName'], style: TextStyle(fontSize: 16)),
                        trailing: IconButton(
                          icon: Icon(Icons.edit),
                          onPressed: () => _showUpdateNameDialog(context, userData['displayName']),
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    Card(
                      child: ListTile(
                        leading: Icon(Icons.email),
                        title: Text('Email', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        subtitle: Text(userData['email'], style: TextStyle(fontSize: 16)),
                      ),
                    ),
                    SizedBox(height: 20),
                    Center(
                      child: ElevatedButton(
                        onPressed: () => _logout(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                        ),
                        child: const Text('Logout', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}