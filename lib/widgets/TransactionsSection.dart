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
  // Color Palette
  static const Color primaryColor = Color(0xFF6F4E37); // Coffee Brown
  static const Color secondaryColor = Color(0xFFA0522D); // Sienna
  static const Color accentColor = Color(0xFFD2691E); // Warm Terracotta
  static const Color backgroundColor = Color(0xFFFFF4E0); // Soft Cream
  static const Color textColor = Color(0xFF3E2723);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromInt(primaryColor.value),
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromInt(secondaryColor.value),
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8.0),
                        child: pw.Text('Name',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromInt(primaryColor.value),
                            )),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8.0),
                        child: pw.Text('Date',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromInt(primaryColor.value),
                            )),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8.0),
                        child: pw.Text('Amount',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromInt(primaryColor.value),
                            )),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: primaryColor, width: 2),
          ),
          backgroundColor: backgroundColor,
          title: Text(
            'Transaction Receipt',
            style: TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildReceiptRow('Name', transaction['tname'] ?? 'No name'),
              _buildReceiptRow('Date', transaction['date'] ?? ''),
              _buildReceiptRow(
                'Amount',
                '${transaction['type'] == 'income' ? '+' : '-'}₹${(transaction['amount'] ?? 0).toStringAsFixed(2)}',
                color: transaction['type'] == 'income'
                    ? Colors.green
                    : accentColor,
              ),
              _buildReceiptRow('Type', transaction['type'] ?? 'Unknown'),
              _buildReceiptRow('Timestamp', transaction['timestamp'] ?? ''),
            ],
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
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

  Widget _buildReceiptRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: RichText(
        text: TextSpan(
          style: TextStyle(color: textColor),
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: secondaryColor,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                color: color ?? textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String userId = _auth.currentUser!.uid;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Column(
        children: [
          // Selected Date Header
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: secondaryColor.withOpacity(0.1),
              border: Border(
                bottom: BorderSide(
                    color: secondaryColor.withOpacity(0.3), width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_today, color: primaryColor),
                const SizedBox(width: 10),
                Text(
                  'Selected Date: ${DateFormat('EEE, dd MMM').format(widget.selectedDate)}',
                  style: TextStyle(
                    fontSize: 16,
                    color: primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
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
        .where('date', isEqualTo: widget.selectedDate)  // Directly use DateTime field for comparison
        .orderBy('timestamp', descending: true)
        .snapshots(),
    builder: (context, snapshot) {
      // Checking the connection state
      if (snapshot.connectionState == ConnectionState.waiting) {
        return Center(
          child: CircularProgressIndicator(
            color: primaryColor,
          ),
        );
      }

      // Error handling
      if (snapshot.hasError) {
        print('Error: ${snapshot.error}');
        return Center(
          child: Text(
            'Error: ${snapshot.error}',
            style: TextStyle(color: accentColor),
          ),
        );
      }

      // If no data exists
      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 80,
                color: primaryColor.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'No transactions found',
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }

      // Extracting transaction data
      final transactions = snapshot.data!.docs;

      return ListView.builder(
        itemCount: transactions.length,
        itemBuilder: (context, index) {
          final transaction = transactions[index].data() as Map<String, dynamic>;
          final amount = transaction['amount'] ?? 0;
          final tname = transaction['tname'] ?? 'No name';
          final type = transaction['type'] ?? 'Unknown';
          final date = transaction['date'] ?? '';

          // Parsing the date string to DateTime
          DateTime transactionDate;
          try {
            transactionDate = DateFormat('EEE, dd MMM').parse(date);
          } catch (e) {
            transactionDate = DateTime.now();
          }

          // Building the list item
          return GestureDetector(
            onTap: () => _showReceiptDialog(transaction),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 254, 250, 240),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: Offset(0, 3),
                  ),
                ],
                border: Border.all(
                  color: secondaryColor.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
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
                              color: primaryColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Date: ${DateFormat('EEE, dd MMM').format(transactionDate)}',
                            style: TextStyle(
                              color: textColor.withOpacity(0.6),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${type == 'income' ? '+' : '-'}₹${amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: type == 'income' ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  ),
),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: () async {
                final shouldExport = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: backgroundColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                      side: BorderSide(color: primaryColor, width: 2),
                    ),
                    title: Text(
                      'Export Transactions',
                      style: TextStyle(color: primaryColor),
                    ),
                    content: Text(
                      'Do you want to export the transactions for this date?',
                      style: TextStyle(color: textColor),
                    ),
                    actions: [
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: accentColor,
                        ),
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: primaryColor,
                        ),
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );

                if (shouldExport == true) {
                  await _generateAndDownloadPDF();
                }
              },
              icon: Icon(
                Icons.file_download,
                color: Colors.white,
              ),
              label: Text(
                'Export Transactions',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 5,
                shadowColor: primaryColor.withOpacity(0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
