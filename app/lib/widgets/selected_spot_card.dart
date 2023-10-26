import 'package:app/providers/map_visible_region_places_provider.dart';
import 'package:app/spot.dart';
import 'package:app/string_extension.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:map_launcher/map_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

class SelectedSpotCard extends StatelessWidget {
  final Spot spot;
  const SelectedSpotCard({super.key, required this.spot});

  String americanizeDistance(double distanceInMeters) {
    const double meterToFootConversion = 3.28084;
    const double meterToMileConversion = 1609.34;
    if (distanceInMeters < meterToMileConversion) {
      final distanceInFeet = distanceInMeters * meterToFootConversion;
      return '${distanceInFeet.toStringAsFixed(0)} ft';
    } else {
      final distanceInMiles = distanceInMeters / meterToMileConversion;
      return '${distanceInMiles.toStringAsFixed(1)} miles';
    }
  }

  Future<void> openInMaps() async {
    final availableMaps = await MapLauncher.installedMaps;

    await availableMaps.first.showDirections(
      destination:
          Coords(spot.coordinates.latitude, spot.coordinates.longitude),
      destinationTitle: spot.name,
      directionsMode: DirectionsMode.walking,
    );
  }

  @override
  Widget build(BuildContext context) {
    HappyHour? currentHappyHour = spot.currentHappyHour;
    HappyHour? nextHappyHour =
        spot.nextHappyHour; // Assuming you've implemented this method

    String timeText = "";
    Color timeColor = Colors.white;
    String dealText = "";

    if (currentHappyHour != null) {
      timeText =
          'Happy hour until ${convertTo12Hour(currentHappyHour.endTime)}!';
      timeColor = Colors.green;
      dealText = currentHappyHour.deal;
    } else if (nextHappyHour != null) {
      final List<String> daysOfWeek = [
        'sunday',
        'monday',
        'tuesday',
        'wednesday',
        'thursday',
        'friday',
        'saturday',
      ];

      String currentDay =
          DateFormat('EEEE').format(DateTime.now()).toLowerCase();
      int currentDayIndex = daysOfWeek.indexOf(currentDay);
      int nextDayIndex =
          (currentDayIndex + 1) % 7; // next day, loop to start if it's Saturday
      String nextDayAfterCurrent = daysOfWeek[nextDayIndex];

      String nextDay = nextHappyHour.day.toLowerCase();

      if (nextDay == currentDay) {
        timeText = 'Starts ${convertTo12Hour(nextHappyHour.startTime)}';
      } else if (nextDay == nextDayAfterCurrent) {
        timeText =
            'Starts tomorrow at ${convertTo12Hour(nextHappyHour.startTime)}';
      } else {
        timeText =
            'Starts ${nextDay.capitalize()} at ${convertTo12Hour(nextHappyHour.startTime)}';
      }
      dealText = nextHappyHour.deal;
      timeColor = Colors.yellow;
    }

    return FutureBuilder(
      future: spot.fetchGooglePlaceDetails(),
      builder: (BuildContext context, AsyncSnapshot<void> snapshot) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        spot.name,
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                        softWrap: true, // this will make text wrap to next line
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      CupertinoIcons.xmark_circle_fill,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      context
                          .read<MapVisibleRegionPlacesProvider>()
                          .handleUnselectSpot();
                    },
                  ),
                ],
              ),

              const SizedBox(height: 8.0),

              Text(
                timeText,
                style: TextStyle(
                  color: timeColor,
                  fontSize: 16.0,
                ),
              ),
              const SizedBox(height: 8.0),

              // Happy Hour Deal
              if (dealText != 'Unknown')
                Text(
                  dealText,
                  style: const TextStyle(
                    fontSize: 16.0,
                    color: Colors.white,
                  ),
                ),
              const SizedBox(height: 8.0),
              if (spot.photoUrl != null)
                CachedNetworkImage(
                  imageUrl: spot.photoUrl!,
                  height: 100,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      const CircularProgressIndicator(),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                )
            ],
          ),
        ),
      ),
    );
  }
}

String convertTo12Hour(String time24) {
  final DateTime tempDate = DateFormat("HH:mm").parse(time24);
  return DateFormat("h:mm a").format(tempDate).toLowerCase();
}
