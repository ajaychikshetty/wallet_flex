import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AddExpensePage extends StatefulWidget {
  const AddExpensePage({super.key});

  @override
  _AddExpensePageState createState() => _AddExpensePageState();
}

class _AddExpensePageState extends State<AddExpensePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  // Add these new variables to track recurring state
  bool _isRecurring = false;
  String _recurringType =
      'daily'; // We can expand this later for weekly/monthly

  final List<String> _recurringOptions = ['daily', 'weekly', 'monthly'];

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Expense'),
      ),
      body: Padding(
        padding: EdgeInsets.all(screenWidth * 0.05),
        child: Column(
          children: [
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount',
                hintText: 'Enter expense amount',
              ),
            ),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Enter expense description',
              ),
            ),
            SizedBox(height: screenHeight * 0.02),
            Row(
              children: [
                Text(
                  "Selected Date: ${DateFormat('EEE, dd MMM').format(_selectedDate)}",
                ),
                IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () => _selectDate(context),
                ),
              ],
            ),

            // Add the checkbox for recurring expenses
            Row(
              children: [
                Checkbox(
                  value: _isRecurring,
                  onChanged: (bool? value) {
                    setState(() {
                      _isRecurring = value ?? false;
                      if (!_isRecurring) {
                        _recurringType =
                            'daily'; // Reset to default when unchecked
                      }
                    });
                  },
                ),
                const Text('Make this a recurring expense'),
              ],
            ),
            if (_isRecurring) // Only show when recurring is checked
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    const SizedBox(
                        width: 32), // Indent to align with checkbox text
                    const Text('Recurrence: '),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _recurringType,
                      items: _recurringOptions.map((String type) {
                        return DropdownMenuItem<String>(
                          value: type,
                          child: Text(type
                              .capitalize()), // Add the capitalize extension below
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _recurringType = newValue;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),

            SizedBox(height: screenHeight * 0.02),
            ElevatedButton(
              onPressed: () async {
                final String userId = _auth.currentUser!.uid;
                final String formattedDate =
                    DateFormat('EEE, dd MMM').format(_selectedDate);
                final double amount =
                    double.tryParse(_amountController.text) ?? 0;
                final String description = _descriptionController.text;

                try {
                  // Add to expenses collection
                  await _firestore
                      .collection('user_details')
                      .doc(userId)
                      .collection('expenses')
                      .add({
                    'amount': amount,
                    'description': description,
                    'date': formattedDate,
                    'timestamp': DateTime.now().toIso8601String(),
                    'type': 'expense',
                    'isRecurring': _isRecurring,
                  });

                  // If it's a recurring expense, add to recurring_pay collection
                  if (_isRecurring) {
                    await _firestore
                        .collection('user_details')
                        .doc(userId)
                        .collection('recurring_pay')
                        .add({
                      'amount': amount,
                      'description': description,
                      'startDate': DateTime.now().toIso8601String(),
                      'recurrence':
                          _recurringType, // This will now be 'daily', 'weekly', or 'monthly'
                      'isActive': true,
                      'lastProcessed': DateTime.now()
                          .toIso8601String(), // Add this to track last processing
                    });
                  }

                  // Add to transactions collection
                  await _firestore
                      .collection('user_details')
                      .doc(userId)
                      .collection('transactions')
                      .add({
                    'amount': amount,
                    'date': formattedDate,
                    'timestamp': DateTime.now().toIso8601String(),
                    'tname': description,
                    'type': 'expense',
                    'isRecurring': _isRecurring,
                  });

                  // Update balance
                  final QuerySnapshot balanceSnapshot = await _firestore
                      .collection('user_details')
                      .doc(userId)
                      .collection('balance')
                      .where('date', isEqualTo: formattedDate)
                      .get();

                  if (balanceSnapshot.docs.isNotEmpty) {
                    final DocumentSnapshot balanceDoc =
                        balanceSnapshot.docs.first;
                    final double existingBalance = balanceDoc['amount'];
                    final double newBalance = existingBalance - amount;

                    await _firestore
                        .collection('user_details')
                        .doc(userId)
                        .collection('balance')
                        .doc(balanceDoc.id)
                        .update({'amount': newBalance});
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_isRecurring
                          ? 'Recurring expense added successfully'
                          : 'Expense added successfully'),
                    ),
                  );
                  Navigator.of(context).pop();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to add expense: $e')),
                  );
                }
              },
              child: const Text('Add Expense'),
            ),
          ],
        ),
      ),
    );
  }
}

// Add this extension for capitalizing strings
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
