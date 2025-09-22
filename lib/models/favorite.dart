class Favorite {
  const Favorite({
    required this.userId,
    required this.spotId,
  });

  final String userId;
  final String spotId;

  Favorite copyWith({String? userId, String? spotId}) {
    return Favorite(
      userId: userId ?? this.userId,
      spotId: spotId ?? this.spotId,
    );
  }

  factory Favorite.fromJson(Map<String, dynamic> json) {
    return Favorite(
      userId: json['user_id'] as String,
      spotId: json['spot_id'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'user_id': userId,
      'spot_id': spotId,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Favorite &&
        other.userId == userId &&
        other.spotId == spotId;
  }

  @override
  int get hashCode => Object.hash(userId, spotId);
}
