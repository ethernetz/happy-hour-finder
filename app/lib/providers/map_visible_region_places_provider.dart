import 'dart:async';
import 'package:app/spot.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapVisibleRegionPlacesProvider with ChangeNotifier {
  List<Spot> _allSpots = [];
  Timer? _debounce;

  List<Spot> get allSpots => _allSpots;

  Future<void> updateLocation(LatLngBounds newLocation) async {
    // Cancel any pending timers
    _debounce?.cancel();

    // Start a new timer
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
        'findSpotsInArea',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 30),
        ),
      );

      LatLng sw = newLocation.southwest;
      LatLng ne = newLocation.northeast;

      List<List<double>> boxCoordinates = [
        [sw.longitude, sw.latitude], // bottom left
        [ne.longitude, ne.latitude] // top right
      ];

      final Map<String, dynamic> payload = {'boxCoordinates': boxCoordinates};

      try {
        final HttpsCallableResult response = await callable.call(payload);
        _allSpots = (response.data as List).map((spotJson) {
          return Spot.fromJson(Map<String, dynamic>.from(spotJson));
        }).toList();
        print(_allSpots.length);
        notifyListeners();
      } catch (e) {
        print(e);
        notifyListeners();
      }
    });
  }
}
