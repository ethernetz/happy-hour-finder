import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:app/spot_card.dart';
import 'package:app/spot.dart';
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<Spot>? spots;
  bool showOnlyCurrentHappyHour = false;
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();

  @override
  void initState() {
    super.initState();
    _callGetHappyHourSpots();
  }

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
        ? spots?.where((spot) => spot.currentHappyHour != null).toList()
        : spots;
    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 50.0,
              backgroundColor: Colors.transparent,
              elevation: 0.0,
              floating: false,
              pinned: false,
              flexibleSpace: Padding(
                padding: const EdgeInsets.fromLTRB(50, 50, 50, 0.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Happili"),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          showOnlyCurrentHappyHour = !showOnlyCurrentHappyHour;
                        });
                      },
                      child: Text(showOnlyCurrentHappyHour
                          ? 'Show all spots'
                          : 'Show current'),
                    ),
                  ],
                ),
              ),
            ),
          ];
        },
        body: LiquidPullToRefresh(
          key: _refreshIndicatorKey,
          onRefresh: _callGetHappyHourSpots,
          animSpeedFactor: 10,
          springAnimationDurationInMilliseconds: 500,
          showChildOpacityTransition: false,
          child: filteredSpots == null
              ? const Center(child: Text("Getting your happy hour spots"))
              : filteredSpots.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        Text("No happy hour spots found"),
                      ],
                    )
                  : ListView.builder(
                      itemCount: filteredSpots.length,
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
        ),
      ),
    );
  }
}
