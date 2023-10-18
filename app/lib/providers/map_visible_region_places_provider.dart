import 'dart:async';
import 'dart:math';
import 'package:app/spot.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

double calculateDistance(LatLng a, LatLng b) {
  const R = 6371e3; // Earth radius in meters
  var lat1 = a.latitude * pi / 180;
  var lat2 = b.latitude * pi / 180;
  var dlat = (lat2 - lat1);
  var dlng = (b.longitude - a.longitude) * pi / 180;

  var x = sin(dlat / 2) * sin(dlat / 2) +
      cos(lat1) * cos(lat2) * sin(dlng / 2) * sin(dlng / 2);
  var c = 2 * atan2(sqrt(x), sqrt(1 - x));

  return R * c;
}

class MapVisibleRegionPlacesProvider with ChangeNotifier {
  final List<Spot> _allSpots = [];
  List<Spot> _latestSpotsSorted = [];
  Timer? _debounce;

  List<Spot> get allSpots => _allSpots;
  List<Spot> get latestSpotsSorted => _latestSpotsSorted;

  Future<void> updateLocation(LatLngBounds newLocation) async {
    _debounce?.cancel();

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
        [sw.longitude, sw.latitude],
        [ne.longitude, ne.latitude]
      ];

      final Map<String, dynamic> payload = {'boxCoordinates': boxCoordinates};

      try {
        final HttpsCallableResult response = await callable.call(payload);
        List<Spot> newSpots = (response.data as List).map((spotJson) {
          return Spot.fromJson(Map<String, dynamic>.from(spotJson));
        }).toList();

        // Merging newSpots into _allSpots, avoiding duplicates
        for (var newSpot in newSpots) {
          if (!_allSpots.any((existingSpot) =>
              existingSpot.googlePlaceId == newSpot.googlePlaceId)) {
            _allSpots.add(newSpot);
          }
        }

        // Sort newSpots by distance from cameraPosition and update _latestSpotsSorted
        _latestSpotsSorted = List.from(newSpots);
        // _latestSpotsSorted.sort((a, b) =>
        //     calculateDistance(cameraPosition, a.coordinates)
        //         .compareTo(calculateDistance(cameraPosition, b.coordinates)));

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
