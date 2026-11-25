import 'dart:typed_data';
import 'models.dart';

DateTime _t(dynamic v) => DateTime.parse(v as String).toLocal();

/// Social-network models: travelers, stories, chats, groups and trip plans.
/// In demo mode they are filled from the seeds below; with Supabase they map
/// to the tables in `supabase/social.sql`.

class Traveler {
  final String id, name, seed, handle, home, bio;
  final List<String> countries;
  final int followers, following, trips;
  final bool verified;
  final bool online;
  final String? nextTrip; // place id the traveler plans to visit
  final String? cover; // cover photo URL
  /// Distinct places this traveler has posted from, and the countries they are in (drives the level).
  final int placesVisited;
  final List<String> visitedCountries;
  const Traveler({
    this.cover,
    this.placesVisited = 0,
    this.visitedCountries = const [],
    required this.id,
    required this.name,
    required this.seed,
    required this.handle,
    required this.home,
    required this.bio,
    required this.countries,
    this.followers = 0,
    this.following = 0,
    this.trips = 0,
    this.verified = false,
    this.online = false,
    this.nextTrip,
  });

  String get first => name.split(' ').first;

  factory Traveler.fromRow(Map<String, dynamic> r) => Traveler(
        id: r['id'] as String,
        name: (r['name'] as String?)?.trim().isNotEmpty == true ? r['name'] as String : 'Traveler',
        seed: r['avatar_url'] as String? ?? '',
        handle: r['username'] as String? ?? (r['name'] as String? ?? 'traveler').toLowerCase().replaceAll(' ', '.'),
        home: r['home'] as String? ?? '',
        bio: r['bio'] as String? ?? '',
        countries: List<String>.from(r['countries'] as List? ?? const []),
        verified: r['verified'] as bool? ?? false,
        nextTrip: r['next_place_id'] as String?,
        cover: r['cover_url'] as String?,
        followers: (r['followers'] as num?)?.toInt() ?? 0,
        following: (r['following'] as num?)?.toInt() ?? 0,
        trips: (r['trips'] as num?)?.toInt() ?? 0,
        placesVisited: (r['places_visited'] as num?)?.toInt() ?? 0,
        visitedCountries: List<String>.from(r['visited_countries'] as List? ?? const []),
      );
}

class Story {
  final String id, travelerId, imageSeed, caption, time;
  final String? placeId;
  const Story(this.id, this.travelerId, this.imageSeed, this.caption, this.time, {this.placeId});

  factory Story.fromRow(Map<String, dynamic> r) =>
      Story(r['id'] as String, r['user_id'] as String, r['media_url'] as String, r['caption'] as String? ?? '', ago(_t(r['created_at'])),
          placeId: r['place_id'] as String?);
}

class Message {
  final String fromId, text, time;
  final String? imageSeed;
  final DateTime? at;
  /// Database id (live mode), used to delete the message.
  final String? id;
  /// Storage path of a photo in the private `chat-media` bucket (live mode).
  final String? media;
  /// The photo's bytes while it is still uploading, so it shows at once.
  final Uint8List? bytes;
  const Message(this.fromId, this.text, this.time, {this.imageSeed, this.at, this.id, this.media, this.bytes});
  bool get isPhoto => media != null || bytes != null || imageSeed != null;
}

class Conversation {
  final String id;
  final String title;
  final List<String> memberIds;
  final bool isGroup;
  final List<Message> messages;
  int unread;
  Conversation({
    required this.id,
    required this.title,
    required this.memberIds,
    required this.messages,
    this.isGroup = false,
    this.unread = 0,
  });
  Message? get last => messages.isEmpty ? null : messages.last;
}

class TravelGroup {
  final String id, name, coverSeed, about, category;
  final int members;
  final bool private;
  final List<String> rules;
  final List<Post> posts;

  factory TravelGroup.fromRow(Map<String, dynamic> r) => TravelGroup(
        id: r['id'] as String,
        name: r['name'] as String,
        coverSeed: r['cover_url'] as String? ?? 'group-${r['slug'] ?? r['name']}',
        about: r['about'] as String? ?? '',
        category: r['category'] as String? ?? 'Community',
        members: (r['member_count'] as num?)?.toInt() ?? 0,
        private: r['private'] as bool? ?? false,
        rules: List<String>.from(r['rules'] as List? ?? const []),
        posts: [],
      );
  const TravelGroup({
    required this.id,
    required this.name,
    required this.coverSeed,
    required this.about,
    required this.category,
    required this.members,
    this.private = false,
    this.rules = const [],
    this.posts = const [],
  });
}

class TripStop {
  String time, title, note, kind; // kind: flight | train | bus | boat | hotel | food | sight | trek
  String? id;
  TripStop(this.time, this.title, this.note, this.kind, {this.id});
}

class TripDay {
  final List<TripStop> stops;
  TripDay(this.stops);
}

class TripPlan {
  final String id;
  String title, placeId;
  DateTime start;
  final List<TripDay> days;
  final List<String> buddies; // traveler ids
  double budget;
  bool public;
  /// Other travelers going to the same place at the same time can see this traveler.
  bool discoverable;
  TripPlan({
    required this.id,
    required this.title,
    required this.placeId,
    required this.start,
    required this.days,
    this.buddies = const [],
    this.budget = 0,
    this.public = true,
    this.discoverable = true,
  });
  DateTime get end => start.add(Duration(days: days.isEmpty ? 0 : days.length - 1));
}

/// A traveler whose trip overlaps yours at the same place.
class SameTimeMatch {
  final String userId, name, home;
  final String? avatarUrl;
  final bool verified;
  final DateTime start, end;
  final int overlapDays;
  const SameTimeMatch({required this.userId, required this.name, required this.home, this.avatarUrl, this.verified = false, required this.start, required this.end, required this.overlapDays});
  factory SameTimeMatch.fromRow(Map<String, dynamic> r) => SameTimeMatch(
        userId: r['user_id'] as String,
        name: (r['name'] as String?)?.trim().isNotEmpty == true ? r['name'] as String : 'Traveler',
        home: r['home'] as String? ?? '',
        avatarUrl: r['avatar_url'] as String?,
        verified: r['verified'] as bool? ?? false,
        start: DateTime.parse(r['start_date'] as String),
        end: DateTime.parse(r['end_date'] as String),
        overlapDays: (r['overlap_days'] as num?)?.toInt() ?? 1,
      );
}

// ------------------------------------------------------------------ seeds

const meId = 'me';

/// Everyone the app knows about. Demo: the seeds below. Live: replaced by rows from `profiles`.
final List<Traveler> travelers = <Traveler>[
  Traveler(id: 'ayesha', name: 'Ayesha Rahman', seed: 'ayesha', handle: 'ayesha.travels', home: 'Dhaka, Bangladesh',
      bio: 'Hill tracts lover. Chasing clouds, tea gardens and slow trains.', countries: ['Bangladesh', 'Nepal', 'India', 'Bhutan', 'Thailand'],
      followers: 12400, following: 380, trips: 41, placesVisited: 123, verified: true, online: true, nextTrip: 'kaptai'),
  Traveler(id: 'meilin', name: 'Mei Lin', seed: 'meilin', handle: 'meilin.wanders', home: 'Osaka, Japan',
      bio: 'Filmmaker. 60-second city guides every Friday.', countries: ['Japan', 'Korea', 'Vietnam', 'Peru', 'Greece', 'Morocco'],
      followers: 58200, following: 210, trips: 77, placesVisited: 231, verified: true, online: true, nextTrip: 'santorini'),
  Traveler(id: 'carlos', name: 'Carlos Vega', seed: 'carlos', handle: 'carlos.trails', home: 'Lima, Peru',
      bio: 'Trekker and trail runner. Inca Trail x7.', countries: ['Peru', 'Chile', 'Bolivia', 'Nepal'],
      followers: 8100, following: 512, trips: 29, placesVisited: 87, online: false, nextTrip: 'sajek'),
  Traveler(id: 'tanvir', name: 'Tanvir Hasan', seed: 'tanvir', handle: 'tanvir.boats', home: 'Chattogram, Bangladesh',
      bio: 'Budget routes, real prices. Boat person.', countries: ['Bangladesh', 'India', 'Malaysia'],
      followers: 3900, following: 640, trips: 18, placesVisited: 54, online: true, nextTrip: 'coxs'),
  Traveler(id: 'nora', name: 'Nora Haddad', seed: 'nora', handle: 'nora.desert', home: 'Beirut, Lebanon',
      bio: 'Deserts, souks and long dinners. Solo female travel tips.', countries: ['Morocco', 'Jordan', 'Egypt', 'Turkey', 'Greece'],
      followers: 21000, following: 300, trips: 52, placesVisited: 156, verified: true, online: false, nextTrip: 'raja-ampat'),
  Traveler(id: 'sam', name: 'Sam Okafor', seed: 'sam', handle: 'sam.dives', home: 'Lagos, Nigeria',
      bio: 'Divemaster. Ocean first, everything else second.', countries: ['Indonesia', 'Philippines', 'Egypt', 'Maldives'],
      followers: 14800, following: 190, trips: 35, placesVisited: 105, online: true, nextTrip: 'raja-ampat'),
  Traveler(id: 'eleni', name: 'Eleni Katsaros', seed: 'eleni', handle: 'eleni.islands', home: 'Athens, Greece',
      bio: 'Local historian. Quiet beaches over crowded viewpoints.', countries: ['Greece', 'Italy', 'Cyprus'],
      followers: 6400, following: 420, trips: 23, placesVisited: 69, online: false, nextTrip: 'kyoto'),
  Traveler(id: 'arjun', name: 'Arjun Mehta', seed: 'arjun', handle: 'arjun.on.road', home: 'Mumbai, India',
      bio: 'Motorbike tours across the Himalaya.', countries: ['India', 'Nepal', 'Bhutan'],
      followers: 2300, following: 280, trips: 14, placesVisited: 42, online: true, nextTrip: 'sajek'),
  Traveler(id: 'lena', name: 'Lena Fischer', seed: 'lena', handle: 'lena.backpacks', home: 'Berlin, Germany',
      bio: 'Backpacking 30 countries on a budget. Hostels and night buses.', countries: ['Germany', 'Thailand', 'Vietnam', 'Peru', 'Morocco', 'Nepal'],
      followers: 9100, following: 760, trips: 33, placesVisited: 99, online: false, nextTrip: 'machu-picchu'),
  Traveler(id: 'hana', name: 'Hana Sato', seed: 'hana', handle: 'hana.eats', home: 'Kyoto, Japan',
      bio: 'Street food maps for every city I visit.', countries: ['Japan', 'Taiwan', 'Thailand', 'Bangladesh'],
      followers: 17300, following: 350, trips: 40, placesVisited: 120, online: true, nextTrip: 'coxs'),
];

const _unknown = Traveler(id: '', name: 'Traveler', seed: '', handle: 'traveler', home: '', bio: '', countries: []);

Traveler travelerById(String id) =>
    travelers.firstWhere((t) => t.id == id || t.seed == id, orElse: () => travelers.isEmpty ? _unknown : _unknown);

/// The author of a post as a [Traveler] (by user id when live, by name in demo).
Traveler? travelerForPost(Post p) {
  for (final t in travelers) {
    if ((p.userId != null && t.id == p.userId) || t.name == p.userName) return t;
  }
  return null;
}

Traveler? travelerByName(String name) {
  for (final t in travelers) {
    if (t.name == name) return t;
  }
  return null;
}

const seedStories = <Story>[
  Story('s1', 'ayesha', 'sajek-morning', 'Sunrise from Konglak hill', '1h', placeId: 'sajek'),
  Story('s2', 'meilin', 'kyoto-lantern', 'Lantern alley at night', '3h', placeId: 'kyoto'),
  Story('s3', 'sam', 'reef-manta', 'Manta cleaning station!', '4h', placeId: 'raja-ampat'),
  Story('s4', 'tanvir', 'kaptai-ghat', 'Boat fare today: 1,800 BDT for 6', '6h', placeId: 'kaptai'),
  Story('s5', 'nora', 'sahara-camp', 'Desert camp dinner', '9h', placeId: 'sahara'),
  Story('s6', 'hana', 'street-food', 'Best fuchka in Dhaka?', '12h'),
  Story('s7', 'lena', 'night-bus', 'Night bus #47', '20h'),
];

List<Conversation> seedConversations() => [
      Conversation(id: 'c1', title: 'Ayesha Rahman', memberIds: ['ayesha'], unread: 2, messages: [
        const Message('ayesha', 'Hey! Saw you saved Kaptai Lake 😊', '10:02 AM'),
        const Message(meId, 'Yes, planning for December. Any tips?', '10:05 AM'),
        const Message('ayesha', 'Go on a weekday and book the boat at Reserve Bazar ghat. Much cheaper.', '10:07 AM'),
        const Message('ayesha', 'I can share my itinerary if you want', '10:08 AM'),
      ]),
      Conversation(id: 'c2', title: 'Sajek Squad · Dec', memberIds: ['carlos', 'arjun', 'tanvir'], isGroup: true, unread: 5, messages: [
        const Message('arjun', 'Jeep from Khagrachari is confirmed for 6 people', '9:12 AM'),
        const Message('carlos', 'Perfect. I land in Dhaka on the 14th', '9:20 AM'),
        const Message('tanvir', 'I will book Megh Machang cottages tonight', '9:41 AM'),
      ]),
      Conversation(id: 'c3', title: 'Mei Lin', memberIds: ['meilin'], messages: [
        const Message(meId, 'Your Kyoto reel was amazing!', 'Yesterday'),
        const Message('meilin', 'Thank you! Shot it all on a phone 📱', 'Yesterday'),
      ]),
      Conversation(id: 'c4', title: 'Sam Okafor', memberIds: ['sam'], messages: [
        const Message('sam', 'Still looking for a dive buddy in Raja Ampat in Feb?', 'Mon'),
      ]),
      Conversation(id: 'c5', title: 'Nora Haddad', memberIds: ['nora'], messages: [
        const Message(meId, 'Which camp did you stay in at Merzouga?', 'Sun'),
        const Message('nora', 'Desert Luxury Camp. Ask for Youssef, he is the best guide.', 'Sun'),
      ]),
    ];

List<TravelGroup> seedGroups() => [
      TravelGroup(
        id: 'g-bd', name: 'Travelers of Bangladesh', coverSeed: 'bd-green-hills', category: 'Country',
        about: 'Routes, prices and safety updates from every corner of Bangladesh. Hill tracts, haor, beaches and the Sundarbans.',
        members: 184200, rules: ['Share real prices and dates', 'No hotel advertising', 'Be kind to locals and to each other'],
        posts: [
          Post(id: 'gp1', userName: 'Tanvir Hasan', userSeed: 'tanvir', imageSeed: 'tanguar-haor', time: '3h', placeId: 'kaptai',
              caption: 'Tanguar Haor houseboats are back in season. Paid 3,500 BDT per person for 2 days, all meals included.', likes: 832),
          Post(id: 'gp2', userName: 'Ayesha Rahman', userSeed: 'ayesha', imageSeed: 'sajek-road', time: '1d', placeId: 'sajek',
              caption: 'Road to Sajek is open again. Army escort leaves Baghaihat at 10:30 am and 3 pm.', likes: 1204),
        ],
      ),
      TravelGroup(
        id: 'g-solo', name: 'Solo Female Travelers', coverSeed: 'solo-traveler', category: 'Community',
        about: 'A safe space for women who travel alone. Ask anything, share stays and meet travel buddies.',
        members: 96300, private: true, rules: ['Women only', 'No sharing screenshots outside the group'],
        posts: [
          Post(id: 'gp3', userName: 'Nora Haddad', userSeed: 'nora', imageSeed: 'marrakech-riad', time: '5h', placeId: 'sahara',
              caption: 'Riad recommendations in Marrakech that felt safe and friendly? Here are my top 3.', likes: 412),
        ],
      ),
      TravelGroup(
        id: 'g-budget', name: 'Backpackers on a Budget', coverSeed: 'backpack-hostel', category: 'Budget',
        about: 'Under \$30 a day? Hostels, night buses, free walking tours and cheap eats worldwide.',
        members: 251000, rules: ['Include prices', 'No referral links'],
        posts: [
          Post(id: 'gp4', userName: 'Lena Fischer', userSeed: 'lena', imageSeed: 'night-market', time: '2h',
              caption: 'Spent \$18 a day in northern Vietnam for two weeks. Full breakdown in the comments.', likes: 2103),
        ],
      ),
      TravelGroup(
        id: 'g-dive', name: 'Scuba & Snorkel Spots', coverSeed: 'coral-reef', category: 'Activity',
        about: 'Dive sites, liveaboards, conditions and buddy finder for divers and snorkelers.',
        members: 42800, rules: ['Respect marine life', 'Tag the dive site'],
        posts: [
          Post(id: 'gp5', userName: 'Sam Okafor', userSeed: 'sam', imageSeed: 'raja-ampat-reef', time: '8h', placeId: 'raja-ampat',
              caption: 'Visibility at Cape Kri today was 25 m. Strong current after 2 pm.', likes: 655),
        ],
      ),
      TravelGroup(
        id: 'g-hike', name: 'Himalaya Trekkers', coverSeed: 'himalaya-trek', category: 'Activity',
        about: 'Permits, porters, teahouses and altitude advice for treks in Nepal, India and Bhutan.',
        members: 77500, rules: ['No unlicensed guide ads', 'Share altitude safety info'],
        posts: [
          Post(id: 'gp6', userName: 'Arjun Mehta', userSeed: 'arjun', imageSeed: 'annapurna', time: '1d',
              caption: 'Annapurna Circuit permits now cost 3,000 NPR. Thorong La was clear this morning.', likes: 980),
        ],
      ),
      TravelGroup(
        id: 'g-food', name: 'Street Food Explorers', coverSeed: 'street-food', category: 'Food',
        about: 'Where locals actually eat. Maps, prices and hygiene tips from street food lovers.',
        members: 133900, posts: [],
      ),
    ];

List<TripPlan> seedTrips() {
  final now = DateTime.now();
  return [
    TripPlan(
      id: 't1', title: 'Kaptai & Sajek hills', placeId: 'kaptai', start: DateTime(now.year, now.month, now.day).add(const Duration(days: 12)),
      buddies: ['ayesha', 'tanvir'], budget: 220,
      days: [
        TripDay([
          TripStop('7:00 AM', 'Bus Dhaka to Chattogram', 'Green Line, seat 4A. Breakfast on board.', 'bus'),
          TripStop('2:00 PM', 'Check in at Rangamati', 'Hotel Sufia, lake view room', 'hotel'),
          TripStop('5:00 PM', 'Sunset at Hanging Bridge', 'Walk from the hotel, 15 min', 'sight'),
        ]),
        TripDay([
          TripStop('8:00 AM', 'Boat tour of Kaptai Lake', 'Reserve Bazar ghat, shared boat with Tanvir', 'boat'),
          TripStop('1:00 PM', 'Lunch at Peda Ting Ting', 'Try bamboo chicken', 'food'),
          TripStop('4:00 PM', 'Shuvolong waterfall', 'Bring sandals', 'sight'),
        ]),
        TripDay([
          TripStop('6:30 AM', 'Jeep to Sajek Valley', 'Army escort from Baghaihat at 10:30', 'jeep'),
          TripStop('3:00 PM', 'Megh Machang cottage', 'Booked by Ayesha', 'hotel'),
        ]),
        TripDay([
          TripStop('5:30 AM', 'Konglak hill sunrise', 'Above the clouds!', 'trek'),
          TripStop('11:00 AM', 'Return to Dhaka', 'Shanti Paribahan night coach', 'bus'),
        ]),
      ],
    ),
    TripPlan(
      id: 't2', title: 'Raja Ampat dive week', placeId: 'raja-ampat', start: DateTime(now.year, now.month, now.day).add(const Duration(days: 74)),
      buddies: ['sam'], budget: 1400, public: false,
      days: [
        TripDay([TripStop('9:00 AM', 'Fly Jakarta to Sorong', 'Garuda GA 682', 'flight'), TripStop('3:00 PM', 'Ferry to Waisai', 'Bahari Express', 'boat')]),
        TripDay([TripStop('8:00 AM', 'Dive: Cape Kri', 'Two tanks with Sam', 'boat')]),
        TripDay([TripStop('7:00 AM', 'Piaynemo viewpoint', '320 steps, go early', 'trek')]),
      ],
    ),
  ];
}
