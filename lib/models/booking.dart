class Booking {
  const Booking({
    required this.id,
    required this.spotId,
    required this.guestId,
    required this.startTs,
    required this.endTs,
    required this.priceTotal,
    required this.status,
  });

  final String id;
  final String spotId;
  final String guestId;
  final DateTime startTs;
  final DateTime endTs;
  final double priceTotal;
  final String status;

  Booking copyWith({
    String? id,
    String? spotId,
    String? guestId,
    DateTime? startTs,
    DateTime? endTs,
    double? priceTotal,
    String? status,
  }) {
    return Booking(
      id: id ?? this.id,
      spotId: spotId ?? this.spotId,
      guestId: guestId ?? this.guestId,
      startTs: startTs ?? this.startTs,
      endTs: endTs ?? this.endTs,
      priceTotal: priceTotal ?? this.priceTotal,
      status: status ?? this.status,
    );
  }

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'] as String,
      spotId: json['spot_id'] as String,
      guestId: json['guest_id'] as String,
      startTs: DateTime.parse(json['start_ts'] as String),
      endTs: DateTime.parse(json['end_ts'] as String),
      priceTotal: (json['price_total'] as num).toDouble(),
      status: json['status'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'spot_id': spotId,
      'guest_id': guestId,
      'start_ts': startTs.toIso8601String(),
      'end_ts': endTs.toIso8601String(),
      'price_total': priceTotal,
      'status': status,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Booking &&
        other.id == id &&
        other.spotId == spotId &&
        other.guestId == guestId &&
        other.startTs == startTs &&
        other.endTs == endTs &&
        other.priceTotal == priceTotal &&
        other.status == status;
  }

  @override
  int get hashCode => Object.hash(
        id,
        spotId,
        guestId,
        startTs,
        endTs,
        priceTotal,
        status,
      );
}
