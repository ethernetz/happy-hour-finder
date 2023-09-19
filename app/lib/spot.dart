import 'dart:convert';

import 'package:app/env.dart';
import 'package:app/google_place_details.dart';
import 'package:app/google_place_details_cache.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

class Spot {
  final bool checkedForHappyHours;
  final List<HappyHour> happyHours;
  final String url;
  final String name;
  final String uniqueName;
  final String address;
  final double distance;
  final GeoJSONPoint coordinates;
  final String googlePlaceId;

  // Cache variables
  DateTime? lastUpdated;
  HappyHour? currentHappyHour;
  HappyHour? nextHappyHour;

  //Google place cache variables
  String? photoUrl;

  Spot({
    required this.checkedForHappyHours,
    required this.happyHours,
    required this.url,
    required this.name,
    required this.uniqueName,
    required this.address,
    required this.distance,
    required this.coordinates,
    required this.googlePlaceId,
  }) {
    _updateHappyHourCache();
  }

  Future<void> fetchGooglePlaceDetails() async {
    if (googlePlaceDetailsCache.containsKey(googlePlaceId)) {
      photoUrl = googlePlaceDetailsCache[googlePlaceId]!.photoUrl;
    } else {
      final url =
          "https://maps.googleapis.com/maps/api/place/details/json?placeid=$googlePlaceId&fields=photo&key=${Env.googleMapsAPIKey}";
      final response = await http.get(Uri.parse(url));
      final jsonData = jsonDecode(response.body);
      final String fetchedPhotoUrl =
          'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=${jsonData["result"]["photos"][0]["photo_reference"]}&key=${Env.googleMapsAPIKey}';

      photoUrl = fetchedPhotoUrl;

      // Store in the cache
      googlePlaceDetailsCache[googlePlaceId] =
          GooglePlaceDetails(photoUrl: fetchedPhotoUrl);
    }
  }

  // Function to convert JSON object to Spot instance
  factory Spot.fromJson(Map<String, dynamic> json) {
    return Spot(
      checkedForHappyHours: json['checkedForHappyHours'],
      happyHours: (json['happyHours'] as List<dynamic>)
          .map((e) => HappyHour.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      url: json['url'],
      name: json['name'],
      uniqueName: json['uniqueName'],
      address: json['address'],
      coordinates: GeoJSONPoint.fromJson(
        Map<String, dynamic>.from(json['coordinates']),
      ),
      distance: json['distance'],
      googlePlaceId: json['googlePlaceId'],
    );
  }

// Updates the cache with either the current or next happy hour
  void _updateHappyHourCache() {
    DateTime now = DateTime.now();
    String currentDay = DateFormat('EEEE').format(now).toLowerCase();
    String currentTime = DateFormat('HH:mm').format(now);

    HappyHour? foundCurrent;
    HappyHour? foundNext;

    // Create a list of weekdays to handle rolling over to the next day
    List<String> weekdays = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday'
    ];
    int todayIndex = weekdays.indexOf(currentDay);

    // Check for the current or next happy hour
    for (int i = 0; i < 7; i++) {
      String checkDay = weekdays[(todayIndex + i) % 7];
      var dayHappyHours =
          happyHours.where((hh) => hh.day.toLowerCase() == checkDay).toList();
      dayHappyHours.sort((a, b) => a.startTime.compareTo(b.startTime));

      for (var hh in dayHappyHours) {
        // If it's today, then we check the time as well
        if (i == 0) {
          if (isCurrentTimeInHappyHour(currentTime, hh.startTime, hh.endTime)) {
            foundCurrent = hh;
            break; // If we find the current happy hour, we can exit the loop
          } else if (isCurrentTimeBeforeHappyHour(currentTime, hh.startTime)) {
            foundNext ??= hh;
          }
        }
        // If it's a future day and we haven't found the next happy hour yet, assign it
        else if (i > 0 && foundNext == null) {
          foundNext = hh;
          break; // Exit the loop once we find the next happy hour
        }
      }

      if (foundCurrent != null) {
        break; // Exit the outer loop if we found the current happy hour
      }
    }

    // Update the cache variables
    lastUpdated = now;
    currentHappyHour = foundCurrent;
    nextHappyHour = foundNext;
  }

  // Checks if the current time is within a given happy hour time range
  bool isCurrentTimeInHappyHour(
    String currentTime,
    String startTime,
    String endTime,
  ) {
    int ct = int.parse(currentTime.replaceAll(":", ""));
    int st = int.parse(startTime.replaceAll(":", ""));
    int et = int.parse(endTime.replaceAll(":", ""));

    return (ct >= st && ct <= et);
  }

  // Checks if the current time is before a given happy hour start time
  bool isCurrentTimeBeforeHappyHour(
    String currentTime,
    String startTime,
  ) {
    int ct = int.parse(currentTime.replaceAll(":", ""));
    int st = int.parse(startTime.replaceAll(":", ""));

    return (ct < st);
  }
}

class HappyHour {
  final String day;
  final String startTime;
  final String endTime;
  final String deal;
  final bool crossesMidnight;

  HappyHour({
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.deal,
    required this.crossesMidnight,
  });

  // Function to convert JSON object to HappyHour instance
  factory HappyHour.fromJson(Map<String, dynamic> json) {
    return HappyHour(
      day: json['day'],
      startTime: json['startTime'],
      endTime: json['endTime'],
      deal: json['deal'],
      crossesMidnight: json['crossesMidnight'] ?? false,
    );
  }
}

class GeoJSONPoint {
  final String type;
  final List<double> coordinates;

  GeoJSONPoint({required this.type, required this.coordinates});

  // Function to convert JSON object to GeoJSONPoint instance
  factory GeoJSONPoint.fromJson(Map<String, dynamic> json) {
    return GeoJSONPoint(
        type: json['type'],
        coordinates:
            List<double>.from(json['coordinates'].map((x) => x.toDouble())));
  }
}
