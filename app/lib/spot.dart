class Spot {
  final bool checkedForHappyHours;
  final List<HappyHour>? happyHours;
  final String url;
  final String name;
  final String uniqueName;
  final String address;
  final GeoJSONPoint coordinates;

  Spot({
    required this.checkedForHappyHours,
    this.happyHours,
    required this.url,
    required this.name,
    required this.uniqueName,
    required this.address,
    required this.coordinates,
  });

  // Function to convert JSON object to Spot instance
  factory Spot.fromJson(Map<String, dynamic> json) {
    return Spot(
      checkedForHappyHours: json['checkedForHappyHours'],
      happyHours: (json['happyHours'] as List<dynamic>?)
          ?.map((e) => HappyHour.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      url: json['url'],
      name: json['name'],
      uniqueName: json['uniqueName'],
      address: json['address'],
      coordinates: GeoJSONPoint.fromJson(
        Map<String, dynamic>.from(json['coordinates']),
      ),
    );
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
