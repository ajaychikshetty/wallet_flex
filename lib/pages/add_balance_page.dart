import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AddBalancePage extends StatefulWidget {
  @override
  _AddBalancePageState createState() => _AddBalancePageState();
}

class _AddBalancePageState extends State<AddBalancePage> {
  final TextEditingController _amountController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  DateTime _selectedDate = DateTime.now();

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
        title: Text('Add Balance'),
      ),
      body: Padding(
        padding: EdgeInsets.all(screenWidth * 0.05),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  "Selected Date: ${DateFormat('EEE, dd MMM').format(_selectedDate)}",
                ),
                IconButton(
                  icon: Icon(Icons.calendar_today),
                  onPressed: () => _selectDate(context),
                ),
              ],
            ),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Amount',
                hintText: 'Enter balance amount',
              ),
            ),
            SizedBox(height: screenHeight * 0.02),
            SizedBox(height: screenHeight * 0.02),
            ElevatedButton(
              onPressed: () async {
                final String userId = _auth.currentUser!.uid;
                final String formattedDate =
                    DateFormat('EEE, dd MMM').format(_selectedDate);
                final double amount =
                    double.tryParse(_amountController.text) ?? 0;

                try {
                  final CollectionReference balanceRef = _firestore
                      .collection('user_details')
                      .doc(userId)
                      .collection('balance');

                  // Check if an entry for the selected date already exists
                  final QuerySnapshot querySnapshot = await balanceRef
                      .where('date', isEqualTo: formattedDate)
                      .get();

                  if (querySnapshot.docs.isNotEmpty) {
                    // Update existing balance
                    final DocumentSnapshot documentSnapshot =
                        querySnapshot.docs.first;
                    final double existingAmount = documentSnapshot['amount'];
                    final double newAmount = existingAmount + amount;

                    await balanceRef
                        .doc(documentSnapshot.id)
                        .update({'amount': newAmount});
                  } else {
                    // Add new balance record
                    await balanceRef.add({
                      'amount': amount,
                      'date': formattedDate,
                      'timestamp': DateTime.now().toIso8601String(),
                    });
                  }

                  // Save transaction record
                  final CollectionReference transactionsRef = _firestore
                      .collection('user_details')
                      .doc(userId)
                      .collection('transactions');

                  await transactionsRef.add({
                    'amount': amount,
                    'date': formattedDate,
                    'tname': 'Balance Addition', // Customize as needed
                    'type': 'income', // Or 'expense' based on your use case
                    'timestamp': DateTime.now().toIso8601String(),
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Balance recorded successfully')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to record balance: $e')),
                  );
                }
                Navigator.of(context).pop();
              },
              child: Text('Add Balance'),
            ),
          ],
        ),
      ),
    );
  }
}
