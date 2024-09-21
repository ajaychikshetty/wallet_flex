import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wallet_flex/pages/add_balance_page.dart';
import 'package:wallet_flex/pages/add_expense_page.dart';

class SpendingSection extends StatelessWidget {
  final DateTime selectedDate;

  SpendingSection({required this.selectedDate});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final FirebaseFirestore _firestore = FirebaseFirestore.instance;
    final FirebaseAuth _auth = FirebaseAuth.instance;
    final String userId = _auth.currentUser!.uid;

    String formattedDate = DateFormat('EEE, dd MMM').format(selectedDate);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Center(
            child: Column(
              children: [
                StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('user_details')
                      .doc(userId)
                      .collection('balance')
                      .where('date', isEqualTo: formattedDate)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return CircularProgressIndicator();
                    }

                    if (snapshot.hasError) {
                      return Text('Error: ${snapshot.error}');
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Text(
                        'Balance: ₹0.00',
                        style: TextStyle(
                          fontSize: screenWidth * 0.05,
                          color: Colors.green,
                        ),
                      );
                    }

                    final balanceDoc = snapshot.data!.docs.first;
                    final balance = balanceDoc['amount']?.toDouble() ?? 0;

                    return Text(
                      'Balance: ₹${balance.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: screenWidth * 0.05,
                        color: Colors.green,
                      ),
                    );
                  },
                ),
                SizedBox(height: screenHeight * 0.02),
                StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('user_details')
                      .doc(userId)
                      .collection('expenses')
                      .where('date', isEqualTo: formattedDate)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return CircularProgressIndicator();
                    }

                    if (snapshot.hasError) {
                      return Text('Error: ${snapshot.error}');
                    }

                    if (!snapshot.hasData) {
                      return Text(
                        'Expense: ₹0.00',
                        style: TextStyle(
                          fontSize: screenWidth * 0.05,
                          color: Colors.red,
                        ),
                      );
                    }

                    double totalExpense = 0;
                    snapshot.data!.docs.forEach((doc) {
                      totalExpense += (doc['amount']?.toDouble() ?? 0);
                    });

                    return Text(
                      'Expense: ₹${totalExpense.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: screenWidth * 0.05,
                        color: Colors.red,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.only(bottom: screenHeight * 0.05),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddBalancePage(),
                      ),
                    );
                  },
                  child: Text(
                    '+ Balance',
                    style: TextStyle(
                      fontSize: screenWidth * 0.04,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      vertical: screenHeight * 0.02,
                      horizontal: screenWidth * 0.1,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddExpensePage(),
                      ),
                    );
                  },
                  child: Text(
                    '+ Expense',
                    style: TextStyle(
                      fontSize: screenWidth * 0.04,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      vertical: screenHeight * 0.02,
                      horizontal: screenWidth * 0.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
