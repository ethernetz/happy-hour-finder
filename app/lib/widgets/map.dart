import 'dart:async';

import 'package:app/providers/map_visible_region_places_provider.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:provider/provider.dart';

class Map extends StatefulWidget {
  const Map({super.key});

  @override
  State<Map> createState() => MapState();
}

class MapState extends State<Map> {
  Future<void> _onCameraMove(CameraPosition? position) async {
    final mapVisibleRegionProvider =
        Provider.of<MapVisibleRegionPlacesProvider>(context, listen: false);
    final controller = await _controller.future;
    final visibleRegion = await controller.getVisibleRegion();
    mapVisibleRegionProvider.updateLocation(visibleRegion);
  }

  @override
  void initState() {
    super.initState();
    setInitialLocation();
  }

  setInitialLocation() async {
    final Location location = Location();
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        return null;
      }
    }

    PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        return null;
      }
    }

    final locationData = await location.getLocation();
    final controller = await _controller.future;
    final cameraPosition = CameraPosition(
        target: LatLng(locationData.latitude!, locationData.longitude!),
        zoom: 14.4746);
    await controller
        .animateCamera(CameraUpdate.newCameraPosition(cameraPosition));
  }

  final Completer<GoogleMapController> _controller =
      Completer<GoogleMapController>();

  @override
  Widget build(BuildContext context) {
    return Consumer<MapVisibleRegionPlacesProvider>(
        builder: (context, provider, child) {
      final spots = provider.allSpots;
      return GoogleMap(
        myLocationEnabled: true,
        tiltGesturesEnabled: false,
        onCameraMove: _onCameraMove,
        mapType: MapType.hybrid,
        initialCameraPosition: const CameraPosition(
          target: LatLng(37.42796133580664, -122.085749655962),
          zoom: 14.4746,
        ),
        onMapCreated: (GoogleMapController controller) {
          _controller.complete(controller);
        },
        markers: spots
            .map(
              (spot) => Marker(
                markerId: MarkerId(spot.googlePlaceId),
                position: LatLng(spot.coordinates.coordinates[1],
                    spot.coordinates.coordinates[0]),
              ),
            )
            .toSet(),
      );
    });
  }
}
