import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:printing/printing.dart';

class TransactionsPage extends StatefulWidget {
  final DateTime selectedDate;

  TransactionsPage({required this.selectedDate});

  @override
  _TransactionsPageState createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Function to format date to match Firestore format (EEE, dd MMM)
  String _formatDateForFirestore(DateTime date) {
    return DateFormat('EEE, dd MMM').format(date);
  }

  Future<void> _generateAndDownloadPDF() async {
    final String userId = _auth.currentUser!.uid;

    final querySnapshot = await _firestore
        .collection('user_details')
        .doc(userId)
        .collection('transactions')
        .where('date', isEqualTo: _formatDateForFirestore(widget.selectedDate))
        .orderBy('timestamp', descending: true)
        .get();

    if (querySnapshot.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No transactions found to export.')),
      );
      return;
    }

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Transaction History for ${DateFormat('EEE, dd MMM').format(widget.selectedDate)}',
                style:
                    pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 16),
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8.0),
                        child: pw.Text('Name',
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8.0),
                        child: pw.Text('Date',
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8.0),
                        child: pw.Text('Amount',
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                  for (var doc in querySnapshot.docs)
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8.0),
                          child: pw.Text(doc['tname'] ?? 'No name'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8.0),
                          child: pw.Text(doc['date'] ?? ''),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8.0),
                          child: pw.Text(
                            '${doc['type'] == 'income' ? '+' : '-'}₹${(doc['amount'] ?? 0).toStringAsFixed(2)}',
                            style: pw.TextStyle(
                              color: doc['type'] == 'income'
                                  ? PdfColors.green
                                  : PdfColors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  void _showReceiptDialog(Map<String, dynamic> transaction) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Transaction Receipt'),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Name: ${transaction['tname'] ?? 'No name'}'),
              Text('Date: ${transaction['date'] ?? ''}'),
              Text(
                'Amount: ${transaction['type'] == 'income' ? '+' : '-'}₹${(transaction['amount'] ?? 0).toStringAsFixed(2)}',
                style: TextStyle(
                  color: transaction['type'] == 'income'
                      ? Colors.green
                      : Colors.red,
                ),
              ),
              Text('Type: ${transaction['type'] ?? 'Unknown'}'),
              Text('Timestamp: ${transaction['timestamp'] ?? ''}'),
            ],
          ),
          actions: [
            TextButton(
              child: Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showPieChartDialog() async {
    final String userId = _auth.currentUser!.uid;

    final balanceSnapshot = await _firestore
        .collection('user_details')
        .doc(userId)
        .collection('balance')
        .orderBy('date')
        .get();

    final expenseSnapshot = await _firestore
        .collection('user_details')
        .doc(userId)
        .collection('expenses')
        .orderBy('date')
        .get();

    // Function to aggregate data by week
    Map<String, double> aggregateWeeklyData(QuerySnapshot snapshot) {
      final Map<String, double> weeklyData = {};
      final DateFormat formatter =
          DateFormat('yyyy-MM-dd'); // Use consistent format for parsing

      for (var doc in snapshot.docs) {
        final date = DateFormat('EEE, dd MMM').parse(doc['date']);
        final weekStart = date.subtract(
            Duration(days: date.weekday - 1)); // Find the start of the week
        final weekKey = DateFormat('yyyy-MM-dd').format(weekStart);

        if (!weeklyData.containsKey(weekKey)) {
          weeklyData[weekKey] = 0;
        }
        weeklyData[weekKey] = weeklyData[weekKey]! + doc['amount'].toDouble();
      }

      return weeklyData;
    }

    final balanceWeeklyData = aggregateWeeklyData(balanceSnapshot);
    final expenseWeeklyData = aggregateWeeklyData(expenseSnapshot);

    // Calculate weekly total balance and expenses
    final totalBalance =
        balanceWeeklyData.values.fold(0.0, (sum, amount) => sum + amount);
    final totalExpenses =
        expenseWeeklyData.values.fold(0.0, (sum, amount) => sum + amount);

    // Prepare data for pie chart
    final pieChartData = [
      {
        'name': 'Expenses',
        'amount': totalExpenses,
        'color': charts.MaterialPalette.red.shadeDefault
      },
      {
        'name': 'Remaining Balance',
        'amount': totalBalance - totalExpenses,
        'color': charts.MaterialPalette.green.shadeDefault
      },
    ];

    final pieChartSeries = charts.Series<Map<String, dynamic>, String>(
      id: 'Expenses',
      domainFn: (Map<String, dynamic> datum, _) => datum['name'] as String,
      measureFn: (Map<String, dynamic> datum, _) => datum['amount'] as double,
      colorFn: (Map<String, dynamic> datum, _) =>
          datum['color'] as charts.Color,
      data: pieChartData,
      labelAccessorFn: (Map<String, dynamic> datum, _) =>
          '${datum['name']}: ${(datum['amount']! / totalBalance * 100).toStringAsFixed(1)}%',
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Weekly Balance and Expense Pie Chart'),
          content: SizedBox(
            height: 300,
            child: charts.PieChart<String>(
              [pieChartSeries],
              animate: true,
              defaultRenderer: charts.ArcRendererConfig(
                arcWidth: 60,
                arcRendererDecorators: [charts.ArcLabelDecorator()],
              ),
            ),
          ),
          actions: [
            TextButton(
              child: Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String userId = _auth.currentUser!.uid;

    return Scaffold(
      body: Column(
        children: [
          // Display Selected Date
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Selected Date: ${DateFormat('EEE, dd MMM').format(widget.selectedDate)}',
                  style: TextStyle(fontSize: 16),
                ),
                ElevatedButton(
                  onPressed: _showPieChartDialog,
                  child: Text('Show Graph'),
                ),
              ],
            ),
          ),
          // Transactions List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('user_details')
                  .doc(userId)
                  .collection('transactions')
                  .where('date',
                      isEqualTo: _formatDateForFirestore(widget.selectedDate))
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('No transactions found.'));
                }

                final transactions = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final transaction =
                        transactions[index].data() as Map<String, dynamic>;
                    final amount = transaction['amount'] ?? 0;
                    final tname = transaction['tname'] ?? 'No name';
                    final type = transaction['type'] ?? 'Unknown';
                    final date = transaction['date'] ?? '';

                    DateTime transactionDate;
                    try {
                      // Parse the date using the same format as Firestore
                      transactionDate = DateFormat('EEE, dd MMM').parse(date);
                    } catch (e) {
                      transactionDate = DateTime
                          .now(); // Fallback to current date if parsing fails
                    }

                    return GestureDetector(
                      onTap: () => _showReceiptDialog(transaction),
                      child: Container(
                        margin: EdgeInsets.symmetric(
                            vertical: 8.0, horizontal: 16.0),
                        padding: EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.grey.shade300,
                          ),
                          borderRadius: BorderRadius.circular(8.0),
                          color: Colors.white,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tname,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    'Date: ${DateFormat('EEE, dd MMM').format(transactionDate)}',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${type == 'income' ? '+' : '-'}₹${amount.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: type == 'income'
                                    ? Colors.green
                                    : Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // Export Button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () async {
                final shouldExport = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Export Transactions'),
                    content: Text(
                        'Do you want to export the transactions for this date?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: Text('OK'),
                      ),
                    ],
                  ),
                );

                if (shouldExport == true) {
                  await _generateAndDownloadPDF();
                }
              },
              child: Text('Export'),
            ),
          ),
        ],
      ),
    );
  }
}
