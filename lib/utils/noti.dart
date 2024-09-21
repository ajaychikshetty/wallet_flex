import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:developer' as dev;

import 'firebase_operations.dart';

Future<void> handleBackgroundMessage(RemoteMessage message) async {
  print(message.notification?.title.toString());
  print(message.notification?.body.toString());
}

class FirebaseNotifiApi {
  final fireBaseMessaging = FirebaseMessaging.instance;

  Future<void> initNotification() async {
    await fireBaseMessaging.requestPermission();
    final FMCtoken = await fireBaseMessaging.getToken();
    print("Token--------------: $FMCtoken");
    dev.log(FMCtoken.toString(), name: "firebase Token");
    NotificationService.addNotiToken(FMCtoken.toString());
    FirebaseMessaging.onMessageOpenedApp.listen(handleBackgroundMessage);
    FirebaseMessaging.onBackgroundMessage(handleBackgroundMessage);
  }
}
