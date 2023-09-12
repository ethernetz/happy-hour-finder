import 'package:app/spot.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SpotCard extends StatelessWidget {
  final Spot spot;
  const SpotCard({super.key, required this.spot});

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

  @override
  Widget build(BuildContext context) {
    HappyHour? currentHappyHour = spot.getCurrentHappyHour();
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Spot name
          Text(
            spot.name,
            style: const TextStyle(
              fontSize: 20.0,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8.0),

          // Open/Closed Status
          if (currentHappyHour != null)
            Text(
              'Happy hour until ${convertTo12Hour(currentHappyHour.endTime)}!',
              style: const TextStyle(
                color: Colors.green,
                fontSize: 16.0,
              ),
            ),
          const SizedBox(height: 8.0),

          // Happy Hour Deal
          if (spot.happyHours.isNotEmpty &&
              spot.happyHours[0].deal != 'Unknown')
            Text(
              spot.happyHours[0].deal,
              style: const TextStyle(
                fontSize: 16.0,
                color: Colors.white,
              ),
            ),
          const SizedBox(height: 8.0),

          // Distance
          Text(
            americanizeDistance(spot.distance),
            style: TextStyle(
              fontSize: 16.0,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}

String convertTo12Hour(String time24) {
  final DateTime tempDate = DateFormat("HH:mm").parse(time24);
  return DateFormat("h:mm a").format(tempDate).toLowerCase();
}
