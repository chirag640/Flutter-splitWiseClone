import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class BalanceScreen extends StatefulWidget {
  const BalanceScreen({super.key});

  @override
  _BalanceScreenState createState() => _BalanceScreenState();
}

class _BalanceScreenState extends State<BalanceScreen> {
  Future<Map<String, double>> _calculateNetBalances() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return {};
    }

    final groupsSnapshot = await FirebaseFirestore.instance
        .collection('groups')
        .where('members', arrayContains: user.uid)
        .get();

    final balances = <String, double>{};

    for (var group in groupsSnapshot.docs) {
      final groupId = group.id;
      final expensesSnapshot = await FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .collection('expenses')
          .get();

      for (var expense in expensesSnapshot.docs) {
        final share = expense['share'];
        final createdBy = expense['createdBy'];
        final membersSnapshot = await FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .collection('members')
            .get();

        for (var member in membersSnapshot.docs) {
          final otherMemberId = member['id'];
          final otherMemberName = member['fullName'];
          if (otherMemberId != user.uid) {
            if (createdBy == user.uid) {
              balances[otherMemberName] = (balances[otherMemberName] ?? 0) + share;
            } else if (createdBy == otherMemberId) {
              balances[otherMemberName] = (balances[otherMemberName] ?? 0) - share;
            }
          }
        }
      }
    }

    return balances;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<Map<String, double>>(
        future: _calculateNetBalances(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final balances = snapshot.data ?? {};
          if (balances.isEmpty) {
            return Center(child: Text('No balances found.'));
          }

          return ListView.builder(
            itemCount: balances.length,
            itemBuilder: (context, index) {
              final entry = balances.entries.elementAt(index);
              final memberName = entry.key;
              final balance = entry.value;
              return Card(
                margin: EdgeInsets.all(10),
                child: ListTile(
                  title: Text(memberName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    balance >= 0
                        ? 'You lent $balance to $memberName'
                        : 'You borrowed ${-balance} from $memberName',
                    style: TextStyle(
                      color: balance >= 0 ? Colors.green : Colors.red,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}