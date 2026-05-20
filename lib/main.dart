import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/login_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  // ✅ Use FirebaseOptions only for Web
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyDiSQAUH34KvVi_khN0fVEGLDUpsWmTpAg",
        authDomain: "smart-rental-apps.firebaseapp.com",
        projectId: "smart-rental-apps",
        storageBucket: "smart-rental-apps.appspot.com",
        messagingSenderId: "930229258733",
        appId: "1:930229258733:web:193131e979fb234b5dffe4",
      ),
    );
  } else {
    // ✅ For Android & iOS — use google-services.json or GoogleService-Info.plist
    await Firebase.initializeApp();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Recommendation App',
      home: const LoginScreen(),
    );
  }
}
