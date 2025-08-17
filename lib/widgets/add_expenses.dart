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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Material(
      color: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: bottomInset),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.55,
            ),
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
                      IconButton(
                        tooltip: 'Close',
                        onPressed: _isSubmitting ? null : () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.close),
                      )
                    ],
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _descriptionController,
                    enabled: !_isSubmitting,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _amountController,
                    enabled: !_isSubmitting,
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      border: OutlineInputBorder(),
                      prefixText: '\$',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting
                          ? null
                          : () async {
                              if (_isSubmitting) return;
                              setState(() => _isSubmitting = true);
                              final description = _descriptionController.text.trim();
                              final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
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
                                  _logger.severe('Error creating top-level expense: $e');
                                  final errorMsg = (e is FirebaseException && e.code == 'permission-denied')
                                      ? 'Permission denied: cannot create expense.'
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
                                  const SnackBar(
                                    content: Text('Enter a description and positive amount'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                              if (mounted) setState(() => _isSubmitting = false);
                            },
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: _isSubmitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Save'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}