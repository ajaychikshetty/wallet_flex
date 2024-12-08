import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class TransactionsPage extends StatefulWidget {
  final DateTime selectedDate;

  const TransactionsPage({super.key, required this.selectedDate});

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
        const SnackBar(content: Text('No transactions found to export.')),
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
          title: const Text('Transaction Receipt'),
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
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // Future<void> _showGraphDialog() async {
  //   final String userId = _auth.currentUser!.uid;

  //   final balanceSnapshot = await _firestore
  //       .collection('user_details')
  //       .doc(userId)
  //       .collection('balance')
  //       .orderBy('date')
  //       .get();

  //   final expenseSnapshot = await _firestore
  //       .collection('user_details')
  //       .doc(userId)
  //       .collection('expenses')
  //       .orderBy('date')
  //       .get();

  //   final balanceData = balanceSnapshot.docs.map((doc) {
  //     final date = DateFormat('EEE, dd MMM').parse(doc['date']);
  //     return charts.Series(
  //       id: 'Balance',
  //       domainFn: (dynamic datum, _) => datum['date'] as DateTime,
  //       measureFn: (dynamic datum, _) => datum['amount'] as double,
  //       data: [
  //         {'date': date, 'amount': doc['amount'].toDouble()}
  //       ],
  //       colorFn: (_, __) => charts.MaterialPalette.blue.shadeDefault,
  //     );
  //   }).toList();

  //   final expenseData = expenseSnapshot.docs.map((doc) {
  //     final date = DateFormat('EEE, dd MMM').parse(doc['date']);
  //     return charts.Series(
  //       id: 'Expenses',
  //       domainFn: (dynamic datum, _) => datum['date'] as DateTime,
  //       measureFn: (dynamic datum, _) => datum['amount'] as double,
  //       data: [
  //         {'date': date, 'amount': doc['amount'].toDouble()}
  //       ],
  //       colorFn: (_, __) => charts.MaterialPalette.red.shadeDefault,
  //     );
  //   }).toList();

  //   showDialog(
  //     context: context,
  //     builder: (BuildContext context) {
  //       return AlertDialog(
  //         title: const Text('Expense and Balance Graph'),
  //         content: SizedBox(
  //           height: 300,
  //           child: charts.TimeSeriesChart(
  //             balanceData + expenseData,
  //             animate: true,
  //           ),
  //         ),
  //         actions: [
  //           TextButton(
  //             child: const Text('Close'),
  //             onPressed: () {
  //               Navigator.of(context).pop();
  //             },
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }

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
                  style: const TextStyle(fontSize: 16),
                ),
                ElevatedButton(
                  // onPressed: _showGraphDialog,
                  onPressed: (){},
                  child: const Text('Show Graph'),
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
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No transactions found.'));
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
                    final timestamp = transaction['timestamp'] ?? '';

                    return Card(
                      child: ListTile(
                        title: Text(tname),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Date: $date'),
                            Text(
                              'Amount: ${type == 'income' ? '+' : '-'}₹${amount.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: type == 'income'
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                            Text('Type: $type'),
                            Text('Timestamp: $timestamp'),
                          ],
                        ),
                        onTap: () => _showReceiptDialog(transaction),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _generateAndDownloadPDF,
        child: const Icon(Icons.download),
      ),
    );
  }
}
