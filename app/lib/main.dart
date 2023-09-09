import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (kDebugMode) {
    try {
      FirebaseFunctions.instance.useFunctionsEmulator("localhost", 5001);
    } catch (exception) {
      print(exception);
    }
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(
          child: MyHomePage(),
        ),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _functionResponse = 'Press the button to call the function';

  Future<void> _callHelloWorldFunction() async {
    print('callHelloWorldFunction');
    HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
      'helloWorld',
      options: HttpsCallableOptions(
        timeout: const Duration(seconds: 5),
      ),
    );

    try {
      final HttpsCallableResult result = await callable.call();
      print(result);
      setState(() {
        _functionResponse = result.data;
      });
    } catch (e) {
      setState(() {
        if (kDebugMode) print(e);
        _functionResponse = 'Function call failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _callHelloWorldFunction,
              child: const Text('Call Hello World Function'),
            ),
            Text(_functionResponse),
          ],
        ),
      ),
    );
  }
}
