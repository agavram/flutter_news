import 'package:flutter/material.dart';
import 'news.dart';
import 'login.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    print(FirebaseAuth.instance.currentUser());
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      routes: {
        "news": (context) => News(),
        "login": (context) => Login(),
      },
      //TODO: Check if logged in
      home: Login(),
    );
  }
}
