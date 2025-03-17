import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:test_firebase/model/expense.dart';

class ExpensesList extends StatefulWidget {
  const ExpensesList({super.key});

  @override
  _ExpensesListState createState() => _ExpensesListState();
}

class _ExpensesListState extends State<ExpensesList> {
  final CollectionReference _expensesCollection =
      FirebaseFirestore.instance.collection('expenses');

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Center(child: Text('Please log in to see your expenses.'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream:
          _expensesCollection.where('paidBy', isEqualTo: user.uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        final expenses = snapshot.data!.docs
            .map((doc) =>
                Expense.fromMap(doc.id, doc.data() as Map<String, dynamic>))
            .toList();

        if (expenses.isEmpty) {
          return Center(child: Text('No expenses found.'));
        }

        return ListView.builder(
          itemCount: expenses.length,
          itemBuilder: (context, index) {
            final expense = expenses[index];
            return ListTile(
              title: Text(
                expense.description,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              subtitle: Text('Amount: ${expense.amount.toStringAsFixed(2)}'),
              trailing: IconButton(
                icon: Icon(Icons.delete),
                onPressed: () async {
                  final shouldDelete = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('Delete Expense'),
                      content:
                          Text('Are you sure you want to delete this expense?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Text('Delete',
                              style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );

                  if (shouldDelete == true) {
                    await _expensesCollection.doc(expense.id).delete();
                  }
                },
              ),
            );
          },
        );
      },
    );
  }
}
