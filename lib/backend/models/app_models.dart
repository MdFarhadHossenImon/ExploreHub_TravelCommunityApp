class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.handle,
    required this.bio,
    required this.avatarUrl,
    required this.homeCity,
    required this.stats,
  });

  final String id;
  final String email;
  final String name;
  final String handle;
  final String bio;
  final String avatarUrl;
  final String homeCity;
  final UserStats stats;

  AppUser copyWith({
    String? id,
    String? email,
    String? name,
    String? handle,
    String? bio,
    String? avatarUrl,
    String? homeCity,
    UserStats? stats,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      handle: handle ?? this.handle,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      homeCity: homeCity ?? this.homeCity,
      stats: stats ?? this.stats,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'handle': handle,
      'bio': bio,
      'avatarUrl': avatarUrl,
      'homeCity': homeCity,
      'stats': stats.toMap(),
    };
  }

  factory AppUser.fromMap(String id, Map<String, dynamic> map) {
    return AppUser(
      id: id,
      email: map['email'] as String? ?? '',
      name: map['name'] as String? ?? 'Explorer',
      handle: map['handle'] as String? ?? '@explorer',
      bio: map['bio'] as String? ?? '',
      avatarUrl: map['avatarUrl'] as String? ?? '',
      homeCity: map['homeCity'] as String? ?? '',
      stats: UserStats.fromMap(map['stats'] as Map<String, dynamic>? ?? {}),
    );
  }
}

class UserStats {
  const UserStats({
    required this.followers,
    required this.trips,
    required this.bookings,
  });

  final int followers;
  final int trips;
  final int bookings;

  Map<String, dynamic> toMap() {
    return {
      'followers': followers,
      'trips': trips,
      'bookings': bookings,
    };
  }

  factory UserStats.fromMap(Map<String, dynamic> map) {
    return UserStats(
      followers: map['followers'] as int? ?? 0,
      trips: map['trips'] as int? ?? 0,
      bookings: map['bookings'] as int? ?? 0,
    );
  }
}

class CommunityPost {
  const CommunityPost({
    required this.id,
    required this.authorId,
    required this.author,
    required this.location,
    required this.caption,
    required this.imageUrl,
    required this.likes,
    required this.comments,
    required this.tags,
    required this.createdAt,
    this.isLiked = false,
    this.isSaved = false,
  });

  final String id;
  final String authorId;
  final String author;
  final String location;
  final String caption;
  final String imageUrl;
  final int likes;
  final int comments;
  final List<String> tags;
  final DateTime createdAt;
  final bool isLiked;
  final bool isSaved;

  CommunityPost copyWith({
    String? id,
    String? authorId,
    String? author,
    String? location,
    String? caption,
    String? imageUrl,
    int? likes,
    int? comments,
    List<String>? tags,
    DateTime? createdAt,
    bool? isLiked,
    bool? isSaved,
  }) {
    return CommunityPost(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      author: author ?? this.author,
      location: location ?? this.location,
      caption: caption ?? this.caption,
      imageUrl: imageUrl ?? this.imageUrl,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      isLiked: isLiked ?? this.isLiked,
      isSaved: isSaved ?? this.isSaved,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'authorId': authorId,
      'author': author,
      'location': location,
      'caption': caption,
      'imageUrl': imageUrl,
      'likes': likes,
      'comments': comments,
      'tags': tags,
      'createdAt': createdAt.toIso8601String(),
      'likedBy': <String>[],
      'savedBy': <String>[],
    };
  }

  factory CommunityPost.fromMap(
    String id,
    Map<String, dynamic> map, {
    String? currentUserId,
  }) {
    final likedBy = List<String>.from(map['likedBy'] as List? ?? const []);
    final savedBy = List<String>.from(map['savedBy'] as List? ?? const []);
    return CommunityPost(
      id: id,
      authorId: map['authorId'] as String? ?? '',
      author: map['author'] as String? ?? 'Traveler',
      location: map['location'] as String? ?? '',
      caption: map['caption'] as String? ?? '',
      imageUrl: map['imageUrl'] as String? ?? '',
      likes: map['likes'] as int? ?? likedBy.length,
      comments: map['comments'] as int? ?? 0,
      tags: List<String>.from(map['tags'] as List? ?? const []),
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      isLiked: currentUserId != null && likedBy.contains(currentUserId),
      isSaved: currentUserId != null && savedBy.contains(currentUserId),
    );
  }
}

class DestinationSpot {
  const DestinationSpot({
    required this.id,
    required this.name,
    required this.country,
    required this.description,
    required this.imageUrl,
    required this.bestTime,
    required this.communityCount,
  });

  final String id;
  final String name;
  final String country;
  final String description;
  final String imageUrl;
  final String bestTime;
  final int communityCount;
}

class HotelDeal {
  const HotelDeal({
    required this.id,
    required this.name,
    required this.city,
    required this.pricePerNight,
    required this.rating,
    required this.imageUrl,
    required this.features,
    this.isSaved = false,
  });

  final String id;
  final String name;
  final String city;
  final int pricePerNight;
  final double rating;
  final String imageUrl;
  final List<String> features;
  final bool isSaved;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'city': city,
      'pricePerNight': pricePerNight,
      'rating': rating,
      'imageUrl': imageUrl,
      'features': features,
    };
  }

  factory HotelDeal.fromMap(
    String id,
    Map<String, dynamic> map, {
    bool isSaved = false,
  }) {
    return HotelDeal(
      id: id,
      name: map['name'] as String? ?? '',
      city: map['city'] as String? ?? '',
      pricePerNight: map['pricePerNight'] as int? ?? 0,
      rating: (map['rating'] as num?)?.toDouble() ?? 0,
      imageUrl: map['imageUrl'] as String? ?? '',
      features: List<String>.from(map['features'] as List? ?? const []),
      isSaved: isSaved,
    );
  }
}

class TicketDeal {
  const TicketDeal({
    required this.id,
    required this.from,
    required this.to,
    required this.carrier,
    required this.departure,
    required this.duration,
    required this.price,
  });

  final String id;
  final String from;
  final String to;
  final String carrier;
  final DateTime departure;
  final String duration;
  final int price;

  Map<String, dynamic> toMap() {
    return {
      'from': from,
      'to': to,
      'carrier': carrier,
      'departure': departure.toIso8601String(),
      'duration': duration,
      'price': price,
    };
  }

  factory TicketDeal.fromMap(String id, Map<String, dynamic> map) {
    return TicketDeal(
      id: id,
      from: map['from'] as String? ?? '',
      to: map['to'] as String? ?? '',
      carrier: map['carrier'] as String? ?? '',
      departure: DateTime.tryParse(map['departure'] as String? ?? '') ??
          DateTime.now(),
      duration: map['duration'] as String? ?? '',
      price: map['price'] as int? ?? 0,
    );
  }
}

class BookingRecord {
  const BookingRecord({
    required this.id,
    required this.userId,
    required this.type,
    required this.itemId,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String type;
  final String itemId;
  final String title;
  final String subtitle;
  final int price;
  final String status;
  final DateTime createdAt;

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'type': type,
      'itemId': itemId,
      'title': title,
      'subtitle': subtitle,
      'price': price,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory BookingRecord.fromMap(String id, Map<String, dynamic> map) {
    return BookingRecord(
      id: id,
      userId: map['userId'] as String? ?? '',
      type: map['type'] as String? ?? '',
      itemId: map['itemId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      subtitle: map['subtitle'] as String? ?? '',
      price: map['price'] as int? ?? 0,
      status: map['status'] as String? ?? 'pending',
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
