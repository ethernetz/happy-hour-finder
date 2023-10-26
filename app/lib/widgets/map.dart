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
  final mapController = MapController();

  setInitialLocation() async {
    final location = await getLocation();
    if (location == null) {
      return;
    }
    mapController.move(location, 16);
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        // initialCenter: const LatLng(40.776676, -73.971321),
        // initialZoom: 14,
        // cameraConstraint: CameraConstraint.containCenter(
        //     bounds: LatLngBounds(
        //   const LatLng(40.821669, -74.016571),
        //   const LatLng(40.697885, -73.909383),
        // )),
        onMapReady: () {
          setInitialLocation();
        },
        onPositionChanged: (position, hasGesture) {
          context
              .read<MapVisibleRegionPlacesProvider>()
              .handleCameraPositionChanged(position.bounds!);
        },
        center: const LatLng(40.776676, -73.971321),
        zoom: 12,
        minZoom: 12,
        bounds: LatLngBounds(
          const LatLng(40.821669, -74.016571),
          const LatLng(40.697885, -73.909383),
        ),
      ),
      children: [
        TileLayer(
          urlTemplate:
              'https://api.mapbox.com/styles/v1/ethernetz/clnxlcfzp002b01r73s4h3g2b/tiles/256/{z}/{x}/{y}@2x?access_token=${Env.mapboxAPIKey}',
          additionalOptions: {
            'accessToken': Env.mapboxAPIKey,
            'id': 'mapbox.mapbox-streets-v8',
          },
          fallbackUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        ),
        Consumer<MapVisibleRegionPlacesProvider>(
            builder: (context, provider, child) {
          final spots = provider.allSpots;
          return MarkerClusterLayerWidget(
            options: MarkerClusterLayerOptions(
              onMarkerTap: (marker) {
                context
                    .read<MapVisibleRegionPlacesProvider>()
                    .handleSpotSelected((marker.key as ValueKey).value);
              },
              maxClusterRadius: 25,
              computeSize: (markers) {
                double minDiameter = 20.0;
                double maxDiameter = 40.0;

                double diameter;
                int markerCount = markers.length;

                if (markerCount >= 15) {
                  diameter = maxDiameter;
                } else if (markerCount <= 0) {
                  diameter = minDiameter;
                } else {
                  double range = maxDiameter - minDiameter;
                  diameter = minDiameter + (range * (markerCount / 15.0));
                }

                return Size(diameter, diameter);
              },
              markers: spots.values.map((spot) {
                return Marker(
                  key: Key(spot.googlePlaceId),
                  width:
                      80, // You may adjust the width based on your layout requirements
                  height:
                      60, // You may adjust the height based on your layout requirements
                  point: spot.coordinates,
                  builder: (context) => Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        spot.name,
                        maxLines: 2, // Maximum of 2 lines
                        overflow:
                            TextOverflow.ellipsis, // Ellipsis for overflow
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      Icon(
                        Icons.location_on,
                        color: provider.selectedSpotId == spot.googlePlaceId
                            ? Colors.amber
                            : Colors.white,
                      ),
                    ],
                  ),
                );
              }).toList(),
              builder: (context, markers) {
                return Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  child: Center(
                    child: Text(
                      markers.length.toString(),
                      style: const TextStyle(color: Colors.black),
                    ),
                  ),
                );
              },
            ),
          );
        }),
        IgnorePointer(
          child: CurrentLocationLayer(),
        ),
      ],
    );
  }
}
