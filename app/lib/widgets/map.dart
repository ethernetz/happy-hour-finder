import 'dart:async';

import 'package:app/get_location.dart';
import 'package:app/providers/map_visible_region_places_provider.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
    final location = await getLocation();
    if (location == null) return;
    final controller = await _controller.future;
    final cameraPosition = CameraPosition(
      target: location,
      zoom: 14,
    );
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
          target: LatLng(40.776676, -73.971321),
          zoom: 14,
        ),
        cameraTargetBounds: CameraTargetBounds(
          LatLngBounds(
            northeast: const LatLng(40.833619, -73.846932),
            southwest: const LatLng(40.691811, -74.054667),
          ),
        ),
        onMapCreated: (GoogleMapController controller) {
          _controller.complete(controller);
        },
        markers: spots
            .map(
              (spot) => Marker(
                markerId: MarkerId(spot.googlePlaceId),
                position: spot.coordinates,
              ),
            )
            .toSet(),
      );
    });
  }
}
