import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  final users = await FirebaseFirestore.instance.collection('users').get();
  for (var doc in users.docs) {
    print('User: ${doc.data()['name']} - Token: ${doc.data()['fcmToken']}');
  }
}
