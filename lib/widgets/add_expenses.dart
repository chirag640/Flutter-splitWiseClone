import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:test_firebase/model/expense.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

class AddExpenseScreen extends StatefulWidget {

  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

 @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Expense'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(labelText: 'Description'),
            ),
            TextField(
              controller: _amountController,
              decoration: InputDecoration(labelText: 'Amount'),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                print('Add Expense button clicked');
                final description = _descriptionController.text;
                final amount = double.tryParse(_amountController.text) ?? 0.0;
                if (description.isNotEmpty && amount > 0) {
                  print('Description: $description, Amount: $amount');
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    try {
                      print('User is logged in');
                      final expense = Expense(
                      id: Uuid().v4(),
                      userId: user.uid,
                      description: description,
                      amount: amount,
                    );
                    await FirebaseFirestore.instance.collection('expenses').add(expense.toMap());
                    Navigator.pop(context, expense);
                    }on FirebaseAuthException catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(e.message ?? 'An error occurred'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('User not logged in'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Please enter a valid description and amount'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: Text('Add Expense'),
            ),
          ],
        ),
      ),
    );
  }
}