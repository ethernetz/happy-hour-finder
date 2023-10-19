import 'dart:async';
import 'package:app/spot.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapVisibleRegionPlacesProvider with ChangeNotifier {
  final Map<String, Spot> _allSpots = {}; // Changed to a map
  List<String> _latestSpotIds = [];
  Timer? _debounce;

  Map<String, Spot> get allSpots => _allSpots;
  List<Spot> get latestSpotsSorted =>
      _latestSpotIds.map((spotId) => _allSpots[spotId]!).toList();

  Future<void> updateLocation(LatLngBounds newLocation) async {
    _debounce?.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
        'findSpotsInArea',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 30),
        ),
      );

      LatLng sw = newLocation.southWest;
      LatLng ne = newLocation.northEast;

      List<List<double>> boxCoordinates = [
        [sw.longitude, sw.latitude],
        [ne.longitude, ne.latitude]
      ];

      final Map<String, dynamic> payload = {'boxCoordinates': boxCoordinates};

      try {
        final HttpsCallableResult response = await callable.call(payload);
        List<Spot> newSpots = (response.data as List).map((spotJson) {
          return Spot.fromJson(Map<String, dynamic>.from(spotJson));
        }).toList();

        for (var newSpot in newSpots) {
          _allSpots[newSpot.googlePlaceId] = newSpot;
        }

        _latestSpotIds = newSpots.map((spot) => spot.googlePlaceId).toList();

        if (kDebugMode) {
          print(_allSpots.length);
        }
        notifyListeners();
      } catch (e) {
        if (kDebugMode) {
          print(e);
        }
        notifyListeners();
      }
    });
  }
}
