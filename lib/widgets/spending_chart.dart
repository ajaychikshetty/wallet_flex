import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';

class SpendingChart extends StatefulWidget {
  final String userId;
  final String selectedDate;

  const SpendingChart(
      {Key? key, required this.userId, required this.selectedDate})
      : super(key: key);

  @override
  _SpendingChartState createState() => _SpendingChartState();
}

class _SpendingChartState extends State<SpendingChart> {
  static const Color backgroundColor = Color.fromARGB(255, 250, 247, 240); // Soft Cream
  // Soft Cream

  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> expenseCategories = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchExpenseCategories();
  }

  Future<void> _fetchExpenseCategories() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      QuerySnapshot querySnapshot = await firestore
          .collection('user_details')
          .doc(widget.userId)
          .collection('expenses')
          .where('date', isEqualTo: widget.selectedDate)
          .get();

      Map<String, double> descriptionTotals = {};

      for (var doc in querySnapshot.docs) {
        String description = doc['description'] ?? 'Uncategorized';
        double amount = doc['amount']?.toDouble() ?? 0;

        descriptionTotals[description] =
            (descriptionTotals[description] ?? 0) + amount;
      }

      setState(() {
        expenseCategories = descriptionTotals.entries
            .map((entry) => {'description': entry.key, 'amount': entry.value})
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching expenses: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      decoration: BoxDecoration(
        
        color: const Color.fromARGB(255, 254, 250, 240),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color.fromARGB(255, 69, 69, 69).withOpacity(0.2)
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 5,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Expense Breakdown',
              style: GoogleFonts.roboto(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.teal[700],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _buildChartContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartContent() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Text(
          _errorMessage,
          style: GoogleFonts.roboto(
            color: Colors.red,
            fontSize: 16,
          ),
        ),
      );
    }

    if (expenseCategories.isEmpty) {
      return _buildEmptyState();
    }

    return _buildPieChart();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Text(
        'No expenses for today',
        style: GoogleFonts.roboto(
          color: Colors.grey,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildPieChart() {
    return PieChart(
      PieChartData(
        sections: expenseCategories
            .map((description) => PieChartSectionData(
                  color: _getdescriptionColor(description['description']),
                  value: description['amount'],
                  title: description['description'],
                  radius: 50,
                  titleStyle: GoogleFonts.roboto(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ))
            .toList(),
        centerSpaceRadius: 40,
        sectionsSpace: 2,
      ),
    );
  }

  Color _getdescriptionColor(String description) {
    final colorMap = {
      'food': Colors.red.shade400,
      'travel': Colors.blue.shade400,
      'entertainment': Colors.green.shade400,
      'shopping': Colors.purple.shade400,
      'Utilities': Colors.orange.shade400,
      'Uncategorized': Colors.grey.shade400,
    };

    return colorMap[description] ?? Colors.grey.shade400;
  }
}
