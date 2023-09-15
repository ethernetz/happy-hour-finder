import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:app/spot_card.dart';
import 'package:app/spot.dart';
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<Spot>? allSpots;
  List<Spot>? currentSpots;

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
        allSpots = [];
        currentSpots = [];
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
        allSpots = (response.data as List).map((spotJson) {
          return Spot.fromJson(Map<String, dynamic>.from(spotJson));
        }).toList();
        currentSpots =
            allSpots!.where((spot) => spot.currentHappyHour != null).toList();
        showOnlyCurrentHappyHour = currentSpots!.isNotEmpty;
      });
    } catch (e) {
      setState(() {
        if (kDebugMode) print(e);
        allSpots = [];
        currentSpots = [];
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
    var spots = showOnlyCurrentHappyHour ? currentSpots : allSpots;
    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return [
            SliverAppBar(
              collapsedHeight: 80,
              expandedHeight: 80,
              floating: false,
              pinned: false,
              backgroundColor: Colors.transparent,
              elevation: 0.0,
              flexibleSpace: Padding(
                padding: const EdgeInsets.fromLTRB(20, 50, 50, 0.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Happili",
                      style: TextStyle(
                        fontSize: 26, // Increase the font size here
                      ),
                    ),
                    if (currentSpots != null && currentSpots!.isNotEmpty)
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        color: showOnlyCurrentHappyHour
                            ? Colors.white12
                            : const Color.fromRGBO(255, 255, 255, 0.08),
                        borderRadius: BorderRadius.circular(5.0),
                        onPressed: () {
                          setState(() {
                            showOnlyCurrentHappyHour =
                                !showOnlyCurrentHappyHour;
                          });
                        },
                        child: Row(
                          children: [
                            if (showOnlyCurrentHappyHour) ...[
                              const Icon(
                                CupertinoIcons.check_mark,
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 5),
                            ],
                            Text(
                              "Open now",
                              style: TextStyle(
                                fontSize: 14,
                                color: showOnlyCurrentHappyHour
                                    ? Colors.white
                                    : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      )
                  ],
                ),
              ),
            )
          ];
        },
        body: LiquidPullToRefresh(
          key: _refreshIndicatorKey,
          onRefresh: _callGetHappyHourSpots,
          animSpeedFactor: 10,
          springAnimationDurationInMilliseconds: 500,
          showChildOpacityTransition: false,
          child: spots == null
              ? const Padding(
                  padding: EdgeInsets.only(bottom: 70.0),
                  child: SpinKitWave(
                    color: Colors.white,
                    type: SpinKitWaveType.start,
                    duration: Duration(milliseconds: 800),
                  ),
                )
              : spots.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        Text("No happy hour spots found"),
                      ],
                    )
                  : ListView.builder(
                      itemCount: spots.length,
                      padding: const EdgeInsets.only(top: 10.0),
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          child: SpotCard(
                            spot: spots[index],
                          ),
                        );
                      },
                    ),
        ),
      ),
    );
  }
}
