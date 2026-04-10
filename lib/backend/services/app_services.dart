import 'package:dio/dio.dart';

import '../models/app_models.dart';

class ApiClient {
  ApiClient()
      : dio = Dio(
          BaseOptions(
            baseUrl: 'https://api.explorehub.app',
            connectTimeout: const Duration(seconds: 12),
            receiveTimeout: const Duration(seconds: 12),
          ),
        );

  final Dio dio;
}

class MockDataService {
  const MockDataService();

  Future<AppUser> currentUser() async {
    return const AppUser(
      name: 'Imon Rahman',
      handle: '@imontravels',
      bio:
          'Slow traveler, hostel reviewer, and the friend who always finds the sunset cafe.',
      avatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e',
      homeCity: 'Dhaka, Bangladesh',
      stats: UserStats(followers: 18400, trips: 27, bookings: 11),
    );
  }

  Future<List<CommunityPost>> posts() async {
    return const [
      CommunityPost(
        author: 'Ava Miles',
        location: 'Cappadocia, Turkey',
        caption:
            'Sunrise balloon rides are worth the 4:30 AM wake-up. Book the valley view breakfast too.',
        imageUrl:
            'https://images.unsplash.com/photo-1519046904884-53103b34b206',
        likes: 1240,
        comments: 92,
        tags: ['Adventure', 'Sunrise', 'Balloon'],
      ),
      CommunityPost(
        author: 'Rifat Noor',
        location: 'Hallstatt, Austria',
        caption:
            'Three-night village stay, lakeside walk, and a tiny bakery I still think about.',
        imageUrl:
            'https://images.unsplash.com/photo-1506744038136-46273834b3fb',
        likes: 847,
        comments: 41,
        tags: ['Europe', 'Village', 'Scenic'],
      ),
      CommunityPost(
        author: 'Lina Costa',
        location: 'Bali, Indonesia',
        caption:
            'Coworking by day, waterfall hopping by evening. Great spot for digital nomads.',
        imageUrl:
            'https://images.unsplash.com/photo-1507525428034-b723cf961d3e',
        likes: 2311,
        comments: 132,
        tags: ['Remote Work', 'Beach', 'Community'],
      ),
    ];
  }

  Future<List<DestinationSpot>> destinations() async {
    return const [
      DestinationSpot(
        name: 'Santorini',
        country: 'Greece',
        description: 'Whitewashed stays, caldera sunsets, and island food tours.',
        imageUrl:
            'https://images.unsplash.com/photo-1570077188670-e3a8d69ac5ff',
        bestTime: 'Apr - Jun',
        communityCount: 3240,
      ),
      DestinationSpot(
        name: 'Kyoto',
        country: 'Japan',
        description: 'Temples, quiet alleys, tea houses, and spring blossoms.',
        imageUrl:
            'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e',
        bestTime: 'Mar - May',
        communityCount: 5120,
      ),
      DestinationSpot(
        name: 'Marrakesh',
        country: 'Morocco',
        description: 'Color, markets, riads, rooftop dinners, and desert gateways.',
        imageUrl:
            'https://images.unsplash.com/photo-1539020140153-e479b8c22e70',
        bestTime: 'Oct - Dec',
        communityCount: 1790,
      ),
    ];
  }

  Future<List<HotelDeal>> hotels() async {
    return const [
      HotelDeal(
        name: 'Azure Coast Resort',
        city: 'Phuket',
        pricePerNight: 120,
        rating: 4.8,
        imageUrl:
            'https://images.unsplash.com/photo-1566073771259-6a8506099945',
        features: ['Breakfast', 'Pool', 'Airport pickup'],
      ),
      HotelDeal(
        name: 'Nomad Loft Hotel',
        city: 'Istanbul',
        pricePerNight: 89,
        rating: 4.6,
        imageUrl:
            'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267',
        features: ['Coworking', 'City view', 'Late checkout'],
      ),
      HotelDeal(
        name: 'Nordic Harbor Stay',
        city: 'Copenhagen',
        pricePerNight: 154,
        rating: 4.9,
        imageUrl:
            'https://images.unsplash.com/photo-1551882547-ff40c63fe5fa',
        features: ['Harbor view', 'Sauna', 'Free bikes'],
      ),
    ];
  }

  Future<List<TicketDeal>> tickets() async {
    return [
      TicketDeal(
        from: 'DAC',
        to: 'IST',
        carrier: 'Turkish Airlines',
        departure: DateTime(2026, 5, 16, 9, 45),
        duration: '8h 20m',
        price: 540,
      ),
      TicketDeal(
        from: 'DAC',
        to: 'BKK',
        carrier: 'Thai Airways',
        departure: DateTime(2026, 5, 18, 12, 10),
        duration: '2h 30m',
        price: 220,
      ),
      TicketDeal(
        from: 'DAC',
        to: 'DXB',
        carrier: 'Emirates',
        departure: DateTime(2026, 5, 24, 1, 15),
        duration: '5h 10m',
        price: 410,
      ),
    ];
  }
}
