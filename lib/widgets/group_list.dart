import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:test_firebase/widgets/group_details.dart';

class GroupsList extends StatelessWidget {
  const GroupsList({super.key});

  Future<List<String>> _getGroupMembers(String groupId) async {
    final membersSnapshot = await FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('members')
        .get();
    return membersSnapshot.docs.map((doc) => doc['fullName'] as String).toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Center(child: Text('Please log in to see your groups.'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('groups')
          .where('members', arrayContains: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        final groups = snapshot.data!.docs;

        if (groups.isEmpty) {
          return Center(child: Text('No groups found.'));
        }

        return ListView.builder(
          itemCount: groups.length,
          itemBuilder: (context, index) {
            final group = groups[index];
            return Card(
              margin: EdgeInsets.all(10),
              child: ListTile(
                leading: Icon(Icons.group, size: 40),
                title: Text(group['groupName'], style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                subtitle: FutureBuilder<List<String>>(
                  future: _getGroupMembers(group.id),
                  builder: (context, memberSnapshot) {
                    if (memberSnapshot.connectionState == ConnectionState.waiting) {
                      return Text('Loading members...');
                    }
                    if (memberSnapshot.hasError) {
                      return Text('Error loading members');
                    }
                    final members = memberSnapshot.data ?? [];
                    return Text('Members: ${members.join(', ')}');
                  },
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GroupDetailsScreen(groupId: group.id),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}