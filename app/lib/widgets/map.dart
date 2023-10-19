import 'dart:async';
import 'dart:ui';

import 'package:app/get_location.dart';
import 'package:app/providers/map_visible_region_places_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';

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
        options: MapOptions(),
        children: [
          TileLayer(
            urlTemplate:
                "https://api.mapbox.com/styles/v1/eyeseediagnostics/ckm6fhoeuc9f617o5ymjl9152/tiles/256/{z}/{x}/{y}@2x?access_token=pk.eyJ1IjoiZXllc2VlZGlhZ25vc3RpY3MiLCJhIjoiY2ttNmZkN3pvMG5wczJvcHIzNXM0dXMydiJ9.OHEYuFFxLxK0fzFlqPU7WQ",
            additionalOptions: {
              'accessToken':
                  'pk.eyJ1IjoiZXllc2VlZGlhZ25vc3RpY3MiLCJhIjoiY2ttNmZkN3pvMG5wczJvcHIzNXM0dXMydiJ9.OHEYuFFxLxK0fzFlqPU7WQ'
            },
          ),
        ],
      );
    });
  }
}
