import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

// Assume these are your custom widget imports
import 'package:wallet_flex/widgets/SpendingSection.dart';
import 'package:wallet_flex/widgets/TransactionsSection.dart';
import 'package:wallet_flex/widgets/ProfilePage.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  // Enhanced Warm Color Palette
  static const Color primaryColor = Color(0xFF6F4E37); // Coffee Brown
  static const Color secondaryColor = Color(0xFFA0522D); // Sienna
  static const Color accentColor = Color(0xFFD2691E); // Warm Terracotta
  static const Color backgroundColor = Color(0xFFFFF4E0); // Soft Cream
  static const Color textColor = Color(0xFF3E2723); // Dark Brown

  // Controllers and Plugins
  late TabController _tabController;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // State Variables
  DateTime _selectedDate = DateTime.now();
  bool _hasNotified70 = false;
  bool _hasNotified90 = false;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Notification Initialization
  void _initializeNotifications() {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('app_icon');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification tap
      },
    );

    _createNotificationChannel();
  }

  // Create Notification
  void _createNotificationChannel() {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'budget_warnings',
      'Budget Warning Notifications',
      description: 'Notifications for budget usage warnings',
      importance: Importance.high,
    );

    flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // Show Budget Notification
  Future<void> _showBudgetNotification(String message) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'budget_warnings',
      'Budget Warning Notifications',
      channelDescription: 'Notifications for budget usage warnings',
      importance: Importance.max,
      priority: Priority.high,
      color: accentColor,
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      0,
      'Budget Alert',
      message,
      platformChannelSpecifics,
    );
  }

  // Date Selection Methods
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: primaryColor,
              primary: primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // Date Formatting
  String _formatDate(DateTime date) {
    return DateFormat('EEE, dd MMM').format(date);
  }

  // Navigation Methods
  void _selectNextDate() {
    setState(() {
      _selectedDate = _selectedDate.add(const Duration(days: 1));
    });
  }

  void _selectPreviousDate() {
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    });
  }

  // Logout Method
  Future<void> _logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.of(context).pushReplacementNamed('/login');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to log out. Please try again.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(65),
          ),
        ),
        leading: null,
        actions: [
          IconButton(
            icon: Icon(
              Icons.logout,
              color: Colors.white,
              shadows: [
                Shadow(
                  blurRadius: 10.0,
                  color: Colors.black45,
                  offset: Offset(0, 2),
                ),
              ],
            ),
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
              border: Border.all(color: Colors.white, width: 1.5),
              borderRadius: BorderRadius.circular(12.0),
              gradient: LinearGradient(
                colors: [
                  primaryColor.withOpacity(0.7),
                  secondaryColor.withOpacity(0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              _formatDate(_selectedDate),
              style: GoogleFonts.openSans(
                color: Colors.white,
                fontSize: screenHeight * 0.022,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
        bottom: TabBar(
          indicator: null,
          controller: _tabController,
          indicatorColor: accentColor,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: GoogleFonts.openSans(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            letterSpacing: 0.5,
          ),
          tabs: [
            Tab(
                icon: Icon(
                  Icons.currency_rupee_sharp,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      blurRadius: 5.0,
                      color: Colors.black45,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                text: "Spending"),
            Tab(
                icon: Icon(
                  Icons.receipt,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      blurRadius: 5.0,
                      color: Colors.black45,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                text: "Transactions"),
            Tab(
                icon: Icon(
                  Icons.account_circle,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      blurRadius: 5.0,
                      color: Colors.black45,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                text: "My Profile"),
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
                SpendingSection(selectedDate: _selectedDate),
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
    final FirebaseAuth auth = FirebaseAuth.instance;
    final String userId = auth.currentUser!.uid;
    final formattedDate = DateFormat('EEE, dd MMM').format(_selectedDate);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('user_details')
          .doc(userId)
          .collection('balance')
          .where('date', isEqualTo: formattedDate)
          .snapshots(),
      builder: (context, balanceSnapshot) {
        // Default values if no balance data
        double balance = 0;

        if (balanceSnapshot.hasData && balanceSnapshot.data!.docs.isNotEmpty) {
          final balanceData = balanceSnapshot.data!.docs.first.data();
          balance = balanceData['amount']?.toDouble() ?? 0;
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('user_details')
              .doc(userId)
              .collection('expenses')
              .where('date', isEqualTo: formattedDate)
              .snapshots(),
          builder: (context, expensesSnapshot) {
            // Calculate total spending
            double totalSpending = expensesSnapshot.hasData
                ? expensesSnapshot.data!.docs.fold(
                    0,
                    (sum, doc) => sum + (doc.data()['amount']?.toDouble() ?? 0),
                  )
                : 0;

            // Calculate balance progress
            double balanceProgress = balance > 0
                ? totalSpending / (balance + totalSpending)
                : totalSpending > 0
                    ? 1.0 // If no balance but expenses exist, show full red
                    : 0.0; // If no balance and no expenses, show empty bar

            // Ensure progress doesn't exceed 1.0
            balanceProgress = balanceProgress.clamp(0.0, 1.0);

            // Move notification logic outside of the build method
            // WidgetsBinding.instance.addPostFrameCallback((_) {
            //   _checkAndShowNotifications(balanceProgress);
            // });

            return Padding(
              padding: EdgeInsets.all(screenWidth * 0.04),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_left,
                      color: primaryColor,
                      size: 30,
                    ),
                    onPressed: _selectPreviousDate,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                       
                        SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            minHeight: 15,
                            backgroundColor: Colors.green.shade100,
                            color: _getProgressColor(balanceProgress),
                            value: balanceProgress,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.arrow_right,
                      color: primaryColor,
                      size: 30,
                    ),
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

// New method to handle notifications
  // void _checkAndShowNotifications(double balanceProgress) {
  //   if (balanceProgress > 0.9 && !_hasNotified90) {
  //     _showBudgetNotification('Warning! 90% of your budget used.');
  //     setState(() {
  //       _hasNotified90 = true;
  //     });
  //   } else if (balanceProgress > 0.7 && !_hasNotified70) {
  //     _showBudgetNotification('Warning! 70% of your budget used.');
  //     setState(() {
  //       _hasNotified70 = true;
  //     });
  //   } else if (balanceProgress <= 0.7 && balanceProgress > 0.5) {
  //     setState(() {
  //       _hasNotified70 = false;
  //     });
  //   } else if (balanceProgress <= 0.9 && balanceProgress > 0.7) {
  //     setState(() {
  //       _hasNotified90 = false;
  //     });
  //   }
  // }

  Color _getProgressColor(double progress) {
    if (progress < 0.5) return Colors.green.shade700;
    if (progress < 0.7) return Colors.orange.shade700;
    if (progress < 0.9) return Colors.deepOrange.shade700;
    return Colors.red.shade700;
  }
}
