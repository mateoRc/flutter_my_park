import 'package:flutter/foundation.dart';

class Spot {
  Spot({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.lat,
    required this.lng,
    this.address,
    this.priceHour,
    this.priceDay,
    List<String>? amenities,
    required this.createdAt,
  }) : amenities = List.unmodifiable(amenities ?? const []);

  final String id;
  final String ownerId;
  final String title;
  final double lat;
  final double lng;
  final String? address;
  final double? priceHour;
  final double? priceDay;
  final List<String> amenities;
  final DateTime createdAt;

  Spot copyWith({
    String? id,
    String? ownerId,
    String? title,
    double? lat,
    double? lng,
    String? address,
    double? priceHour,
    double? priceDay,
    List<String>? amenities,
    DateTime? createdAt,
  }) {
    return Spot(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      title: title ?? this.title,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      address: address ?? this.address,
      priceHour: priceHour ?? this.priceHour,
      priceDay: priceDay ?? this.priceDay,
      amenities: amenities ?? this.amenities,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory Spot.fromJson(Map<String, dynamic> json) {
    return Spot(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      title: json['title'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      address: json['address'] as String?,
      priceHour: (json['price_hour'] as num?)?.toDouble(),
      priceDay: (json['price_day'] as num?)?.toDouble(),
      amenities: (json['amenities'] as List?)
              ?.map((item) => item as String)
              .toList() ??
          const [],
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'owner_id': ownerId,
      'title': title,
      'lat': lat,
      'lng': lng,
      if (address != null) 'address': address,
      if (priceHour != null) 'price_hour': priceHour,
      if (priceDay != null) 'price_day': priceDay,
      'amenities': amenities,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Spot &&
        other.id == id &&
        other.ownerId == ownerId &&
        other.title == title &&
        other.lat == lat &&
        other.lng == lng &&
        other.address == address &&
        other.priceHour == priceHour &&
        other.priceDay == priceDay &&
        listEquals(other.amenities, amenities) &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(
        id,
        ownerId,
        title,
        lat,
        lng,
        address,
        priceHour,
        priceDay,
        Object.hashAll(amenities),
        createdAt,
      );
}
