import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import './screens/home_page.dart';
import 'providers/spots_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (kDebugMode && Platform.isAndroid) {
    try {
      FirebaseFunctions.instance.useFunctionsEmulator("localhost", 5001);
    } catch (exception) {
      if (kDebugMode) {
        print(exception);
      }
    }
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => SpotsProvider(),
      child: MaterialApp(
        theme: ThemeData(
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSwatch(
            brightness:
                Brightness.dark, // Match the brightness setting in ThemeData
          ).copyWith(
            secondary: const Color(0xFFFAE96F),
          ),
        ),
        home: const HomePage(),
      ),
    );
  }
}
