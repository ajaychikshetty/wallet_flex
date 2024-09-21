import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:wallet_flex/widgets/SpendingSection.dart';
import 'package:wallet_flex/widgets/TransactionsSection.dart';
import 'package:wallet_flex/widgets/ProfilePage.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  String message = "Only 30% budget left!!";
  DateTime _selectedDate = DateTime.now();
  bool _hasNotified70 = false;
  bool _hasNotified90 = false;

  @override
  void initState() {
    super.initState();
    _createNotificationChannel();

    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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

  String _formatDate(DateTime date) {
    return DateFormat('EEE, dd MMM').format(date);
  }

  void _selectNextDate() {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: 1));
    });
  }

  void _selectPreviousDate() {
    setState(() {
      _selectedDate = _selectedDate.subtract(Duration(days: 1));
    });
  }

  Future<void> _logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.of(context).pushReplacementNamed('/login');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to log out. Please try again.'),
        ),
      );
    }
  }

  void _createNotificationChannel() {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'chat_messages', // Channel ID
      'Chat Messages', // Channel name
      importance: Importance.high,
      description: 'Notifications for chat messages',
    );

    flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _showNotification(String message) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'chat_messages', // Channel ID
      'Chat Messages', // Channel name
      channelDescription:
          'Notifications for chat messages', // Channel description
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
      0,
      'Warning!',
      message,
      platformChannelSpecifics,
      payload: 'item x',
    );
  }

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
        toolbarHeight: screenHeight * 0.1,
        title: GestureDetector(
          onTap: () => _selectDate(context),
          child: Container(
            padding: EdgeInsets.symmetric(
              vertical: screenHeight * 0.01,
              horizontal: screenWidth * 0.02,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white),
              borderRadius: BorderRadius.circular(5.0),
            ),
            child: Text(
              _formatDate(_selectedDate),
              style:
                  TextStyle(color: Colors.white, fontSize: screenHeight * 0.02),
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: Icon(Icons.currency_rupee_sharp), text: "Spending"),
            Tab(icon: Icon(Icons.receipt), text: "Transactions"),
            Tab(icon: Icon(Icons.account_circle), text: "My Profile"),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildProgressBar(screenWidth, screenHeight),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 20.0),
                  child: SpendingSection(selectedDate: _selectedDate),
                ),
                TransactionsPage(selectedDate: _selectedDate),
                ProfilePage(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(double screenWidth, double screenHeight) {
    final FirebaseAuth _auth = FirebaseAuth.instance;
    final String userId = _auth.currentUser!.uid;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('user_details')
          .doc(userId)
          .collection('balance')
          .where('date',
              isEqualTo: DateFormat('EEE, dd MMM').format(_selectedDate))
          .snapshots(),
      builder: (context, balanceSnapshot) {
        if (!balanceSnapshot.hasData || balanceSnapshot.data!.docs.isEmpty) {
          return Container();
        }
        final balanceData = balanceSnapshot.data!.docs.first.data();
        double balance = balanceData['amount']?.toDouble() ?? 0;

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('user_details')
              .doc(userId)
              .collection('expenses')
              .where('date',
                  isEqualTo: DateFormat('EEE, dd MMM').format(_selectedDate))
              .snapshots(),
          builder: (context, expensesSnapshot) {
            if (!expensesSnapshot.hasData) {
              return Container();
            }
            double totalSpending = expensesSnapshot.data!.docs.fold(
              0,
              (sum, doc) => sum + (doc.data()['amount']?.toDouble() ?? 0),
            );

            double balanceProgress =
                balance > 0 ? totalSpending / (balance + totalSpending) : 0;

            // Send notifications if thresholds are met and no notification has been sent for those thresholds
            if (balanceProgress > 0.9 && !_hasNotified90) {
              _showNotification('Warning! 90% of your budget used.');
              _hasNotified90 = true; // Mark 90% notification as sent
            } else if (balanceProgress > 0.7 && !_hasNotified70) {
              _showNotification('Warning! 70% of your budget used.');
              _hasNotified70 = true; // Mark 70% notification as sent
            } else if (balanceProgress <= 0.7 && balanceProgress > 0.5) {
              // Reset notification status when going below 70% but still above 50%
              _hasNotified70 = false;
            } else if (balanceProgress <= 0.9 && balanceProgress > 0.7) {
              // Reset notification status when going below 90% but still above 70%
              _hasNotified90 = false;
            }

            return Padding(
              padding: EdgeInsets.all(screenWidth * 0.04),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_left),
                    onPressed: _selectPreviousDate,
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        LinearProgressIndicator(
                          minHeight: 10,
                          backgroundColor: Colors.green,
                          color: Colors.red,
                          value:
                              balanceProgress, // Progress value between 0.0 and 1.0
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.arrow_right),
                    onPressed: _selectNextDate,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
