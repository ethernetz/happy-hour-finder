import 'dart:async';
import 'dart:ui';

import 'package:app/env.dart';
import 'package:app/get_location.dart';
import 'package:app/providers/spots_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';
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

class MapState extends State<Map> with TickerProviderStateMixin {
  late final mapController = AnimatedMapController(vsync: this);

  @override
  void dispose() {
    mapController.dispose();
    super.dispose();
  }

  setCurrentLocation() async {
    final location = await getLocation();
    if (location == null) {
      return;
    }
    mapController.animateTo(
      dest: location,
      zoom: 17,
    );
  }

  String? previousSelectedSpotId;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Selector<SpotsProvider, String?>(
            selector: (_, provider) => provider.selectedSpotId,
            builder: (context, selectedSpotId, child) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (selectedSpotId != null &&
                    selectedSpotId != previousSelectedSpotId) {
                  mapController.animateTo(
                    dest: context
                        .read<SpotsProvider>()
                        .allSpots![selectedSpotId]!
                        .coordinates,
                    zoom: 17,
                  );
                }
                previousSelectedSpotId = selectedSpotId;
              });
              return FlutterMap(
                mapController: mapController.mapController,
                options: MapOptions(
                  // initialCenter: const LatLng(40.776676, -73.971321),
                  // initialZoom: 14,
                  // cameraConstraint: CameraConstraint.containCenter(
                  //     bounds: LatLngBounds(
                  //   const LatLng(40.821669, -74.016571),
                  //   const LatLng(40.697885, -73.909383),
                  // )),
                  onMapReady: () {
                    setCurrentLocation();
                  },
                  onPositionChanged: (position, hasGesture) {
                    context
                        .read<SpotsProvider>()
                        .handleCameraPositionChanged(position.bounds!);
                  },
                  center: const LatLng(40.776676, -73.971321),
                  zoom: 14,
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
                    fallbackUrl:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  ),
                  Consumer<SpotsProvider>(builder: (context, provider, child) {
                    final spots = provider.allSpots;
                    if (spots == null) {
                      return Container();
                    }
                    return MarkerClusterLayerWidget(
                      options: MarkerClusterLayerOptions(
                        onMarkerTap: (marker) {
                          context.read<SpotsProvider>().handleSpotSelected(
                              (marker.key as ValueKey).value);
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
                            diameter =
                                minDiameter + (range * (markerCount / 15.0));
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
                                  overflow: TextOverflow
                                      .ellipsis, // Ellipsis for overflow
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                Icon(
                                  Icons.location_on,
                                  color: provider.selectedSpotId ==
                                          spot.googlePlaceId
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
            }),
        Positioned(
          top: 75,
          right: 20,
          child: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8.0),
                  color: Colors.white.withOpacity(0.08),
                ),
                child: CupertinoButton(
                  padding: const EdgeInsets.all(8),
                  child: const Icon(
                    CupertinoIcons.location_fill,
                    size: 25,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    setCurrentLocation();
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
