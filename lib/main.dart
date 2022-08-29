import 'package:firebase_authentication_demo/firebase_options.dart';
import 'package:firebase_authentication_demo/views/app.dart';
import 'package:firebase_authentication_demo/views/login_view.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(App());
}
