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
  bool _isSubmitting = false;

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  Future<void> _addGroup() async {
    final groupName = _groupNameController.text;
    final user = FirebaseAuth.instance.currentUser;

    if (groupName.isNotEmpty && user != null) {
  if (_isSubmitting) return;
  setState(() => _isSubmitting = true);
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
      if (mounted) {
        setState(() => _isSubmitting = false);
        Navigator.pop(context);
      }
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
    // Bottom sheet style content so this widget can be shown via showModalBottomSheet
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Material(
      color: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: bottomInset),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.55,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Create Group', style: Theme.of(context).textTheme.titleLarge),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: _isSubmitting ? null : () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.close),
                      )
                    ],
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _groupNameController,
                    enabled: !_isSubmitting,
                    decoration: const InputDecoration(
                      labelText: 'Group Name',
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _addGroup,
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: _isSubmitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Save'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}