import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:logging/logging.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  final Logger _logger = Logger('AddExpenseScreen');

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add Expense'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
            TextField(
              controller: _descriptionController,
              enabled: !_isSubmitting,
              decoration: InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _amountController,
              enabled: !_isSubmitting,
              decoration: InputDecoration(
                labelText: 'Amount',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          SizedBox(height: 20),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isSubmitting ? null : () {
            Navigator.of(context).pop();
          },
          child: Text('Cancel'),
        ),
        TextButton(
          onPressed: _isSubmitting ? null : () async {
            if (_isSubmitting) return;
            setState(() => _isSubmitting = true);
            final description = _descriptionController.text;
            final amount = double.tryParse(_amountController.text) ?? 0.0;
            final user = FirebaseAuth.instance.currentUser;
            if (description.isNotEmpty && amount > 0 && user != null) {
              final expenseId = Uuid().v4();
              final expenseData = {
                'id': expenseId,
                'description': description,
                'amount': amount,
                'createdBy': user.uid,
                'createdAt': Timestamp.now(),
              };
              try {
                await FirebaseFirestore.instance.collection('expenses').doc(expenseId).set(expenseData);
                if (mounted) Navigator.of(context).pop();
              } catch (e) {
                // Handle permission errors gracefully to avoid app crash
                _logger.severe('Error creating top-level expense: $e');
                final errorMsg = (e is FirebaseException && e.code == 'permission-denied')
                    ? 'Permission denied: cannot create expense. Check Firestore rules.'
                    : 'Failed to create expense: ${e.toString()}';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(errorMsg),
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
            if (mounted) setState(() => _isSubmitting = false);
          },
          child: _isSubmitting ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text('Save'),
        ),
      ],
    );
  }
}