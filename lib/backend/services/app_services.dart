import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/app_models.dart';

class ApiClient {
  const ApiClient();
}

class FirebaseServices {
  FirebaseServices({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : auth = auth ?? FirebaseAuth.instance,
        firestore = firestore ?? FirebaseFirestore.instance,
        storage = storage ?? FirebaseStorage.instance;

  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final FirebaseStorage storage;
}

class MockDataService {
  MockDataService() {
    _seed();
  }

  final _authController = StreamController<AppUser?>.broadcast();
  AppUser? _currentUser;
  final List<CommunityPost> _posts = [];
  final List<DestinationSpot> _destinations = [];
  final List<HotelDeal> _hotels = [];
  final List<TicketDeal> _tickets = [];
  final List<BookingRecord> _bookings = [];

  void _seed() {
    _currentUser = const AppUser(
      id: 'mock-user-1',
      email: 'imon@example.com',
      name: 'Imon Rahman',
      handle: '@imontravels',
      bio:
          'Slow traveler, hostel reviewer, and the friend who always finds the sunset cafe.',
      avatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e',
      homeCity: 'Dhaka, Bangladesh',
      stats: UserStats(followers: 18400, trips: 27, bookings: 11),
    );

    _posts
      ..clear()
      ..addAll([
        CommunityPost(
          id: 'post-1',
          authorId: 'user-2',
          author: 'Ava Miles',
          location: 'Cappadocia, Turkey',
          caption:
              'Sunrise balloon rides are worth the 4:30 AM wake-up. Book the valley view breakfast too.',
          imageUrl:
              'https://images.unsplash.com/photo-1519046904884-53103b34b206',
          likes: 1240,
          comments: 92,
          tags: const ['Adventure', 'Sunrise', 'Balloon'],
          createdAt: DateTime(2026, 4, 5),
        ),
        CommunityPost(
          id: 'post-2',
          authorId: 'user-3',
          author: 'Rifat Noor',
          location: 'Hallstatt, Austria',
          caption:
              'Three-night village stay, lakeside walk, and a tiny bakery I still think about.',
          imageUrl:
              'https://images.unsplash.com/photo-1506744038136-46273834b3fb',
          likes: 847,
          comments: 41,
          tags: const ['Europe', 'Village', 'Scenic'],
          createdAt: DateTime(2026, 4, 3),
        ),
      ]);

    _destinations
      ..clear()
      ..addAll(const [
        DestinationSpot(
          id: 'dest-1',
          name: 'Santorini',
          country: 'Greece',
          description: 'Whitewashed stays, caldera sunsets, and island food tours.',
          imageUrl:
              'https://images.unsplash.com/photo-1570077188670-e3a8d69ac5ff',
          bestTime: 'Apr - Jun',
          communityCount: 3240,
        ),
        DestinationSpot(
          id: 'dest-2',
          name: 'Kyoto',
          country: 'Japan',
          description: 'Temples, quiet alleys, tea houses, and spring blossoms.',
          imageUrl:
              'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e',
          bestTime: 'Mar - May',
          communityCount: 5120,
        ),
      ]);

    _hotels
      ..clear()
      ..addAll(const [
        HotelDeal(
          id: 'hotel-1',
          name: 'Azure Coast Resort',
          city: 'Phuket',
          pricePerNight: 120,
          rating: 4.8,
          imageUrl:
              'https://images.unsplash.com/photo-1566073771259-6a8506099945',
          features: ['Breakfast', 'Pool', 'Airport pickup'],
        ),
        HotelDeal(
          id: 'hotel-2',
          name: 'Nomad Loft Hotel',
          city: 'Istanbul',
          pricePerNight: 89,
          rating: 4.6,
          imageUrl:
              'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267',
          features: ['Coworking', 'City view', 'Late checkout'],
        ),
      ]);

    _tickets
      ..clear()
      ..addAll([
        TicketDeal(
          id: 'ticket-1',
          from: 'DAC',
          to: 'IST',
          carrier: 'Turkish Airlines',
          departure: DateTime(2026, 5, 16, 9, 45),
          duration: '8h 20m',
          price: 540,
        ),
        TicketDeal(
          id: 'ticket-2',
          from: 'DAC',
          to: 'BKK',
          carrier: 'Thai Airways',
          departure: DateTime(2026, 5, 18, 12, 10),
          duration: '2h 30m',
          price: 220,
        ),
      ]);

    _authController.add(_currentUser);
  }

  Stream<AppUser?> authStateChanges() async* {
    yield _currentUser;
    yield* _authController.stream;
  }

  Future<AppUser?> currentUser() async => _currentUser;

  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    _currentUser = _currentUser?.copyWith(email: email);
    _authController.add(_currentUser);
    return _currentUser!;
  }

  Future<AppUser> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    _currentUser = AppUser(
      id: 'mock-${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      name: fullName,
      handle: '@${fullName.toLowerCase().replaceAll(' ', '')}',
      bio: 'New traveler on ExploreHub',
      avatarUrl: '',
      homeCity: 'Add your city',
      stats: const UserStats(followers: 0, trips: 0, bookings: 0),
    );
    _authController.add(_currentUser);
    return _currentUser!;
  }

  Future<void> sendPasswordReset(String email) async {}

  Future<void> signOut() async {
    _currentUser = null;
    _authController.add(null);
  }

  Future<List<CommunityPost>> posts() async => List.unmodifiable(_posts);

  Future<void> createPost({
    required String location,
    required String caption,
    required String imageUrl,
  }) async {
    final user = _currentUser;
    if (user == null) return;
    _posts.insert(
      0,
      CommunityPost(
        id: 'post-${DateTime.now().millisecondsSinceEpoch}',
        authorId: user.id,
        author: user.name,
        location: location,
        caption: caption,
        imageUrl: imageUrl,
        likes: 0,
        comments: 0,
        tags: const ['Community'],
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> toggleLike(String postId) async {
    final index = _posts.indexWhere((post) => post.id == postId);
    if (index < 0) return;
    final post = _posts[index];
    final nextLiked = !post.isLiked;
    _posts[index] = post.copyWith(
      isLiked: nextLiked,
      likes: nextLiked ? post.likes + 1 : post.likes - 1,
    );
  }

  Future<void> toggleSavePost(String postId) async {
    final index = _posts.indexWhere((post) => post.id == postId);
    if (index < 0) return;
    final post = _posts[index];
    _posts[index] = post.copyWith(isSaved: !post.isSaved);
  }

  Future<List<CommunityPost>> savedPosts() async {
    return _posts.where((post) => post.isSaved).toList();
  }

  Future<List<DestinationSpot>> destinations() async =>
      List.unmodifiable(_destinations);

  Future<List<HotelDeal>> hotels() async => List.unmodifiable(_hotels);

  Future<List<TicketDeal>> tickets() async => List.unmodifiable(_tickets);

  Future<void> createBooking({
    required String type,
    required String itemId,
    required String title,
    required String subtitle,
    required int price,
  }) async {
    final user = _currentUser;
    if (user == null) return;
    _bookings.insert(
      0,
      BookingRecord(
        id: 'booking-${DateTime.now().millisecondsSinceEpoch}',
        userId: user.id,
        type: type,
        itemId: itemId,
        title: title,
        subtitle: subtitle,
        price: price,
        status: 'confirmed',
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<List<BookingRecord>> bookings() async => List.unmodifiable(_bookings);
}
