import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:splitwise/theme.dart';

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
    final currencyFormatter = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    return Scaffold(
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
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.account_balance_wallet, size: 64, color: Colors.grey),
              SizedBox(height: 12),
              Text('No balances found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Text('Create or join a group to start tracking balances', style: TextStyle(color: Colors.grey)),
            ]));
          }

          return RefreshIndicator(
            onRefresh: () async => await Future.delayed(Duration(milliseconds: 300)),
            child: ListView.builder(
              itemCount: balances.length,
              itemBuilder: (context, index) {
                final entry = balances.entries.elementAt(index);
                final memberName = entry.key;
                final balance = entry.value;
                final isPositive = balance >= 0;
                return Card(
                  margin: EdgeInsets.all(10),
                  child: ListTile(
                    title: Text(memberName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(isPositive ? Icons.arrow_upward : Icons.arrow_downward, color: isPositive ? Colors.green : Colors.red, size: 18),
                      SizedBox(width: 8),
                      Text(
                        currencyFormatter.format(isPositive ? balance : -balance),
                        style: TextStyle(color: isPositive ? Colors.green : Colors.red, fontWeight: FontWeight.w600),
                      ),
                    ]),
                    subtitle: Text(isPositive ? 'You are owed' : 'You owe', style: TextStyle(color: isPositive ? Colors.green : Colors.red)),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}