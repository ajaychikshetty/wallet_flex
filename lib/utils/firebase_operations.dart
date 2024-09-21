import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  static final FirebaseAuth auth = FirebaseAuth.instance;
  static final FirebaseFirestore firestore = FirebaseFirestore.instance;

  static Future<void> addNotiToken(String token) async {
    try {
      DocumentReference userDocRef =
          firestore.collection('user_details').doc(auth.currentUser?.uid);

      if (auth.currentUser != null) {
        await userDocRef.update({
          'Ntoken': token,
        });
        print('Notification token updated successfully.');
      } else {
        print('User not authenticated.');
      }
    } catch (e) {
      print('Error updating notification token: $e');
    }
  }
}
