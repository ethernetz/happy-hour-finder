import 'dart:async';
import 'dart:ui';

import 'package:app/env.dart';
import 'package:app/get_location.dart';
import 'package:app/providers/map_visible_region_places_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class Map extends StatefulWidget {
  const Map({super.key});

  @override
  State<Map> createState() => MapState();
}

Future<Uint8List?> getBytesFromAsset(String path, int width) async {
  ByteData data = await rootBundle.load(path);
  Codec codec = await instantiateImageCodec(data.buffer.asUint8List(),
      targetWidth: width);
  FrameInfo fi = await codec.getNextFrame();
  return (await fi.image.toByteData(format: ImageByteFormat.png))
      ?.buffer
      .asUint8List();
}

class MapState extends State<Map> {
  @override
  void initState() {
    super.initState();
    setInitialLocation();
  }

  setInitialLocation() async {
    final location = await getLocation();
    // if (location == null) return;
    // final controller = await _controller.future;
    // final cameraPosition = CameraPosition(
    //   target: location,
    //   zoom: 14,
    // );
    // await controller
    //     .animateCamera(CameraUpdate.newCameraPosition(cameraPosition));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MapVisibleRegionPlacesProvider>(
        builder: (context, provider, child) {
      final spots = provider.allSpots;
      return FlutterMap(
        mapController: MapController(),
        options: MapOptions(
          initialCenter: const LatLng(40.776676, -73.971321),
          initialZoom: 14,
          onPositionChanged: (position, hasGesture) {
            provider.updateLocation(position.bounds!);
          },
          cameraConstraint: CameraConstraint.containCenter(
              bounds: LatLngBounds(
            const LatLng(40.821669, -74.016571),
            const LatLng(40.697885, -73.909383),
          )),
        ),
        children: [
          TileLayer(
            urlTemplate:
                'https://api.mapbox.com/styles/v1/ethernetz/clnxlcfzp002b01r73s4h3g2b/tiles/256/{z}/{x}/{y}@2x?access_token=${Env.mapboxAPIKey}',
            additionalOptions: {
              'accessToken': Env.mapboxAPIKey,
              'id': 'mapbox.mapbox-streets-v8',
            },
          ),
          MarkerClusterLayerWidget(
            options: MarkerClusterLayerOptions(
              maxClusterRadius: 45,
              size: const Size(40, 40),
              alignment: Alignment.center,
              markers: spots.values.map((spot) {
                return Marker(
                  width: 40,
                  height: 40,
                  point: spot.coordinates,
                  child: IconButton(
                    icon: const Icon(Icons.location_on),
                    onPressed: () {},
                  ),
                );
              }).toList(),
              builder: (context, markers) {
                return Container(
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.blue),
                  child: Center(
                    child: Text(
                      markers.length.toString(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                );
              },
            ),
          ),
          CurrentLocationLayer(),
        ],
      );
    });
  }
}
