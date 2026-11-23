class RouteStep {
  final String mode; // flight | train | bus | boat | jeep | trek | info
  final String title, detail, duration, cost;
  final String? action; // flight | train | bus -> opens ticket search
  const RouteStep({
    required this.mode,
    required this.title,
    required this.detail,
    this.duration = '',
    this.cost = '',
    this.action,
  });
}

class Place {
  final String id, name, location, country, category, hub;
  final String about, season, lastMode, lastDetail, lastDuration;
  final double rating, price;
  final int reviews;
  final List<String> facilities;
  final String? address, hours, mapsUrl, imageUrl, videoUrl, continent, wikiTitle;
  final double? lat, lng;
  final int? budgetLow, budgetHigh, popularity;

  /// Typical daily spend in USD for a mid-range traveler (0 when unknown).
  int get dailyBudget => budgetLow ?? (price > 0 ? price.round() : 0);

  /// Photo to show: the real image when the backend has one, else the place id (demo).
  String get photo => imageUrl ?? id;

  const Place({
    required this.id,
    required this.name,
    required this.location,
    required this.country,
    required this.category,
    required this.hub,
    required this.rating,
    required this.reviews,
    required this.price,
    required this.about,
    required this.season,
    required this.lastMode,
    required this.lastDetail,
    required this.lastDuration,
    required this.facilities,
    this.address,
    this.hours,
    this.mapsUrl,
    this.imageUrl,
    this.lat,
    this.lng,
    this.videoUrl,
    this.continent,
    this.wikiTitle,
    this.budgetLow,
    this.budgetHigh,
    this.popularity,
  });

  factory Place.fromRow(Map<String, dynamic> r) => Place(
        id: r['id'] as String,
        name: r['name'] as String,
        location: r['location'] as String,
        country: r['country'] as String,
        category: r['category'] as String,
        hub: r['hub'] as String,
        rating: (r['rating'] as num).toDouble(),
        reviews: (r['reviews'] as num).toInt(),
        price: (r['price'] as num).toDouble(),
        about: r['about'] as String? ?? '',
        season: r['season'] as String? ?? '',
        lastMode: r['last_mode'] as String? ?? 'car',
        lastDetail: r['last_detail'] as String? ?? '',
        lastDuration: r['last_duration'] as String? ?? '',
        facilities: List<String>.from(r['facilities'] as List? ?? const []),
        address: r['address'] as String?,
        hours: r['hours'] as String?,
        mapsUrl: r['maps_url'] as String?,
        imageUrl: r['image_url'] as String?,
        lat: (r['lat'] as num?)?.toDouble(),
        lng: (r['lng'] as num?)?.toDouble(),
        videoUrl: r['video_url'] as String?,
        continent: r['continent'] as String?,
        wikiTitle: r['wiki_title'] as String?,
        budgetLow: (r['budget_low'] as num?)?.toInt(),
        budgetHigh: (r['budget_high'] as num?)?.toInt(),
        popularity: (r['popularity'] as num?)?.toInt(),
      );

  /// "How to go there" guide, built from the place's nearest travel hub.
  List<RouteStep> get routes => [
        RouteStep(
          mode: 'flight',
          title: 'Fly into $hub',
          detail:
              'Daily direct and connecting flights serve $hub. Booking 3 to 6 weeks ahead usually gets the best fares.',
          duration: '1 to 14 h',
          cost: 'est. ${money0(price * 1.2)}',
          action: 'flight',
        ),
        RouteStep(
          mode: 'bus',
          title: 'Overland from $hub',
          detail:
              'Comfortable coaches and trains connect $hub with the region. Choose an early departure to arrive in daylight.',
          duration: '3 to 9 h',
          cost: 'est. ${money0(price * 0.25)}',
          action: 'bus',
        ),
        RouteStep(
          mode: lastMode,
          title: 'The last stretch',
          detail: lastDetail,
          duration: lastDuration,
          cost: 'pay locally',
        ),
        RouteStep(
          mode: 'info',
          title: 'Before you go',
          detail:
              'Best time to visit: $season. Carry a printed copy of your booking and some local cash.',
        ),
      ];
}

String money0(num v) => '\$${v.round()}';

class Review {
  final String name, text, when;
  final double rating;
  const Review(this.name, this.rating, this.text, this.when);
}

class Comment {
  final String user, text;
  const Comment(this.user, this.text);
}

class Post {
  final String id, userName, userSeed, imageSeed, time;
  String caption;
  final String? placeId, videoTitle, userId, groupId;
  final bool isVideo;
  int likes;
  int commentCount;
  int shareCount;
  bool edited;
  final List<Comment> comments;

  /// The post this one re-shares, if any.
  final Post? shared;

  /// A place the author typed in (not in the catalog), e.g. "Bichanakandi, Bangladesh".
  final String? locationLabel;

  Post({
    required this.id,
    required this.userName,
    required this.userSeed,
    required this.caption,
    required this.imageSeed,
    required this.time,
    this.placeId,
    this.videoTitle,
    this.userId,
    this.groupId,
    this.isVideo = false,
    this.likes = 0,
    int? commentCount,
    List<Comment>? comments,
    this.shareCount = 0,
    this.edited = false,
    this.shared,
    this.locationLabel,
  })  : comments = comments ?? [],
        commentCount = commentCount ?? (comments?.length ?? 0);

  /// [imageSeed] holds the media URL for real posts (AppImage detects http links).
  factory Post.fromRow(Map<String, dynamic> r) {
    final caption = r['caption'] as String;
    final isVideo = r['is_video'] as bool? ?? false;
    return Post(
      id: r['id'] as String,
      userId: r['user_id'] as String?,
      groupId: r['group_id'] as String?,
      userName: r['author_name'] as String? ?? 'Traveler',
      userSeed: r['author_avatar'] as String? ?? '',
      caption: caption,
      imageSeed: r['media_url'] as String? ?? '',
      placeId: r['place_id'] as String?,
      isVideo: isVideo,
      videoTitle: isVideo ? caption.split('.').first : null,
      likes: (r['like_count'] as num?)?.toInt() ?? 0,
      commentCount: (r['comment_count'] as num?)?.toInt() ?? 0,
      shareCount: (r['share_count'] as num?)?.toInt() ?? 0,
      edited: r['edited_at'] != null,
      locationLabel: r['location_name'] == null ? null : '${r['location_name']}, ${r['location_country'] ?? ''}',
      time: ago(DateTime.parse(r['created_at'] as String).toLocal()),
      shared: r['shared_post_id'] == null || r['shared_caption'] == null
          ? null
          : Post(
              id: r['shared_post_id'] as String,
              userId: r['shared_user_id'] as String?,
              userName: r['shared_author'] as String? ?? 'Traveler',
              userSeed: r['shared_author_avatar'] as String? ?? '',
              caption: r['shared_caption'] as String,
              imageSeed: r['shared_media'] as String? ?? '',
              isVideo: r['shared_is_video'] as bool? ?? false,
              time: '',
            ),
    );
  }
}

class Booking {
  final String id, title, location, type, seed, ref;
  final double amount;
  final DateTime start, end;
  String status; // Upcoming | Completed | Cancelled

  Booking({
    required this.id,
    required this.title,
    required this.location,
    required this.type,
    required this.seed,
    required this.ref,
    required this.amount,
    required this.start,
    required this.end,
    this.status = 'Upcoming',
  });

  factory Booking.fromRow(Map<String, dynamic> r) => Booking(
        id: r['id'] as String,
        title: r['title'] as String,
        location: r['location'] as String? ?? '',
        type: r['type'] as String,
        seed: r['seed'] as String? ?? '',
        ref: r['ref'] as String,
        amount: (r['amount'] as num).toDouble(),
        start: DateTime.parse(r['start_date'] as String),
        end: DateTime.parse(r['end_date'] as String),
        status: r['status'] as String? ?? 'Upcoming',
      );
}

class AppNotification {
  final String id, title, body, kind, time, day;
  final String? actorId, actorName, actorAvatar, targetType, targetId;
  bool read;
  AppNotification({
    this.actorId,
    this.actorName,
    this.actorAvatar,
    this.targetType,
    this.targetId,
    required this.id,
    required this.title,
    required this.body,
    required this.kind,
    required this.time,
    required this.day,
    this.read = false,
  });

  factory AppNotification.fromRow(Map<String, dynamic> r) {
    final t = DateTime.parse(r['created_at'] as String).toLocal();
    return AppNotification(
      id: r['id'] as String,
      kind: r['kind'] as String? ?? 'app',
      title: r['title'] as String,
      body: r['body'] as String? ?? '',
      time: clock(t),
      day: dayLabel(t),
      read: r['read'] as bool? ?? false,
      actorId: r['actor_id'] as String?,
      actorName: (r['actor'] as Map?)?['name'] as String?,
      actorAvatar: (r['actor'] as Map?)?['avatar_url'] as String?,
      targetType: r['target_type'] as String?,
      targetId: r['target_id'] as String?,
    );
  }
}

class TransportOffer {
  final String type, operator, from, to, depart, arrive, duration, extra;
  final double price;
  const TransportOffer({
    required this.type,
    required this.operator,
    required this.from,
    required this.to,
    required this.depart,
    required this.arrive,
    required this.duration,
    required this.extra,
    required this.price,
  });
}

class Guide {
  final String id, name, base, bio, seed;
  final double rating, pricePerDay;
  final int years;
  final List<String> languages;
  const Guide({
    required this.id,
    required this.name,
    required this.base,
    required this.bio,
    required this.seed,
    required this.rating,
    required this.pricePerDay,
    required this.years,
    required this.languages,
  });

  factory Guide.fromRow(Map<String, dynamic> r) => Guide(
        id: r['id'] as String,
        name: r['name'] as String,
        base: r['base'] as String,
        bio: r['bio'] as String? ?? '',
        seed: (r['name'] as String).split(' ').first.toLowerCase(),
        rating: (r['rating'] as num).toDouble(),
        pricePerDay: (r['price_per_day'] as num).toDouble(),
        years: (r['years'] as num).toInt(),
        languages: List<String>.from(r['languages'] as List? ?? const []),
      );
}

class EventItem {
  final String title, placeId;
  const EventItem(this.title, this.placeId);
}

/// What the user is about to book (hotel/tour, ticket or guide).
class BookingDraft {
  final String title, location, type, seed;
  final double unitPrice;
  const BookingDraft({
    required this.title,
    required this.location,
    required this.type,
    required this.seed,
    required this.unitPrice,
  });
}

class BookingOption {
  final String name;
  final List<String> details;
  final double price;
  const BookingOption(this.name, this.details, this.price);
}


// ---------- small formatting helpers ----------
String ago(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  return '${diff.inDays}d';
}

String clock(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m ${t.hour >= 12 ? 'PM' : 'AM'}';
}

String dayLabel(DateTime t) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(t.year, t.month, t.day);
  final diff = today.difference(day).inDays;
  if (diff <= 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${t.day} ${m[t.month - 1]} ${t.year}';
}

/// A real-world travel meetup that travelers can join.
class Meetup {
  final String id, hostId, hostName, hostAvatar, title, about, location;
  final String? placeId, coverUrl;
  final DateTime startsAt;
  final int? capacity;
  int going, interested;

  Meetup({
    required this.id,
    required this.hostId,
    required this.hostName,
    required this.hostAvatar,
    required this.title,
    required this.about,
    required this.location,
    required this.startsAt,
    this.placeId,
    this.coverUrl,
    this.capacity,
    this.going = 0,
    this.interested = 0,
  });

  factory Meetup.fromRow(Map<String, dynamic> r) => Meetup(
        id: r['id'] as String,
        hostId: r['host_id'] as String,
        hostName: r['host_name'] as String? ?? 'Traveler',
        hostAvatar: r['host_avatar'] as String? ?? '',
        title: r['title'] as String,
        about: r['about'] as String? ?? '',
        location: r['location'] as String? ?? '',
        placeId: r['place_id'] as String?,
        coverUrl: r['cover_url'] as String?,
        startsAt: DateTime.parse(r['starts_at'] as String).toLocal(),
        capacity: (r['capacity'] as num?)?.toInt(),
        going: (r['going_count'] as num?)?.toInt() ?? 0,
        interested: (r['interested_count'] as num?)?.toInt() ?? 0,
      );

  bool get isPast => startsAt.isBefore(DateTime.now());
  bool get isFull => capacity != null && going >= capacity!;
}
