import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:splitwise/model/expense.dart';
import 'package:intl/intl.dart';
import 'package:splitwise/theme.dart';

class ExpensesList extends StatefulWidget {
  const ExpensesList({super.key});

  @override
  _ExpensesListState createState() => _ExpensesListState();
}

class _ExpensesListState extends State<ExpensesList> {
  final CollectionReference _expensesCollection =
      FirebaseFirestore.instance.collection('expenses');

  final TextEditingController _expenseDescriptionController = TextEditingController();
  final TextEditingController _expenseAmountController = TextEditingController();

  @override
  void dispose() {
    _expenseDescriptionController.dispose();
    _expenseAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
  final currencyFormatter = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    if (user == null) {
      return Center(child: Text('Please log in to see your expenses.'));
    }

    return RefreshIndicator(
      onRefresh: () async {
        // StreamBuilder updates automatically; just wait a moment
        await Future.delayed(Duration(milliseconds: 300));
      },
      child: StreamBuilder<QuerySnapshot>(
        stream: _expensesCollection.where('createdBy', isEqualTo: user.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            // simple skeleton loader
            return ListView.builder(
              padding: EdgeInsets.all(AppSpacing.md),
              itemCount: 6,
              itemBuilder: (context, i) => Card(
                child: ListTile(
                  title: Container(height: 16, color: Colors.grey.shade800),
                  subtitle: Container(height: 12, color: Colors.grey.shade800),
                ),
              ),
            );
          }

          final expenses = snapshot.data!.docs
              .map((doc) => Expense.fromMap(doc.id, doc.data() as Map<String, dynamic>))
              .toList();

          if (expenses.isEmpty) {
            return ListView(
              children: [
                SizedBox(height: 80),
                Icon(Icons.receipt_long, size: 80, color: Colors.grey),
                SizedBox(height: 20),
                Center(child: Text('No expenses yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                SizedBox(height: 8),
                Center(child: Text('Tap + to add your first expense', style: TextStyle(color: Colors.grey))),
              ],
            );
          }

          return ListView.builder(
            itemCount: expenses.length,
            itemBuilder: (context, index) {
              final expense = expenses[index];
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
                    _expenseDescriptionController.text = expense.description;
                    _expenseAmountController.text = expense.amount.toString();
                    final shouldUpdate = await showModalBottomSheet<bool>(
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
                                      Expanded(child: Text('Update Expense', style: Theme.of(context).textTheme.titleLarge)),
                                      IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.close))
                                    ]),
                                    const SizedBox(height: 4),
                                    TextField(controller: _expenseDescriptionController, decoration: const InputDecoration(labelText: 'Description'), textInputAction: TextInputAction.next),
                                    const SizedBox(height: 12),
                                    TextField(controller: _expenseAmountController, decoration: const InputDecoration(labelText: 'Amount', prefixText: '\$'), keyboardType: TextInputType.number, textInputAction: TextInputAction.done),
                                    const SizedBox(height: 20),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)), child: const Text('Save')),
                                    )
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                    if (shouldUpdate == true) {
                      await _updateExpense(expense.id, _expenseDescriptionController.text, double.parse(_expenseAmountController.text));
                    }
                    return false;
                    } else if (direction == DismissDirection.endToStart) {
                    // Swipe left to delete
                    final shouldDelete = await showModalBottomSheet<bool>(
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
                              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                                Row(children:[
                                  Expanded(child: Text('Delete Expense', style: Theme.of(context).textTheme.titleLarge)),
                                  IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.close))
                                ]),
                                const SizedBox(height: 8),
                                const Text('Are you sure you want to delete this expense?'),
                                const SizedBox(height: 20),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 14)),
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('Delete'),
                                  ),
                                ),
                              ]),
                            ),
                          ),
                        );
                      },
                    );
                    if (shouldDelete == true) {
                      await _deleteExpense(expense.id);
                      return true;
                    }
                    return false;
                  }
                  return false;
                },
                  child: Card(
                  child: ListTile(
                    title: Text(
                      expense.description,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    trailing: Text(
                      currencyFormatter.format(expense.amount),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: expense.amount >= 0 ? Colors.green : Colors.red,
                      ),
                    ),
                    subtitle: Text(''),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _updateExpense(String expenseId, String description, double amount) async {
    await _expensesCollection.doc(expenseId).update({
      'description': description,
      'amount': amount,
    });
    setState(() {});
  }

  Future<void> _deleteExpense(String expenseId) async {
    await _expensesCollection.doc(expenseId).delete();
    setState(() {});
  }
}