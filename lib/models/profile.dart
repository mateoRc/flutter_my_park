class Profile {
  const Profile({
    required this.id,
    this.name,
    this.phone,
    required this.createdAt,
  });

  final String id;
  final String? name;
  final String? phone;
  final DateTime createdAt;

  Profile copyWith({
    String? id,
    String? name,
    String? phone,
    DateTime? createdAt,
  }) {
    return Profile(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      name: json['name'] as String?,
      phone: json['phone'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Profile &&
        other.id == id &&
        other.name == name &&
        other.phone == phone &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(id, name, phone, createdAt);
}
