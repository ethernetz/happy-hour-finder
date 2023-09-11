import 'package:intl/intl.dart';

class Spot {
  final bool checkedForHappyHours;
  final List<HappyHour> happyHours;
  final String url;
  final String name;
  final String uniqueName;
  final String address;
  final double distance;
  final GeoJSONPoint coordinates;

  Spot({
    required this.checkedForHappyHours,
    required this.happyHours,
    required this.url,
    required this.name,
    required this.uniqueName,
    required this.address,
    required this.coordinates,
    required this.distance,
  });

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
    );
  }

  HappyHour? getCurrentHappyHour() {
    // Get current day and time
    DateTime now = DateTime.now();
    String currentDay = DateFormat('EEEE').format(now).toLowerCase();
    String currentTime = DateFormat('HH:mm').format(now);

    // String currentDay = "monday";
    // String currentTime = "20:00";

    for (HappyHour hh in happyHours) {
      if (hh.day.toLowerCase() == currentDay) {
        // Check if the current time is within the Happy Hour time range
        if (isCurrentTimeInHappyHour(
            currentTime, hh.startTime, hh.endTime, hh.crossesMidnight)) {
          return hh;
        }
      }
    }
    return null;
  }

  bool isCurrentTimeInHappyHour(String currentTime, String startTime,
      String endTime, bool crossesMidnight) {
    int ct = int.parse(currentTime.replaceAll(":", ""));
    int st = int.parse(startTime.replaceAll(":", ""));
    int et = int.parse(endTime.replaceAll(":", ""));

    if (crossesMidnight) {
      return (ct >= st || ct <= et);
    } else {
      return (ct >= st && ct <= et);
    }
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
