import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

class AddGroupScreen extends StatefulWidget {
  const AddGroupScreen({super.key});

  @override
  State<AddGroupScreen> createState() => _AddGroupScreenState();
}

class _AddGroupScreenState extends State<AddGroupScreen> {
  final TextEditingController _groupNameController = TextEditingController();

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Group'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _groupNameController,
              decoration: InputDecoration(labelText: 'Group Name'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final groupName = _groupNameController.text;
                final user = FirebaseAuth.instance.currentUser;
                if (groupName.isNotEmpty && user != null) {
                  final groupId = Uuid().v4();
                  final groupData = {
                    'id': groupId,
                    'groupName': groupName,
                    'createdBy': user.uid,
                    'members': [user.uid], // Add the current user as a member
                  };
                  await FirebaseFirestore.instance.collection('groups').doc(groupId).set(groupData);

                  final memberData = {
                    'id': user.uid,
                    'email': user.email,
                    'fullName': user.displayName ?? '',
                    'balance': 0.0,
                  };
                  await FirebaseFirestore.instance
                      .collection('groups')
                      .doc(groupId)
                      .collection('members')
                      .doc(user.uid)
                      .set(memberData);

                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Please enter a group name'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: Text('Add Group'),
            ),
          ],
        ),
      ),
    );
  }
}