import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String _profileImageUrl = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final User? currentUser = _auth.currentUser;

      if (currentUser != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('user_details')
            .doc(currentUser.uid)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data();

          setState(() {
            _nameController.text = userData?['name'] ?? '';
            _emailController.text = userData?['email'] ?? '';
            _phoneController.text = userData?['phone'] ?? '';
            _ageController.text = userData?['age']?.toString() ?? '';
            _profileImageUrl = userData?['profileUrl'] ?? '';
          });
        } else {
          print('Error: User document does not exist.');
        }
      } else {
        print('Error: No user is currently signed in.');
      }
    } catch (e) {
      print('Error fetching user data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateUserData() async {
    final User? currentUser = _auth.currentUser;

    if (currentUser != null) {
      await FirebaseFirestore.instance
          .collection('user_details')
          .doc(currentUser.uid)
          .update({
        'name': _nameController.text,
        'email': _emailController.text,
        'phone': _phoneController.text,
        'age': int.tryParse(_ageController.text) ?? 0,
        'profileUrl': _profileImageUrl,
      });
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await showDialog<XFile?>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Image Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () async {
                  Navigator.of(context)
                      .pop(await _picker.pickImage(source: ImageSource.camera));
                },
              ),
              ListTile(
                leading: const Icon(Icons.image),
                title: const Text('Gallery'),
                onTap: () async {
                  Navigator.of(context).pop(
                      await _picker.pickImage(source: ImageSource.gallery));
                },
              ),
            ],
          ),
        );
      },
    );

    if (pickedFile != null) {
      final file = File(pickedFile.path);
      final fileName = DateTime.now().millisecondsSinceEpoch.toString();
      final firebaseStorageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('$fileName.jpg');

      final uploadTask = firebaseStorageRef.putFile(file);
      final snapshot = await uploadTask.whenComplete(() {});
      final downloadUrl = await snapshot.ref.getDownloadURL();

      setState(() {
        _profileImageUrl = downloadUrl;
      });

      _updateUserData();
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor:
          const Color(0xFFFFF4E0), // Using your app's background color
      // appBar: AppBar(
      //   backgroundColor:
      //       const Color(0xFF6F4E37), // Primary color from your theme
      //   elevation: 0,
      //   title: Text(
      //     'Profile',
      //     style: TextStyle(
      //       color: Colors.white,
      //       fontSize: 20,
      //       fontWeight: FontWeight.bold,
      //     ),
      //   ),
      //   centerTitle: true,
      // ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(screenWidth * 0.05),
          child: Column(
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    ClipOval(
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                        ),
                        child: _profileImageUrl.isNotEmpty
                            ? Image.network(
                                _profileImageUrl,
                                fit: BoxFit.cover,
                              )
                            : const Icon(Icons.person, size: 80),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6F4E37),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.edit,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: screenHeight * 0.04),
              buildTextField(
                controller: _nameController,
                label: 'Name',
                icon: Icons.person_outline,
              ),
              SizedBox(height: screenHeight * 0.02),
              buildTextField(
                controller: _emailController,
                label: 'Email',
                icon: Icons.email_outlined,
                enabled: false,
              ),
              SizedBox(height: screenHeight * 0.02),
              buildTextField(
                controller: _phoneController,
                label: 'Phone',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
              SizedBox(height: screenHeight * 0.02),
              buildTextField(
                controller: _ageController,
                label: 'Age',
                icon: Icons.calendar_today_outlined,
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: screenHeight * 0.04),
              ElevatedButton(
                onPressed: _updateUserData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6F4E37),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.2,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  'Update',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(height: screenHeight * 0.02),
              TextButton(
                onPressed: () async {
                  await _auth.signOut();
                  Navigator.of(context).pushReplacementNamed('/login');
                },
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF6F4E37),
                ),
                child: const Text(
                  'Sign Out',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: const Color(0xFF6F4E37)),
          prefixIcon: Icon(icon, color: const Color(0xFF6F4E37)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.transparent),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: const Color(0xFF6F4E37)),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }
}
