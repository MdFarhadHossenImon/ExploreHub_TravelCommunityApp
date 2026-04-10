class AppUser {
  const AppUser({
    required this.name,
    required this.handle,
    required this.bio,
    required this.avatarUrl,
    required this.homeCity,
    required this.stats,
  });

  final String name;
  final String handle;
  final String bio;
  final String avatarUrl;
  final String homeCity;
  final UserStats stats;
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
}

class CommunityPost {
  const CommunityPost({
    required this.author,
    required this.location,
    required this.caption,
    required this.imageUrl,
    required this.likes,
    required this.comments,
    required this.tags,
  });

  final String author;
  final String location;
  final String caption;
  final String imageUrl;
  final int likes;
  final int comments;
  final List<String> tags;
}

class DestinationSpot {
  const DestinationSpot({
    required this.name,
    required this.country,
    required this.description,
    required this.imageUrl,
    required this.bestTime,
    required this.communityCount,
  });

  final String name;
  final String country;
  final String description;
  final String imageUrl;
  final String bestTime;
  final int communityCount;
}

class HotelDeal {
  const HotelDeal({
    required this.name,
    required this.city,
    required this.pricePerNight,
    required this.rating,
    required this.imageUrl,
    required this.features,
  });

  final String name;
  final String city;
  final int pricePerNight;
  final double rating;
  final String imageUrl;
  final List<String> features;
}

class TicketDeal {
  const TicketDeal({
    required this.from,
    required this.to,
    required this.carrier,
    required this.departure,
    required this.duration,
    required this.price,
  });

  final String from;
  final String to;
  final String carrier;
  final DateTime departure;
  final String duration;
  final int price;
}
