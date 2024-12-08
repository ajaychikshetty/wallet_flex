import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wallet_flex/pages/add_balance_page.dart';
import 'package:wallet_flex/pages/add_expense_page.dart';
import 'package:wallet_flex/widgets/spending_chart.dart';
import 'package:glassmorphism/glassmorphism.dart';

class SpendingSection extends StatefulWidget {
  final DateTime selectedDate;

  const SpendingSection({Key? key, required this.selectedDate})
      : super(key: key);

  @override
  _SpendingSectionState createState() => _SpendingSectionState();
}

class _SpendingSectionState extends State<SpendingSection>
    with SingleTickerProviderStateMixin {
  // Color Constants
  static const Color primaryColor = Color(0xFF6F4E37);
  static const Color secondaryColor = Color(0xFFA0522D);
  static const Color accentColor = Color(0xFFD2691E);
  static const Color backgroundColor = Color(0xFFFFF4E0);
  static const Color textColor = Color(0xFF3E2723);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late AnimationController _animationController;
  late Animation<double> _animation;

  // Centralized financial data
  Map<String, dynamic>? _financialData;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeAnimationController();
    _fetchFinancialData();
  }

  void _initializeAnimationController() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _animationController.forward();
  }

  Future<void> _fetchFinancialData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final formattedDate =
          DateFormat('EEE, dd MMM').format(widget.selectedDate);

      // Fetch balance
      final balanceSnapshot = await _firestore
          .collection('user_details')
          .doc(userId)
          .collection('balance')
          .where('date', isEqualTo: formattedDate)
          .limit(1)
          .get();

      // Fetch expenses
      final expensesSnapshot = await _firestore
          .collection('user_details')
          .doc(userId)
          .collection('expenses')
          .where('date', isEqualTo: formattedDate)
          .get();

      setState(() {
        _financialData = {
          'balance': balanceSnapshot.docs.isNotEmpty
              ? balanceSnapshot.docs.first.data()
              : null,
          'expenses': expensesSnapshot.docs.map((doc) => doc.data()).toList(),
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage =
            'Failed to load financial data. Please check your connection.';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return FadeTransition(
      opacity: _animation,
      child: Scaffold(
        backgroundColor: backgroundColor,
        bottomNavigationBar:
            _buildActionButtons(context, screenWidth, screenHeight),
        body: _buildBody(screenWidth, screenHeight),
      ),
    );
  }

  Widget _buildBody(double screenWidth, double screenHeight) {
    if (_isLoading) {
      return _buildLoadingIndicator();
    }

    if (_errorMessage != null) {
      return _buildErrorWidget();
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            backgroundColor.withOpacity(0.1),
            backgroundColor.withOpacity(0.5)
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: RefreshIndicator(
        color: primaryColor,
        onRefresh: _fetchFinancialData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildFinancialSummary(screenWidth, screenHeight),
              _buildMonthlyInsights(),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recurring Expenses',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildRecurringExpenses(context),
                  ],
                ),
              ),
              _buildSpendingChart(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: accentColor,
            size: 60,
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: GoogleFonts.openSans(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchFinancialData,
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
            child: Text(
              'Retry',
              style: GoogleFonts.openSans(color: Colors.white),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFinancialSummary(double screenWidth, double screenHeight) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: GlassmorphicContainer(
        width: screenWidth,
        height: screenHeight * 0.25,
        borderRadius: 20,
        blur: 10,
        alignment: Alignment.center,
        border: 2,
        linearGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.6),
            Colors.white.withOpacity(0.4)
          ],
        ),
        borderGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor.withOpacity(0.2),
            secondaryColor.withOpacity(0.1),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 10.0, left: 10),
                child: Text(
                  'Expense Breakdown',
                  style: GoogleFonts.roboto(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal[700],
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildFinancialCard(
                    'Balance',
                    Icons.account_balance_wallet,
                    const Color.fromARGB(255, 78, 131, 57),
                  ),
                  _buildFinancialCard(
                    'Expense',
                    Icons.money_off,
                    const Color.fromARGB(255, 210, 36, 30),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFinancialCard(String type, IconData icon, Color color) {
    double amount = 0;

    if (type == 'Balance' && _financialData?['balance'] != null) {
      amount = _financialData!['balance']['amount']?.toDouble() ??
          0.0; // Convert to double
    } else if (type == 'Expense' && _financialData?['expenses'] != null) {
      amount = (_financialData!['expenses'] as List).fold(0.0, (sum, doc) {
        return sum +
            (doc['amount']?.toDouble() ?? 0.0); // Ensure conversion to double
      });
    }

    return Container(
      width: 150,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
        boxShadow: [BoxShadow(color: backgroundColor)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 40),
          const SizedBox(height: 10),
          Text(
            type,
            style: GoogleFonts.openSans(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: GoogleFonts.openSans(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyInsights() {
    final expenses = _financialData?['expenses'] ?? [];

    double totalExpenses = expenses.fold(0.0, (sum, doc) {
      return sum +
          (doc['amount']?.toDouble() ?? 0.0); // Ensure double conversion
    });

    int transactionCount = expenses.length;
    double averageExpense = transactionCount > 0
        ? totalExpenses / transactionCount
        : 0.0; // Avoid integer division

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, backgroundColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Monthly Insights',
                  style: GoogleFonts.roboto(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal[700],
                  ),
                ),
                Icon(
                  Icons.analytics_outlined,
                  color: Colors.green.withOpacity(0.7),
                  size: 30,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildInsightRow(
                    icon: Icons.monetization_on_outlined,
                    label: 'Total Expenses',
                    value: '₹${totalExpenses.toStringAsFixed(2)}',
                  ),
                  const Divider(color: Colors.black),
                  _buildInsightRow(
                    icon: Icons.trending_up_outlined,
                    label: 'Average Expense',
                    value: '₹${averageExpense.toStringAsFixed(2)}',
                  ),
                  const Divider(color: Colors.black),
                  _buildInsightRow(
                    icon: Icons.receipt_long_outlined,
                    label: 'Transactions',
                    value: transactionCount.toString(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecurringExpenses(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('user_details')
          .doc(_auth.currentUser!.uid)
          .collection('recurring_pay')
          .where('isActive', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text('No recurring expenses found'),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;

            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: accentColor.withOpacity(0.1),
                  child: const Icon(
                    Icons.repeat,
                    color: accentColor,
                  ),
                ),
                title: Text(data['description'] ?? 'No description'),
                subtitle: Text(
                    '₹${data['amount']?.toStringAsFixed(2) ?? '0.00'} daily'),
                trailing: Text(
                  'Started: ${DateFormat('dd MMM yyyy').format(DateTime.parse(data['startDate']))}',
                  style: TextStyle(
                    color: textColor.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
                onTap: () => _showRecurringExpenseDetails(context, doc),
              ),
            );
          },
        );
      },
    );
  }

  void _showRecurringExpenseDetails(
      BuildContext context, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Recurring Expense Details'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Description: ${data['description'] ?? 'No description'}'),
              const SizedBox(height: 8),
              Text('Amount: ₹${data['amount']?.toStringAsFixed(2) ?? '0.00'}'),
              const SizedBox(height: 8),
              Text('Recurrence: ${data['recurrence'] ?? 'daily'}'),
              const SizedBox(height: 8),
              Text(
                  'Start Date: ${DateFormat('dd MMM yyyy').format(DateTime.parse(data['startDate']))}'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _cancelRecurringExpense(context, doc.id),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Cancel Recurring Expense'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _cancelRecurringExpense(
      BuildContext context, String docId) async {
    try {
      await _firestore
          .collection('user_details')
          .doc(_auth.currentUser!.uid)
          .collection('recurring_pay')
          .doc(docId)
          .update({'isActive': false});

      Navigator.of(context).pop(); // Close the dialog

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recurring expense cancelled successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to cancel recurring expense: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildInsightRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.black, size: 24),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.openSans(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.openSans(
              color: Colors.red,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpendingChart() {
    final userId = _auth.currentUser?.uid;
    final formattedDate = DateFormat('EEE, dd MMM').format(widget.selectedDate);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: SpendingChart(userId: userId!, selectedDate: formattedDate),
    );
  }

  Widget _buildActionButtons(
      BuildContext context, double screenWidth, double screenHeight) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildElevatedGlassButton(
            context,
            '+ Add Balance',
            Icons.account_balance_wallet_outlined,
            primaryColor,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AddBalancePage()),
            ),
          ),
          _buildElevatedGlassButton(
            context,
            '+ Add Expense',
            Icons.money_off_outlined,
            accentColor,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AddExpensePage()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildElevatedGlassButton(BuildContext context, String text,
      IconData icon, Color buttonColor, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: buttonColor.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  buttonColor.withOpacity(0.7),
                  buttonColor.withOpacity(0.9),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                splashColor: Colors.white.withOpacity(0.3),
                onTap: onPressed,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 15,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        text,
                        style: GoogleFonts.openSans(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
      ),
    );
  }
}
