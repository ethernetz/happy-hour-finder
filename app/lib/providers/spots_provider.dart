import 'dart:async';
import 'package:app/spot.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class SpotsProvider with ChangeNotifier {
  Map<String, Spot>? _allSpots; // Changed to a map
  List<String> _spotIdsInCamera = [];
  Timer? _getNewSpotsInCameraDebounce;
  Timer? _updateSpotIdsInCameraDebounce;
  String? _selectedSpotId;

  Map<String, Spot>? get allSpots => _allSpots;
  List<Spot>? get spotsInCamera {
    if (_allSpots == null) return null;
    return _spotIdsInCamera.map((spotId) => _allSpots![spotId]!).toList();
  }

  String? get selectedSpotId => _selectedSpotId;
  Spot? get selectedSpot => _allSpots?[_selectedSpotId];

  void _addSpot(Spot spot) {
    if (_allSpots == null) {
      _allSpots = {spot.googlePlaceId: spot};
    } else {
      _allSpots![spot.googlePlaceId] = spot;
    }
  }

  Future<void> handleCameraPositionChanged(LatLngBounds newLocation) async {
    _getNewSpotsInCameraDebounce?.cancel();
    _getNewSpotsInCameraDebounce =
        Timer(const Duration(milliseconds: 500), () async {
      final newSpots = await getNewSpotsInCamera(newLocation);
      if (newSpots == null) return;
      for (var spot in newSpots) {
        _addSpot(spot);
      }
      final allSpotValues = _allSpots?.values.toList();
      if (allSpotValues == null) return;
      _spotIdsInCamera = getUpdatedSpotIdsInCamera(newLocation, allSpotValues);
      notifyListeners();
    });

    _updateSpotIdsInCameraDebounce?.cancel();
    _updateSpotIdsInCameraDebounce = Timer(
      const Duration(milliseconds: 2),
      () {
        final allSpotValues = _allSpots?.values.toList();
        if (allSpotValues == null) return;
        _spotIdsInCamera =
            getUpdatedSpotIdsInCamera(newLocation, allSpotValues);
        notifyListeners();
      },
    );
  }

  void handleSpotSelected(String spotId) {
    _selectedSpotId = spotId;
    notifyListeners();
  }

  void handleUnselectSpot() {
    _selectedSpotId = null;
    notifyListeners();
  }
}

List<String> getUpdatedSpotIdsInCamera(
    LatLngBounds newLocation, List<Spot> spots) {
  LatLng sw = newLocation.southWest;
  LatLng ne = newLocation.northEast;

  List<String> newSpotIdsInCamera = [];

  for (var spot in spots) {
    if (spot.coordinates.latitude > sw.latitude &&
        spot.coordinates.latitude < ne.latitude &&
        spot.coordinates.longitude > sw.longitude &&
        spot.coordinates.longitude < ne.longitude) {
      newSpotIdsInCamera.add(spot.googlePlaceId);
    }
  }

  return newSpotIdsInCamera;
}

Future<List<Spot>?> getNewSpotsInCamera(LatLngBounds newLocation) async {
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
    return (response.data as List).map((spotJson) {
      return Spot.fromJson(Map<String, dynamic>.from(spotJson));
    }).toList();
  } catch (e) {
    if (kDebugMode) {
      print(e);
    }
    return null;
  }
}
