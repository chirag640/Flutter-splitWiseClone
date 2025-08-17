import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:splitwise/services/notification_service.dart';
import 'package:uuid/uuid.dart';
import 'package:logging/logging.dart';

class GroupDetailsScreen extends StatefulWidget {
  final String groupId;

  const GroupDetailsScreen({required this.groupId, super.key});

  @override
  _GroupDetailsScreenState createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
  final Logger _logger = Logger('GroupDetailsScreen');
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
      // Fetch the group name
      final groupSnapshot = await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .get();
      final groupName = groupSnapshot.data()?['groupName'] ?? 'Unknown Group';

      // Ensure the user's display name is not null
      String userName = user.displayName ?? '';
      if (userName.isEmpty) {
        final userSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        userName = userSnapshot.data()?['displayName'] ?? 'Unknown User';
      }

      final expenseId = Uuid().v4();
      final membersSnapshot = await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('members')
          .get();
      final members = membersSnapshot.docs;

      if (members.isEmpty) {
        // No members to split with — prevent division by zero and inform the user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No members in group to split the expense.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Distribute amount in integer cents to avoid floating point rounding errors.
      final int amountCents = (amount * 100).round();
      final int n = members.length;
      final int baseShare = amountCents ~/ n; // integer cents per member
      final int remainder = amountCents % n; // extra cents to distribute

      // Store base share as double and remainder for traceability
      final expenseData = {
        'id': expenseId,
        'description': description,
        'amount': amount,
        'createdBy': user.uid,
        'createdAt': Timestamp.now(),
        'share': baseShare / 100.0,
        'share_remainder_cents': remainder,
      };

      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('expenses')
          .doc(expenseId)
          .set(expenseData);

      List<String> tokens = [];
      final List<Future> updateFutures = [];
      // Distribute cents fairly: the first `remainder` members get +1 cent
      for (int i = 0; i < members.length; i++) {
        final member = members[i];
        final memberId = member['id'];
        if (memberId != user.uid) {
          tokens.add(member['token']); // Collect tokens for notifications
        }

        final int memberShareCents = baseShare + (i < remainder ? 1 : 0);
        final double memberShare = memberShareCents / 100.0;

        updateFutures.add(FirebaseFirestore.instance
            .collection('groups')
            .doc(widget.groupId)
            .collection('members')
            .doc(memberId)
            .update({
          'balance': FieldValue.increment(-memberShare),
        }));
      }

      // Credit the payer with the total amount
      updateFutures.add(FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('members')
          .doc(user.uid)
          .update({
        'balance': FieldValue.increment(amount),
      }));

      try {
        await Future.wait(updateFutures);
      } catch (e) {
        _logger.severe('Error updating member balances: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to apply expense updates. Check permissions.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

    // Compute display share for notifications
    final double displayShare = (baseShare / 100.0);

    // Send notifications
      try {
        final notificationService = NotificationService();
        await notificationService.sendNotificationToMultiple(
          tokens: tokens,
      title: "New Expense Added to $groupName",
      body: "$description added by $userName. Your share: ${displayShare.toStringAsFixed(2)}",
        );
  _logger.info('Successfully sent notification');
      } catch (e) {
  _logger.severe('Error sending notification: $e');
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
    // Fetch the expense doc to obtain distribution details
    final expenseDoc = await FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .collection('expenses')
        .doc(expenseId)
        .get();

    if (!expenseDoc.exists) {
      // Nothing to do
      return;
    }

    final expenseData = expenseDoc.data() ?? {};
    final double expenseAmount = (expenseData['amount'] is num)
        ? (expenseData['amount'] as num).toDouble()
        : double.tryParse('${expenseData['amount']}') ?? amount;

    // Load members once
    final membersSnapshot = await FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .collection('members')
        .get();
    final members = membersSnapshot.docs;

    if (members.isEmpty) return;

    // Determine distribution: prefer stored cents remainder if available
    int amountCents = (expenseAmount * 100).round();
    int baseShare = (expenseData['share'] is num)
        ? ((expenseData['share'] as num) * 100).round() ~/ members.length
        : amountCents ~/ members.length;
    int remainder = expenseData['share_remainder_cents'] ?? (amountCents % members.length);

    // Reverse updates in parallel
    final List<Future> updateFutures = [];
    for (int i = 0; i < members.length; i++) {
      final member = members[i];
      final memberId = member['id'];
      final int memberShareCents = baseShare + (i < remainder ? 1 : 0);
      final double memberShare = memberShareCents / 100.0;

      updateFutures.add(FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('members')
          .doc(memberId)
          .update({
        // Revert the member's balance by adding back their share
        'balance': FieldValue.increment(memberShare),
      }));
    }

    // Debit the creator by the expense amount (revert credit)
    updateFutures.add(FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .collection('members')
        .doc(createdBy)
        .update({
      'balance': FieldValue.increment(-expenseAmount),
    }));

    try {
      await Future.wait(updateFutures);
    } catch (e) {
      _logger.severe('Error reverting expense deletion updates: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to revert expense deletion. Check permissions.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

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
      // Fetch existing expense to compute previous distribution
      final expenseDoc = await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('expenses')
          .doc(expenseId)
          .get();

      if (!expenseDoc.exists) {
        // If expense not found, nothing to update
        return;
      }

      final oldData = expenseDoc.data() ?? {};
      final double oldAmount = (oldData['amount'] is num)
          ? (oldData['amount'] as num).toDouble()
          : double.tryParse('${oldData['amount']}') ?? 0.0;

      // Load members once
      final membersSnapshot = await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('members')
          .get();
      final members = membersSnapshot.docs;
      if (members.isEmpty) return;

      // Compute old distribution
      final int oldAmountCents = (oldAmount * 100).round();
      final int n = members.length;
      final int oldBaseShare = oldAmountCents ~/ n;
      final int oldRemainder = oldData['share_remainder_cents'] ?? (oldAmountCents % n);

      // Compute new distribution
      final int newAmountCents = (amount * 100).round();
      final int newBaseShare = newAmountCents ~/ n;
      final int newRemainder = newAmountCents % n;

      // Prepare parallel updates: for each member compute delta = newShare - oldShare
      final List<Future> updateFutures = [];
      for (int i = 0; i < members.length; i++) {
        final member = members[i];
        final memberId = member['id'];

        final int oldShareCents = oldBaseShare + (i < oldRemainder ? 1 : 0);
        final int newShareCents = newBaseShare + (i < newRemainder ? 1 : 0);
        final double delta = (newShareCents - oldShareCents) / 100.0;

        // Decrease or increase member balance by delta (payer direction handled below)
        updateFutures.add(FirebaseFirestore.instance
            .collection('groups')
            .doc(widget.groupId)
            .collection('members')
            .doc(memberId)
            .update({
          'balance': FieldValue.increment(-delta),
        }));
      }

      // Adjust payer balance by difference between new total and old total
      final double payerDelta = amount - oldAmount; // positive if payer should be credited more
      updateFutures.add(FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('members')
          .doc(user.uid)
          .update({
        'balance': FieldValue.increment(payerDelta),
      }));

      // Update expense doc
      updateFutures.add(FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('expenses')
          .doc(expenseId)
          .update({
        'description': description,
        'amount': amount,
        'share': newBaseShare / 100.0,
        'share_remainder_cents': newRemainder,
      }));

      try {
        await Future.wait(updateFutures);
      } catch (e) {
        _logger.severe('Error updating expense and balances: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update expense. Check permissions.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

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

  void _deleteGroup() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You are not authorized to delete this group'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final groupSnapshot = await FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .get();

    if (!groupSnapshot.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Group does not exist'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final groupData = groupSnapshot.data();
    final createdBy = groupData?['createdBy'];
    final expensesSnapshot = await FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .collection('expenses')
        .get();

    if (createdBy != user.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Only the group creator can delete this group'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (expensesSnapshot.docs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot delete group with existing expenses'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await FirebaseFirestore.instance.collection('groups').doc(widget.groupId).delete();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Group deleted successfully'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pop(context); // Navigate back after deletion
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
      tooltip: 'Add expense',
      backgroundColor: Theme.of(context).colorScheme.primary,
      onPressed: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
          builder: (context) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return Material(
              color: Theme.of(context).cardColor,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              child: SafeArea(
                top: false,
                child: AnimatedPadding(
                  padding: EdgeInsets.only(bottom: bottomInset),
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
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
                            Expanded(child: Text('Add Expense', style: Theme.of(context).textTheme.titleLarge)),
                            IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.close))
                          ],
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _expenseDescriptionController,
                          decoration: const InputDecoration(labelText: 'Description'),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _expenseAmountController,
                          decoration: const InputDecoration(labelText: 'Amount', prefixText: '\$'),
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () { _addExpense(); Navigator.pop(context); },
                            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                            child: const Text('Save'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
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
                  subtitle: FutureBuilder<Map<String, Map<String, dynamic>>>(
                    future: _getMemberBalances(member['id']),
                    builder: (context, balanceSnapshot) {
                      if (balanceSnapshot.connectionState == ConnectionState.waiting) {
                        return Text('Loading...');
                      }
                      if (balanceSnapshot.hasError) {
                        return Text('Error: ${balanceSnapshot.error}');
                      }
                      final balances = balanceSnapshot.data ?? {};
                      // balances: { otherMemberId: { 'displayName': name, 'balance': value } }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
              children: balances.entries.map((entry) {
                final info = entry.value;
                          final otherMemberName = info['displayName'] ?? 'Unknown';
                          final balance = (info['balance'] is num) ? (info['balance'] as num).toDouble() : 0.0;
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

  /// Returns a map keyed by other memberId. Each value contains displayName and balance
  /// { otherMemberId: { 'displayName': name, 'balance': value } }
  Future<Map<String, Map<String, dynamic>>> _getMemberBalances(String memberId) async {
    final expensesSnapshot = await FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .collection('expenses')
        .get();

    final membersSnapshot = await FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .collection('members')
        .get();

    final members = <String, String>{}; // id -> displayName
    for (var m in membersSnapshot.docs) {
      final id = m['id'] as String? ?? '';
      final name = m['fullName'] as String? ?? 'Unknown';
      if (id.isNotEmpty) members[id] = name;
    }

    final balances = <String, Map<String, dynamic>>{};

    for (var otherId in members.keys) {
      if (otherId == memberId) continue;
      balances[otherId] = {'displayName': members[otherId], 'balance': 0.0};
    }

    for (var expense in expensesSnapshot.docs) {
      final share = (expense['share'] is num) ? (expense['share'] as num).toDouble() : 0.0;
      final createdBy = expense['createdBy'] as String? ?? '';

      for (var otherId in members.keys) {
        if (otherId == memberId) continue;
        // If the memberId created the expense, others owe positive share to them
        if (createdBy == memberId) {
          balances[otherId]!['balance'] = (balances[otherId]!['balance'] as double) + share;
        } else if (createdBy == otherId) {
          // If someone else created the expense, memberId owes negative share
          balances[otherId]!['balance'] = (balances[otherId]!['balance'] as double) - share;
        }
      }
    }

    return balances;
  }

  AppBar header(BuildContext context) {
    return AppBar(
      backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      title: Text('Group Details'),
      actions: [
        IconButton(
          icon: Icon(Icons.person_add),
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
              builder: (context) {
                final bottomInset = MediaQuery.of(context).viewInsets.bottom;
                return Material(
                  color: Theme.of(context).cardColor,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                  child: SafeArea(
                    top: false,
                    child: AnimatedPadding(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      padding: EdgeInsets.only(bottom: bottomInset),
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
                            Row(children: [
                              Expanded(child: Text('Add Member', style: Theme.of(context).textTheme.titleLarge)),
                              IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.close))
                            ]),
                            const SizedBox(height: 4),
                            TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email'), textInputAction: TextInputAction.done),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () { _addMember(); Navigator.pop(context); },
                                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                                child: const Text('Save'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
        IconButton(
          icon: Icon(Icons.delete),
          onPressed: () {
            showModalBottomSheet(
              context: context,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
              builder: (context) {
                return Material(
                  color: Theme.of(context).cardColor,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                  child: SafeArea(
                    top: false,
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
                          Row(children: [
                            Expanded(child: Text('Delete Group', style: Theme.of(context).textTheme.titleLarge)),
                            IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.close))
                          ]),
                          const SizedBox(height: 4),
                          const Text('Are you sure you want to delete this group?'),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 14)),
                              onPressed: () { _deleteGroup(); Navigator.pop(context); },
                              child: const Text('Delete'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}