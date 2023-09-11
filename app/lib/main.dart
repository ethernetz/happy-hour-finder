import 'package:app/spot.dart';
import 'package:app/spot_card.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:map_launcher/map_launcher.dart';

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

Future<void> openInMaps(Spot spot) async {
  final availableMaps = await MapLauncher.installedMaps;

  await availableMaps.first.showDirections(
    destination: Coords(
        spot.coordinates.coordinates[1], spot.coordinates.coordinates[0]),
    destinationTitle: spot.name,
    directionsMode: DirectionsMode.walking,
  );
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
  List<Spot>? spots;
  bool showOnlyCurrentHappyHour = false;

  Future<void> _callGetHappyHourSpots() async {
    print('_callGetHappyHourSpots');

    final LocationData? locationData = await _getLocation();
    if (locationData == null) {
      setState(() {
        spots = [];
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
      });
    } catch (e) {
      setState(() {
        if (kDebugMode) print(e);
        spots = [];
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
    var filteredSpots = showOnlyCurrentHappyHour
        ? spots?.where((spot) => spot.getCurrentHappyHour() != null).toList()
        : spots;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 20.0),
            ElevatedButton(
              onPressed: _callGetHappyHourSpots,
              child: const Text('Load happy hour spots'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  showOnlyCurrentHappyHour = !showOnlyCurrentHappyHour;
                });
              },
              child: Text(showOnlyCurrentHappyHour
                  ? 'Show all spots'
                  : 'Show only current happy hour spots'),
            ),
            Expanded(
              child: filteredSpots == null
                  ? const Text("Click the button to load happy hour spots")
                  : filteredSpots.isEmpty
                      ? const Text("No open happy hour spots found")
                      : ListView.builder(
                          itemCount: filteredSpots.length,
                          itemBuilder: (context, index) {
                            return ListTile(
                              title: SpotCard(spot: filteredSpots[index]),
                              onTap: () {
                                openInMaps(filteredSpots[index]);
                              },
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
