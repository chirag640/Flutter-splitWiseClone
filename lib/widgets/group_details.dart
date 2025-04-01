import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:splitwise/services/notification_service.dart';
import 'package:uuid/uuid.dart';

class GroupDetailsScreen extends StatefulWidget {
  final String groupId;

  const GroupDetailsScreen({required this.groupId, super.key});

  @override
  _GroupDetailsScreenState createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _expenseDescriptionController = TextEditingController();
  final TextEditingController _expenseAmountController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _expenseDescriptionController.dispose();
    _expenseAmountController.dispose();
    super.dispose();
  }

  void _addMember() async {
    final email = _emailController.text;
    if (email.isNotEmpty) {
      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .get();
      if (userSnapshot.docs.isNotEmpty) {
        final user = userSnapshot.docs.first;
        final memberId = user['uid'];
        final memberData = {
          'id': memberId,
          'email': email,
          'fullName': user['displayName'],
          'token': user['token'], // Fetch the token from the users collection
          'balance': 0.0, // Initialize balance to 0
        };
        await FirebaseFirestore.instance
            .collection('groups')
            .doc(widget.groupId)
            .collection('members')
            .doc(memberId)
            .set(memberData);
        await FirebaseFirestore.instance
            .collection('groups')
            .doc(widget.groupId)
            .update({
          'members': FieldValue.arrayUnion([memberId])
        });
        _emailController.clear();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User not found'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter an email'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _addExpense() async {
    final description = _expenseDescriptionController.text;
    final amount = double.tryParse(_expenseAmountController.text) ?? 0.0;
    final user = FirebaseAuth.instance.currentUser;

    if (description.isNotEmpty && amount > 0 && user != null) {
      final expenseId = Uuid().v4();
      final membersSnapshot = await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('members')
          .get();
      final members = membersSnapshot.docs;
      final share = (amount / members.length).ceil();

      final expenseData = {
        'id': expenseId,
        'description': description,
        'amount': amount,
        'createdBy': user.uid,
        'createdAt': Timestamp.now(),
        'share': share,
      };

      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('expenses')
          .doc(expenseId)
          .set(expenseData);

      List<String> tokens = [];
      for (var member in members) {
        final memberId = member['id'];
        if (memberId != user.uid) {
          tokens.add(member['token']); // Collect tokens for notifications
        }
        await FirebaseFirestore.instance
            .collection('groups')
            .doc(widget.groupId)
            .collection('members')
            .doc(memberId)
            .update({
          'balance': FieldValue.increment(-share),
        });
      }

      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('members')
          .doc(user.uid)
          .update({
        'balance': FieldValue.increment(amount),
      });

      // Send notifications
      try {
         final notificationService = NotificationService();
      await notificationService.sendNotificationToMultiple(
        tokens: tokens,
        title: "New Expense Added",
        body: "$description added by ${user.displayName}. Your share: $share",
      );
      print("successfully sending notification");
      } catch (e) {
        print("Error sending notification: $e");

      } 
     

      _expenseDescriptionController.clear();
      _expenseAmountController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a valid description and amount'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _deleteExpense(String expenseId, double amount, String createdBy) async {
    final membersSnapshot = await FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .collection('members')
        .get();
    final members = membersSnapshot.docs;
    final share = (amount / members.length).ceil();

    for (var member in members) {
      final memberId = member['id'];
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('members')
          .doc(memberId)
          .update({
        'balance': FieldValue.increment(share),
      });
    }

    await FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .collection('members')
        .doc(createdBy)
        .update({
      'balance': FieldValue.increment(-amount),
    });

    await FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .collection('expenses')
        .doc(expenseId)
        .delete();

    setState(() {}); // Trigger a rebuild to update the UI
  }

  void _updateExpense(String expenseId, String description, double amount) async {
    final user = FirebaseAuth.instance.currentUser;
    if (description.isNotEmpty && amount > 0 && user != null) {
      final membersSnapshot = await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('members')
          .get();
      final members = membersSnapshot.docs;
      final share = (amount / members.length).ceil();

      final expenseData = {
        'description': description,
        'amount': amount,
        'share': share,
      };

      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('expenses')
          .doc(expenseId)
          .update(expenseData);

      for (var member in members) {
        final memberId = member['id'];
        await FirebaseFirestore.instance
            .collection('groups')
            .doc(widget.groupId)
            .collection('members')
            .doc(memberId)
            .update({
          'balance': FieldValue.increment(-share),
        });
      }

      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('members')
          .doc(user.uid)
          .update({
        'balance': FieldValue.increment(amount),
      });

      setState(() {}); // Trigger a rebuild to update the UI
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a valid description and amount'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<String> _getUserName(String userId) async {
    final userSnapshot = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    return userSnapshot.data()?['displayName'] ?? 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: header(context),
      body: Column(
        children: [
          users(),
          Text('Expenses', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          expenses(),
        ],
      ),
      floatingActionButton: addBtn(context),
    );
  }

  FloatingActionButton addBtn(BuildContext context) {
    return FloatingActionButton(
      backgroundColor: Colors.green,
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Add Expense'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _expenseDescriptionController,
                  decoration: InputDecoration(labelText: 'Description'),
                ),
                TextField(
                  controller: _expenseAmountController,
                  decoration: InputDecoration(labelText: 'Amount'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  _addExpense();
                  Navigator.pop(context);
                },
                child: Text('Add'),
              ),
            ],
          ),
        );
      },
      child: Icon(Icons.add),
    );
  }

  Expanded expenses() {
    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('groups')
            .doc(widget.groupId)
            .collection('expenses')
            .orderBy('createdAt', descending: true) // Order by creation timestamp in descending order
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final expenses = snapshot.data!.docs;

          return ListView.builder(
            itemCount: expenses.length,
            itemBuilder: (context, index) {
              final expense = expenses[index];
              final user = FirebaseAuth.instance.currentUser;

              if (expense['createdBy'] == user?.uid) {
                return Dismissible(
                  key: Key(expense.id),
                  background: Container(
                    color: Colors.green,
                    alignment: Alignment.centerLeft,
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Icon(Icons.edit, color: Colors.white),
                  ),
                  secondaryBackground: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (direction) async {
                    if (direction == DismissDirection.startToEnd) {
                      // Swipe right to update
                      _expenseDescriptionController.text = expense['description'];
                      _expenseAmountController.text = expense['amount'].toString();
                      final shouldUpdate = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('Update Expense'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(
                                controller: _expenseDescriptionController,
                                decoration: InputDecoration(labelText: 'Description'),
                              ),
                              TextField(
                                controller: _expenseAmountController,
                                decoration: InputDecoration(labelText: 'Amount'),
                                keyboardType: TextInputType.number,
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: Text('Update'),
                            ),
                          ],
                        ),
                      );
                      if (shouldUpdate == true) {
                        _updateExpense(expense.id, _expenseDescriptionController.text, double.parse(_expenseAmountController.text));
                      }
                      return false;
                    } else if (direction == DismissDirection.endToStart) {
                      // Swipe left to delete
                      final shouldDelete = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('Delete Expense'),
                          content: Text('Are you sure you want to delete this expense?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: Text('Delete', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                      if (shouldDelete == true) {
                        _deleteExpense(expense.id, expense['amount'], expense['createdBy']);
                        return true;
                      }
                      return false;
                    }
                    return false;
                  },
                  child: Card(
                    margin: EdgeInsets.all(10),
                    child: ListTile(
                      leading: Icon(Icons.receipt, color: Colors.blue),
                      title: Text(expense['description'], style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      subtitle: FutureBuilder<String>(
                        future: _getUserName(expense['createdBy']),
                        builder: (context, userSnapshot) {
                          if (userSnapshot.connectionState == ConnectionState.waiting) {
                            return Text('Loading...');
                          }
                          if (userSnapshot.hasError) {
                            return Text('Error: ${userSnapshot.error}');
                          }
                          final userName = userSnapshot.data ?? 'Unknown';
                          return RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Amount: ',
                                  style: TextStyle(color: Colors.white),
                                ),
                                TextSpan(
                                  text: '${expense['amount']}',
                                  style: TextStyle(color: Colors.green),
                                ),
                                TextSpan(
                                  text: ' Paid By ',
                                  style: TextStyle(color: Colors.white),
                                ),
                                TextSpan(
                                  text: userName,
                                  style: TextStyle(color: Colors.green),
                                ),
                                TextSpan(
                                  text: '\nShare: ',
                                  style: TextStyle(color: Colors.white),
                                ),
                                TextSpan(
                                  text: '${expense['share']}',
                                  style: TextStyle(color: Colors.blue),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              } else {
                return Card(
                  margin: EdgeInsets.all(10),
                  child: ListTile(
                    leading: Icon(Icons.receipt, color: Colors.blue),
                    title: Text(expense['description'], style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    subtitle: FutureBuilder<String>(
                      future: _getUserName(expense['createdBy']),
                      builder: (context, userSnapshot) {
                        if (userSnapshot.connectionState == ConnectionState.waiting) {
                          return Text('Loading...');
                        }
                        if (userSnapshot.hasError) {
                          return Text('Error: ${userSnapshot.error}');
                        }
                        final userName = userSnapshot.data ?? 'Unknown';
                        return RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: 'Amount: ',
                                style: TextStyle(color: Colors.white),
                              ),
                              TextSpan(
                                text: '${expense['amount']}',
                                style: TextStyle(color: Colors.green),
                              ),
                              TextSpan(
                                text: ' Paid By ',
                                style: TextStyle(color: Colors.white),
                              ),
                              TextSpan(
                                text: userName,
                                style: TextStyle(color: Colors.green),
                              ),
                              TextSpan(
                                text: '\nShare: ',
                                style: TextStyle(color: Colors.white),
                              ),
                              TextSpan(
                                text: '${expense['share']}',
                                style: TextStyle(color: Colors.blue),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }

  Expanded users() {
    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('groups')
            .doc(widget.groupId)
            .collection('members')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final members = snapshot.data!.docs;

          return ListView.builder(
            itemCount: members.length,
            itemBuilder: (context, index) {
              final member = members[index];
              return Card(
                margin: EdgeInsets.all(10),
                child: ListTile(
                  title: Text(member['fullName'], style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  subtitle: FutureBuilder<Map<String, double>>(
                    future: _getMemberBalances(member['id']),
                    builder: (context, balanceSnapshot) {
                      if (balanceSnapshot.connectionState == ConnectionState.waiting) {
                        return Text('Loading...');
                      }
                      if (balanceSnapshot.hasError) {
                        return Text('Error: ${balanceSnapshot.error}');
                      }
                      final balances = balanceSnapshot.data ?? {};
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: balances.entries.map((entry) {
                          final otherMemberName = entry.key;
                          final balance = entry.value;
                          return Text(
                            balance >= 0
                                ? 'You lent $balance to $otherMemberName'
                                : 'You borrowed ${-balance} from $otherMemberName',
                            style: TextStyle(
                              color: balance >= 0 ? Colors.green : Colors.red,
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<Map<String, double>> _getMemberBalances(String memberId) async {
    final expensesSnapshot = await FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .collection('expenses')
        .get();

    final balances = <String, double>{};
    for (var expense in expensesSnapshot.docs) {
      final share = expense['share'];
      final createdBy = expense['createdBy'];
      final membersSnapshot = await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('members')
          .get();

      for (var member in membersSnapshot.docs) {
        final otherMemberId = member['id'];
        final otherMemberName = member['fullName'];
        if (otherMemberId != memberId) {
          if (createdBy == memberId) {
            balances[otherMemberName] = (balances[otherMemberName] ?? 0) + share;
          } else if (createdBy == otherMemberId) {
            balances[otherMemberName] = (balances[otherMemberName] ?? 0) - share;
          }
        }
      }
    }

    return balances;
  }

  AppBar header(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.black,
      title: Text('Group Details'),
      actions: [
        IconButton(
          icon: Icon(Icons.person_add),
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('Add Member'),
                content: TextField(
                  controller: _emailController,
                  decoration: InputDecoration(labelText: 'Email'),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () {
                      _addMember();
                      Navigator.pop(context);
                    },
                    child: Text('Add'),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}