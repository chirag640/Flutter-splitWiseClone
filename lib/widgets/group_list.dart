import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:splitwise/widgets/group_details.dart';
import 'package:splitwise/theme.dart';
import 'package:intl/intl.dart';


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

    return RefreshIndicator(
      onRefresh: () async => await Future.delayed(Duration(milliseconds: 300)),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('groups').where('members', arrayContains: user.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView.builder(
              padding: EdgeInsets.all(AppSpacing.md),
              itemCount: 6,
              itemBuilder: (context, i) => Card(
                child: ListTile(
                  leading: CircleAvatar(child: Container(color: Colors.grey.shade800)),
                  title: Container(height: 16, color: Colors.grey.shade800),
                  subtitle: Container(height: 12, color: Colors.grey.shade800),
                ),
              ),
            );
          }

          final groups = snapshot.data!.docs;
          if (groups.isEmpty) {
            return ListView(
              children: [
                SizedBox(height: 80),
                Icon(Icons.group, size: 80, color: Colors.grey),
                SizedBox(height: 20),
                Center(child: Text('No groups yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                SizedBox(height: 8),
                Center(child: Text('Tap + to create a group', style: TextStyle(color: Colors.grey))),
              ],
            );
          }

          return ListView.builder(
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              return Card(
                color: Theme.of(context).cardColor,
                margin: EdgeInsets.all(10),
                child: ListTile(
                  leading: CircleAvatar(child: Text((group['groupName'] as String).substring(0,1).toUpperCase())),
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
                    Navigator.push(context, MaterialPageRoute(builder: (context) => GroupDetailsScreen(groupId: group.id)));
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}