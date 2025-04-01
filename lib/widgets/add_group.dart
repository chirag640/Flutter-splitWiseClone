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

  Future<void> _addGroup() async {
    final groupName = _groupNameController.text;
    final user = FirebaseAuth.instance.currentUser;

    if (groupName.isNotEmpty && user != null) {
      final userSnapshot = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final fullName = userSnapshot.data()?['displayName'] ?? '';
      final token = userSnapshot.data()?['token'] ?? ''; // Fetch the token

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
        'fullName': fullName,
        'token': token, // Save the token
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
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add Group'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _groupNameController,
            decoration: InputDecoration(
              labelText: 'Group Name',
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 20),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text('Cancel'),
        ),
        TextButton(
          onPressed: _addGroup,
          child: Text('Add Group'),
        ),
      ],
    );
  }
}