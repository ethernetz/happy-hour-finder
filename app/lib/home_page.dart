import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:app/spot_card.dart';
import 'package:map_launcher/map_launcher.dart';
import 'package:app/spot.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});
  @override
  State<MyHomePage> createState() => _MyHomePageState();
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

class _MyHomePageState extends State<MyHomePage> {
  List<Spot>? spots;
  bool showOnlyCurrentHappyHour = false;

  Future<void> _callGetHappyHourSpots() async {
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
      backgroundColor: Colors.grey[900],
      body: SingleChildScrollView(
        child: Center(
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
              filteredSpots == null
                  ? const Text("Click the button to load happy hour spots")
                  : filteredSpots.isEmpty
                      ? const Text("No open happy hour spots found")
                      : ListView.builder(
                          itemCount: filteredSpots.length,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              child: SpotCard(
                                spot: filteredSpots[index],
                              ),
                            );
                          },
                        ),
            ],
          ),
        ),
      ),
    );
  }
}
