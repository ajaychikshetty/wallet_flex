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

  const SpendingSection({Key? key, required this.selectedDate}) : super(key: key);

  @override
  _SpendingSectionState createState() => _SpendingSectionState();
}

class _SpendingSectionState extends State<SpendingSection> {
  // Color Palette
  static const Color primaryColor = Color(0xFF2C3E50);
  static const Color secondaryColor = Color(0xFF34495E);
  static const Color accentColor = Color(0xFF3498DB);
  static const Color backgroundColor = Color(0xFFF4F6F7);

  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final String userId = auth.currentUser!.uid;
    String formattedDate = DateFormat('EEE, dd MMM').format(widget.selectedDate);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor.withOpacity(0.1),
            backgroundColor.withOpacity(0.5)
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            _buildFinancialSummary(userId, formattedDate, screenWidth, screenHeight),
            _buildSpendingChart(userId, formattedDate),
            _buildActionButtons(context, screenWidth, screenHeight),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialSummary(String userId, String formattedDate, double screenWidth, double screenHeight) {
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
            Colors.white,
            Colors.white
          ],
        ),
        borderGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.5),
            Colors.white.withOpacity(0.2),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildFinancialCard(
                userId, 
                formattedDate, 
                'Balance', 
                Icons.account_balance_wallet, 
                Colors.green,
                screenWidth
              ),
              _buildFinancialCard(
                userId, 
                formattedDate, 
                'Expense', 
                Icons.money_off, 
                Colors.red,
                screenWidth
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFinancialCard(
    String userId, 
    String formattedDate, 
    String type, 
    IconData icon, 
    Color color, 
    double screenWidth
  ) {
    return StreamBuilder<QuerySnapshot>(
      stream: type == 'Balance' 
        ? firestore
            .collection('user_details')
            .doc(userId)
            .collection('balance')
            .where('date', isEqualTo: formattedDate)
            .snapshots()
        : firestore
            .collection('user_details')
            .doc(userId)
            .collection('expenses')
            .where('date', isEqualTo: formattedDate)
            .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingIndicator();
        }

        double amount = 0;
        if (type == 'Balance' && snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          amount = snapshot.data!.docs.first['amount']?.toDouble() ?? 0;
        } else if (type == 'Expense' && snapshot.hasData) {
          amount = snapshot.data!.docs.fold(0, (sum, doc) => sum + (doc['amount']?.toDouble() ?? 0));
        }

        return Container(
          width: 150,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: color.withOpacity(0.3), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 40),
              const SizedBox(height: 10),
              Text(
                type,
                style: GoogleFonts.roboto(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '₹${amount.toStringAsFixed(2)}',
                style: GoogleFonts.roboto(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSpendingChart(String userId, String formattedDate) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: SpendingChart(userId: userId, selectedDate: formattedDate),
    );
  }

  Widget _buildActionButtons(BuildContext context, double screenWidth, double screenHeight) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildGradientButton(
            context, 
            '+ Balance', 
            screenWidth, 
            screenHeight, 
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AddBalancePage()),
            ),
          ),
          _buildGradientButton(
            context, 
            '+ Expense', 
            screenWidth, 
            screenHeight, 
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AddExpensePage()),
            ),
          ),
        ],
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

  Widget _buildGradientButton(
    BuildContext context, 
    String text, 
    double screenWidth, 
    double screenHeight, 
    VoidCallback onPressed
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, accentColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: EdgeInsets.symmetric(
            vertical: screenHeight * 0.02,
            horizontal: screenWidth * 0.1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: Text(
          text,
          style: GoogleFonts.roboto(
            fontSize: screenWidth * 0.04,
            color: Colors.white,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}