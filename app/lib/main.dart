import 'package:app/spot.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:location/location.dart';

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
      home: const SafeArea(
        child: Scaffold(
          body: Center(
            child: MyHomePage(),
          ),
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
  List<Spot> spots = [];
  String functionMessage = 'No function called yet';

  Future<void> _callHelloWorldFunction() async {
    print('callHelloWorldFunction');

    final LocationData? locationData = await _getLocation();
    if (locationData == null) {
      setState(() {
        spots = [];
        functionMessage = 'Location not found';
      });
      return;
    }
    HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
      'helloWorld',
      options: HttpsCallableOptions(
        timeout: const Duration(seconds: 10),
      ),
    );

    final Map<String, dynamic> payload = {
      'latitude': locationData.latitude,
      'longitude': locationData.longitude
    };

    try {
      final HttpsCallableResult response = await callable.call(payload);
      setState(() {
        spots = (response.data as List).map((spotJson) {
          return Spot.fromJson(Map<String, dynamic>.from(spotJson));
        }).toList();
        functionMessage = 'Function call succeeded';
      });
    } catch (e) {
      setState(() {
        if (kDebugMode) print(e);
        spots = [];
        functionMessage = 'Function call failed';
      });
    }
  }

  Future<LocationData?> _getLocation() async {
    Location location = Location();

    bool serviceEnabled;
    PermissionStatus permissionGranted;
    LocationData? locationData;

    serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        return null;
      }
    }

    permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        return null;
      }
    }

    locationData = await location.getLocation();
    return locationData;
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
            Text(
              functionMessage,
              style: const TextStyle(fontSize: 18.0),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: spots.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(spots[index].name),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
