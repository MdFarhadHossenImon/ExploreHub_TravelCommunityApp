import 'models.dart';

const categories = ['Heritage', 'Nature', 'Mountains', 'Beach', 'Lakes', 'City', 'Camp'];

const cities = [
  'Dhaka', 'Chattogram', "Cox's Bazar", 'Sylhet', 'Kathmandu', 'Jakarta',
  'Athens', 'Osaka', 'Lima', 'Marrakech', 'Bangkok', 'Dubai',
];

final List<Place> places = <Place>[
  Place(
    id: 'raja-ampat', name: 'Raja Ampat Islands', lat: -0.23, lng: 130.52, location: 'West Papua',
    country: 'Indonesia', category: 'Beach', hub: 'Jakarta', rating: 4.9,
    reviews: 150, price: 85,
    about:
        'A remote archipelago of more than 1,500 jungle-covered islands with the richest coral reefs on Earth. Snorkel with manta rays by day and sleep in stilted homestays by night.',
    season: 'October to April', lastMode: 'boat',
    lastDetail:
        'Fly Jakarta to Sorong, then take the public ferry or a speedboat transfer to Waisai. Homestays arrange pickups.',
    lastDuration: '2 to 3 h',
    facilities: ['Boat transfer', 'Snorkel gear', 'Homestay', 'Breakfast'],
  ),
  Place(
    id: 'kaptai', name: 'Kaptai Lake', lat: 22.5, lng: 92.21, location: 'Rangamati',
    country: 'Bangladesh', category: 'Lakes', hub: 'Chattogram', rating: 4.8,
    reviews: 320, price: 50,
    about:
        "Bangladesh's largest man-made lake, ringed by green hills and tribal villages. Take a boat to the Hanging Bridge and watch the sun set over still water.",
    season: 'November to March', lastMode: 'boat',
    lastDetail:
        'Take a bus from Chattogram to Rangamati town, then hire a motor boat from the main ghat.',
    lastDuration: '3 h',
    facilities: ['Boat ride', 'Local guide', 'Lunch', 'Life jackets'],
  ),
  Place(
    id: 'coxs', name: "Cox's Bazar", location: 'Chattogram Division',
    country: 'Bangladesh', category: 'Beach', hub: "Cox's Bazar", rating: 4.6,
    reviews: 910, price: 45,
    about:
        'The world\'s longest natural sea beach at 120 km. Walk the shoreline at sunrise, eat fresh seafood and visit Himchari waterfalls nearby.',
    season: 'November to February', lastMode: 'jeep',
    lastDetail:
        'The airport and bus terminal are in town. Auto-rickshaws and Chander Gari jeeps reach Laboni Beach in minutes.',
    lastDuration: '20 min',
    facilities: ['Beach access', 'Hotel', 'Seafood', 'Parasailing'],
  ),
  Place(
    id: 'sajek', name: 'Sajek Valley', lat: 23.38, lng: 92.29, location: 'Rangamati Hill District',
    country: 'Bangladesh', category: 'Mountains', hub: 'Chattogram', rating: 4.7,
    reviews: 540, price: 60,
    about:
        'The "Queen of Hills", where clouds drift below your cottage. Famous for its sea of clouds at dawn and the colorful Lushai and Pangkhua communities.',
    season: 'June to October', lastMode: 'jeep',
    lastDetail:
        'Take a bus to Khagrachari, then a shared Chander Gari jeep up the hill road. Escort rules apply, so travel in daylight.',
    lastDuration: '3 to 4 h',
    facilities: ['Cottage', 'Jeep transfer', 'Campfire', 'Local meals'],
  ),
  Place(
    id: 'kanchenjunga', name: 'Kanchenjunga Base Camp', lat: 27.7, lng: 88.15, location: 'Taplejung',
    country: 'Nepal', category: 'Mountains', hub: 'Kathmandu', rating: 4.9,
    reviews: 88, price: 320,
    about:
        'A 20-day trek to the foot of the world\'s third highest peak, through rhododendron forests and Sherpa villages. Quiet trails and enormous views.',
    season: 'March to May, October to November', lastMode: 'trek',
    lastDetail:
        'Fly Kathmandu to Bhadrapur, drive to Taplejung, then trek in with a licensed guide. Permits are mandatory and arranged by your operator.',
    lastDuration: '10 days',
    facilities: ['Permits', 'Licensed guide', 'Porter', 'Tea houses'],
  ),
  Place(
    id: 'santorini', name: 'Santorini', lat: 36.39, lng: 25.46, location: 'Cyclades',
    country: 'Greece', category: 'City', hub: 'Athens', rating: 4.8,
    reviews: 2100, price: 140,
    about:
        'White-washed villages on a volcanic caldera. Walk from Fira to Oia, taste Assyrtiko wine and watch the famous sunset from the castle ruins.',
    season: 'May to October', lastMode: 'boat',
    lastDetail:
        'Take a 35-minute flight from Athens, or the high-speed ferry from Piraeus (about 5 hours).',
    lastDuration: '35 min to 5 h',
    facilities: ['Caldera view', 'Breakfast', 'Airport pickup', 'Wine tour'],
  ),
  Place(
    id: 'kyoto', name: 'Kyoto', lat: 35.01, lng: 135.77, location: 'Kansai Region',
    country: 'Japan', category: 'City', hub: 'Osaka', rating: 4.9,
    reviews: 3400, price: 110,
    about:
        'Japan\'s old capital, with over 1,600 temples. Visit Fushimi Inari at dawn, stay in a ryokan and wander the lantern-lit streets of Gion.',
    season: 'March to April, November', lastMode: 'train',
    lastDetail:
        'From Kansai Airport take the Haruka Express straight to Kyoto Station. A Japan Rail pass covers most of the route.',
    lastDuration: '75 min',
    facilities: ['Ryokan stay', 'Rail pass help', 'Tea ceremony', 'Breakfast'],
  ),
  Place(
    id: 'machu-picchu', name: 'Machu Picchu', lat: -13.16, lng: -72.55, location: 'Cusco Region',
    country: 'Peru', category: 'Camp', hub: 'Lima', rating: 4.9,
    reviews: 5200, price: 180,
    about:
        'The Inca citadel above the Urubamba valley. Hike the Inca Trail over four days or take the train to Aguas Calientes and climb at sunrise.',
    season: 'May to September', lastMode: 'trek',
    lastDetail:
        'Fly Lima to Cusco, take the Vistadome train to Aguas Calientes, then the bus or a 90-minute climb to the gate. Tickets sell out months ahead.',
    lastDuration: '6 to 8 h',
    facilities: ['Entry ticket', 'Train', 'Guide', 'Camping gear'],
  ),
  Place(
    id: 'sahara', name: 'Merzouga Desert Camp', lat: 31.1, lng: -4.01, location: 'Erg Chebbi',
    country: 'Morocco', category: 'Camp', hub: 'Marrakech', rating: 4.7,
    reviews: 640, price: 95,
    about:
        'Sleep in a Berber tent among 150 m dunes. Ride camels at sunset, share tagine by the fire and count the stars.',
    season: 'October to April', lastMode: 'jeep',
    lastDetail:
        'A 4x4 desert transfer from Marrakech via the Atlas Mountains takes two days with an overnight stop in Ouarzazate.',
    lastDuration: '9 h',
    facilities: ['Camel ride', 'Dinner', 'Tent', '4x4 transfer'],
  ),
];

Place placeById(String id) => places.firstWhere((p) => p.id == id, orElse: () => places.first);

const events = <EventItem>[
  EventItem('Sajek Valley Special Tour', 'sajek'),
  EventItem('Kaptai Lake Sunset Cruise', 'kaptai'),
  EventItem('Santorini Wine Weekend', 'santorini'),
  EventItem('Kyoto Autumn Leaves', 'kyoto'),
];

const reviewsSeed = <Review>[
  Review('Ayesha R.', 5, 'Exactly like the photos. The guide was kind and knew every shortcut.', '2 weeks ago'),
  Review('Marco D.', 4.5, 'Beautiful place. Go early to beat the crowds, and bring cash.', '1 month ago'),
  Review('Nora H.', 4, 'Transport took longer than planned, but the views were worth every hour.', '3 months ago'),
];

final List<Guide> guides = <Guide>[
  Guide(id: 'g1', name: 'Rahim Uddin', base: 'Bangladesh', rating: 4.9, pricePerDay: 35, years: 8,
      languages: ['Bangla', 'English'], seed: 'rahim', verified: true,
      bio: 'Hill-tracts specialist. Knows every boat route on Kaptai Lake and the safest jeep drivers to Sajek.'),
  Guide(id: 'g2', name: 'Pema Sherpa', base: 'Nepal', rating: 5.0, pricePerDay: 60, years: 14,
      languages: ['Nepali', 'English', 'Hindi'], seed: 'pema',
      bio: 'Licensed trekking guide. Eleven Kanchenjunga expeditions, wilderness first-aid certified.'),
  Guide(id: 'g3', name: 'Yuki Tanaka', base: 'Japan', rating: 4.8, pricePerDay: 90, years: 6,
      languages: ['Japanese', 'English'], seed: 'yuki',
      bio: 'Kyoto native. Temple etiquette, hidden tea houses and seasonal photo spots.'),
  Guide(id: 'g4', name: 'Andi Pratama', base: 'Indonesia', rating: 4.8, pricePerDay: 45, years: 9,
      languages: ['Indonesian', 'English'], seed: 'andi',
      bio: 'Divemaster and boat captain based in Waisai. Plans island-hopping around the weather.'),
  Guide(id: 'g5', name: 'Lucia Quispe', base: 'Peru', rating: 4.9, pricePerDay: 70, years: 11,
      languages: ['Spanish', 'Quechua', 'English'], seed: 'lucia',
      bio: 'Archaeology graduate who leads Inca Trail groups and explains the stories behind the stones.'),
  Guide(id: 'g6', name: 'Youssef Benali', base: 'Morocco', rating: 4.7, pricePerDay: 50, years: 7,
      languages: ['Arabic', 'French', 'English'], seed: 'youssef',
      bio: 'Berber guide from Merzouga. Camel treks, dune sunrise and family-run camps.'),
  Guide(id: 'g7', name: 'Eleni Katsaros', base: 'Greece', rating: 4.8, pricePerDay: 65, years: 5,
      languages: ['Greek', 'English'], seed: 'eleni',
      bio: 'Local historian offering caldera walks, winery visits and quiet beaches.'),
];

List<Post> seedPosts() => [
      Post(id: 'p1', userName: 'Ayesha Rahman', userSeed: 'ayesha', imageSeed: 'sajek-clouds',
          placeId: 'sajek', time: '2h',
          caption: 'Woke up above the clouds at Sajek. Worth the 4 am jeep ride!',
          likes: 248,
          comments: [Comment('Tanvir', 'Which cottage did you stay in?'), Comment('Mei Lin', 'This is going on my list.')]),
      Post(id: 'v1', userName: 'Mei Lin', userSeed: 'meilin', imageSeed: 'kyoto-gion',
          placeId: 'kyoto', time: '5h', isVideo: true, videoTitle: 'Kyoto in 60 seconds',
          caption: 'Fushimi Inari before the crowds. Arrive by 6:30 am.',
          likes: 1320, comments: [Comment('Carlos', 'The lighting is unreal.')]),
      Post(id: 'p2', userName: 'Carlos Vega', userSeed: 'carlos', imageSeed: 'machu-sunrise',
          placeId: 'machu-picchu', time: '1d',
          caption: 'Day 4 on the Inca Trail. Legs are done, heart is full.',
          likes: 905, comments: [Comment('Lucia', 'Congrats! Did you see the sun gate?')]),
      Post(id: 'p0', userName: 'Emmie Watson', userSeed: 'me', imageSeed: 'kaptai-lake-sunset',
          placeId: 'kaptai', time: '6d',
          caption: 'Golden hour on Kaptai Lake. Our boatman Rafiq knew every hidden cove. Planning to come back in December!',
          likes: 186, comments: [Comment('Ayesha', 'So beautiful! Join us in December 🙌')]),
      Post(id: 'v2', userName: 'Tanvir Hasan', userSeed: 'tanvir', imageSeed: 'kaptai-boat',
          placeId: 'kaptai', time: '1d', isVideo: true, videoTitle: 'Kaptai Lake boat route',
          caption: 'Full route from Rangamati ghat to the Hanging Bridge, with prices.',
          likes: 477, comments: []),
      Post(id: 'p3', userName: 'Nora Haddad', userSeed: 'nora', imageSeed: 'merzouga-dunes',
          placeId: 'sahara', time: '2d',
          caption: 'Camel caravan at golden hour. Dinner by the fire was the best tagine of my life.',
          likes: 389, comments: [Comment('Sam', 'Booking this for March!')]),
      Post(id: 'v3', userName: 'Sam Okafor', userSeed: 'sam', imageSeed: 'raja-ampat-reef',
          placeId: 'raja-ampat', time: '3d', isVideo: true, videoTitle: 'Snorkeling Raja Ampat',
          caption: 'Manta rays under the jetty. Homestay costs \$30 a night.',
          likes: 2210, comments: [Comment('Ayesha', 'Adding to the bucket list.')]),
      Post(id: 'p4', userName: 'Eleni Katsaros', userSeed: 'eleni', imageSeed: 'santorini-oia',
          placeId: 'santorini', time: '4d',
          caption: 'Skip Oia at sunset. Imerovigli has the same view without the crowd.',
          likes: 612, comments: []),
    ];

List<Booking> seedBookings() => [
      Booking(id: 'b1', title: 'Vagabond Ventures', location: 'Rangamati, Bangladesh', type: 'tour',
          seed: 'kaptai', ref: 'EH-20418', amount: 120,
          start: DateTime.now().add(const Duration(days: 12)),
          end: DateTime.now().add(const Duration(days: 15))),
      Booking(id: 'b2', title: 'Dhaka to Cox\'s Bazar', location: 'US-Bangla Airlines', type: 'flight',
          seed: 'coxs', ref: 'EH-19377', amount: 74,
          start: DateTime.now().subtract(const Duration(days: 40)),
          end: DateTime.now().subtract(const Duration(days: 40)), status: 'Completed'),
    ];

List<AppNotification> seedNotifications() => [
      AppNotification(id: 'n0', kind: 'buddy', title: 'Lena Fischer wants to be your travel buddy',
          body: 'You have 9 mutual buddies. Lena is going to Machu Picchu next.', time: '1:20 PM', day: 'Today'),
      AppNotification(id: 'n00', kind: 'trip', title: 'Tanvir added a stop to Kaptai & Sajek hills',
          body: 'Day 2: Boat tour of Kaptai Lake at 8:00 AM.', time: '1:02 PM', day: 'Today'),
      AppNotification(id: 'n000', kind: 'group', title: 'New in Travelers of Bangladesh',
          body: 'Ayesha posted: Road to Sajek is open again.', time: '12:58 PM', day: 'Today'),
      AppNotification(id: 'n1', kind: 'hotel', title: 'Booking confirmed',
          body: 'Vagabond Ventures is confirmed. Check-in opens at 8:00 AM.', time: '12:45 PM', day: 'Today'),
      AppNotification(id: 'n2', kind: 'community', title: 'Ayesha liked your post',
          body: 'Ayesha Rahman and 12 others liked your Sajek Valley photo.', time: '11:10 AM', day: 'Today'),
      AppNotification(id: 'n3', kind: 'flight', title: 'Fare drop alert',
          body: 'Dhaka to Kathmandu flights are \$40 cheaper this week.', time: '9:30 AM', day: 'Today', read: true),
      AppNotification(id: 'n4', kind: 'app', title: 'New: How to go guides',
          body: 'Every place now shows flights, buses and the last stretch step by step.', time: '3:45 PM', day: 'Yesterday', read: true),
    ];
