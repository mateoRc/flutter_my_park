class SpotPhoto {
  const SpotPhoto({
    required this.id,
    required this.spotId,
    required this.path,
    required this.order,
  });

  final String id;
  final String spotId;
  final String path;
  final int order;

  SpotPhoto copyWith({
    String? id,
    String? spotId,
    String? path,
    int? order,
  }) {
    return SpotPhoto(
      id: id ?? this.id,
      spotId: spotId ?? this.spotId,
      path: path ?? this.path,
      order: order ?? this.order,
    );
  }

  factory SpotPhoto.fromJson(Map<String, dynamic> json) {
    return SpotPhoto(
      id: json['id'] as String,
      spotId: json['spot_id'] as String,
      path: json['path'] as String,
      order: json['order'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'spot_id': spotId,
      'path': path,
      'order': order,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SpotPhoto &&
        other.id == id &&
        other.spotId == spotId &&
        other.path == path &&
        other.order == order;
  }

  @override
  int get hashCode => Object.hash(id, spotId, path, order);
}
