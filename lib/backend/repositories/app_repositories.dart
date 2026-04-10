import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_models.dart';
import '../services/app_services.dart';

abstract class AuthRepository {
  Stream<AppUser?> authStateChanges();
  Future<AppUser?> currentUser();
  Future<AppUser> signIn({
    required String email,
    required String password,
  });
  Future<AppUser> signUp({
    required String email,
    required String password,
    required String fullName,
  });
  Future<void> sendPasswordReset(String email);
  Future<void> signOut();
}

abstract class CommunityRepository {
  Future<List<CommunityPost>> getPosts();
  Future<List<CommunityPost>> getSavedPosts();
  Future<List<DestinationSpot>> getDestinations();
  Future<void> createPost({
    required String location,
    required String caption,
    required String imageUrl,
  });
  Future<void> toggleLike(String postId);
  Future<void> toggleSavePost(String postId);
}

abstract class BookingRepository {
  Future<List<HotelDeal>> getHotels();
  Future<List<TicketDeal>> getTickets();
  Future<List<BookingRecord>> getBookings();
  Future<void> createBooking({
    required String type,
    required String itemId,
    required String title,
    required String subtitle,
    required int price,
  });
}

abstract class ProfileRepository {
  Future<AppUser?> getProfile();
}

class MockAuthRepository implements AuthRepository {
  MockAuthRepository(this._service);

  final MockDataService _service;

  @override
  Stream<AppUser?> authStateChanges() => _service.authStateChanges();

  @override
  Future<AppUser?> currentUser() => _service.currentUser();

  @override
  Future<void> sendPasswordReset(String email) => _service.sendPasswordReset(email);

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) {
    return _service.signIn(email: email, password: password);
  }

  @override
  Future<AppUser> signUp({
    required String email,
    required String password,
    required String fullName,
  }) {
    return _service.signUp(
      email: email,
      password: password,
      fullName: fullName,
    );
  }

  @override
  Future<void> signOut() => _service.signOut();
}

class MockCommunityRepository implements CommunityRepository {
  MockCommunityRepository(this._service);

  final MockDataService _service;

  @override
  Future<void> createPost({
    required String location,
    required String caption,
    required String imageUrl,
  }) =>
      _service.createPost(
        location: location,
        caption: caption,
        imageUrl: imageUrl,
      );

  @override
  Future<List<DestinationSpot>> getDestinations() => _service.destinations();

  @override
  Future<List<CommunityPost>> getPosts() => _service.posts();

  @override
  Future<List<CommunityPost>> getSavedPosts() => _service.savedPosts();

  @override
  Future<void> toggleLike(String postId) => _service.toggleLike(postId);

  @override
  Future<void> toggleSavePost(String postId) => _service.toggleSavePost(postId);
}

class MockBookingRepository implements BookingRepository {
  MockBookingRepository(this._service);

  final MockDataService _service;

  @override
  Future<void> createBooking({
    required String type,
    required String itemId,
    required String title,
    required String subtitle,
    required int price,
  }) {
    return _service.createBooking(
      type: type,
      itemId: itemId,
      title: title,
      subtitle: subtitle,
      price: price,
    );
  }

  @override
  Future<List<BookingRecord>> getBookings() => _service.bookings();

  @override
  Future<List<HotelDeal>> getHotels() => _service.hotels();

  @override
  Future<List<TicketDeal>> getTickets() => _service.tickets();
}

class MockProfileRepository implements ProfileRepository {
  MockProfileRepository(this._service);

  final MockDataService _service;

  @override
  Future<AppUser?> getProfile() => _service.currentUser();
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._services);

  final FirebaseServices _services;

  CollectionReference<Map<String, dynamic>> get _users =>
      _services.firestore.collection('users');

  @override
  Stream<AppUser?> authStateChanges() {
    return _services.auth.authStateChanges().asyncMap((user) async {
      if (user == null) return null;
      return _loadUser(user);
    });
  }

  @override
  Future<AppUser?> currentUser() async {
    final user = _services.auth.currentUser;
    if (user == null) return null;
    return _loadUser(user);
  }

  Future<AppUser> _loadUser(User authUser) async {
    final doc = await _users.doc(authUser.uid).get();
    if (!doc.exists) {
      final created = AppUser(
        id: authUser.uid,
        email: authUser.email ?? '',
        name: authUser.displayName ?? 'Explorer',
        handle:
            '@${(authUser.displayName ?? authUser.email?.split('@').first ?? 'explorer').toLowerCase().replaceAll(' ', '')}',
        bio: 'Traveler on ExploreHub',
        avatarUrl: authUser.photoURL ?? '',
        homeCity: 'Add your city',
        stats: const UserStats(followers: 0, trips: 0, bookings: 0),
      );
      await _users.doc(authUser.uid).set(created.toMap());
      return created;
    }
    return AppUser.fromMap(doc.id, doc.data()!);
  }

  @override
  Future<void> sendPasswordReset(String email) {
    return _services.auth.sendPasswordResetEmail(email: email);
  }

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _services.auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return _loadUser(credential.user!);
  }

  @override
  Future<AppUser> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final credential = await _services.auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await credential.user!.updateDisplayName(fullName);
    final user = AppUser(
      id: credential.user!.uid,
      email: email,
      name: fullName,
      handle: '@${fullName.toLowerCase().replaceAll(' ', '')}',
      bio: 'Traveler on ExploreHub',
      avatarUrl: '',
      homeCity: 'Add your city',
      stats: const UserStats(followers: 0, trips: 0, bookings: 0),
    );
    await _users.doc(user.id).set(user.toMap());
    return user;
  }

  @override
  Future<void> signOut() => _services.auth.signOut();
}

class FirebaseCommunityRepository implements CommunityRepository {
  FirebaseCommunityRepository(this._services);

  final FirebaseServices _services;

  CollectionReference<Map<String, dynamic>> get _posts =>
      _services.firestore.collection('posts');

  CollectionReference<Map<String, dynamic>> get _destinations =>
      _services.firestore.collection('destinations');

  String? get _currentUserId => _services.auth.currentUser?.uid;

  @override
  Future<void> createPost({
    required String location,
    required String caption,
    required String imageUrl,
  }) async {
    final user = _services.auth.currentUser;
    if (user == null) {
      throw StateError('You need to log in before creating a post.');
    }
    await _posts.add(
      CommunityPost(
        id: '',
        authorId: user.uid,
        author: user.displayName ?? user.email?.split('@').first ?? 'Traveler',
        location: location,
        caption: caption,
        imageUrl: imageUrl,
        likes: 0,
        comments: 0,
        tags: const ['Community'],
        createdAt: DateTime.now(),
      ).toMap(),
    );
  }

  @override
  Future<List<DestinationSpot>> getDestinations() async {
    final snapshot = await _destinations.get();
    if (snapshot.docs.isEmpty) {
      return MockDataService().destinations();
    }
    return snapshot.docs
        .map(
          (doc) => DestinationSpot(
            id: doc.id,
            name: doc.data()['name'] as String? ?? '',
            country: doc.data()['country'] as String? ?? '',
            description: doc.data()['description'] as String? ?? '',
            imageUrl: doc.data()['imageUrl'] as String? ?? '',
            bestTime: doc.data()['bestTime'] as String? ?? '',
            communityCount: doc.data()['communityCount'] as int? ?? 0,
          ),
        )
        .toList();
  }

  @override
  Future<List<CommunityPost>> getPosts() async {
    final snapshot = await _posts.orderBy('createdAt', descending: true).get();
    return snapshot.docs
        .map(
          (doc) => CommunityPost.fromMap(
            doc.id,
            doc.data(),
            currentUserId: _currentUserId,
          ),
        )
        .toList();
  }

  @override
  Future<List<CommunityPost>> getSavedPosts() async {
    if (_currentUserId == null) return [];
    final snapshot = await _posts.where('savedBy', arrayContains: _currentUserId).get();
    return snapshot.docs
        .map(
          (doc) => CommunityPost.fromMap(
            doc.id,
            doc.data(),
            currentUserId: _currentUserId,
          ),
        )
        .toList();
  }

  @override
  Future<void> toggleLike(String postId) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw StateError('You need to log in before liking posts.');
    }
    final doc = await _posts.doc(postId).get();
    final data = doc.data();
    if (data == null) return;
    final likedBy = List<String>.from(data['likedBy'] as List? ?? const []);
    final hasLiked = likedBy.contains(userId);
    await _posts.doc(postId).update({
      'likedBy': hasLiked
          ? FieldValue.arrayRemove([userId])
          : FieldValue.arrayUnion([userId]),
      'likes': hasLiked
          ? FieldValue.increment(-1)
          : FieldValue.increment(1),
    });
  }

  @override
  Future<void> toggleSavePost(String postId) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw StateError('You need to log in before saving posts.');
    }
    final doc = await _posts.doc(postId).get();
    final data = doc.data();
    if (data == null) return;
    final savedBy = List<String>.from(data['savedBy'] as List? ?? const []);
    final isSaved = savedBy.contains(userId);
    await _posts.doc(postId).update({
      'savedBy': isSaved
          ? FieldValue.arrayRemove([userId])
          : FieldValue.arrayUnion([userId]),
    });
  }
}

class FirebaseBookingRepository implements BookingRepository {
  FirebaseBookingRepository(this._services);

  final FirebaseServices _services;

  CollectionReference<Map<String, dynamic>> get _hotels =>
      _services.firestore.collection('hotels');
  CollectionReference<Map<String, dynamic>> get _tickets =>
      _services.firestore.collection('tickets');
  CollectionReference<Map<String, dynamic>> get _bookings =>
      _services.firestore.collection('bookings');

  @override
  Future<void> createBooking({
    required String type,
    required String itemId,
    required String title,
    required String subtitle,
    required int price,
  }) async {
    final userId = _services.auth.currentUser?.uid;
    if (userId == null) {
      throw StateError('You need to log in before booking.');
    }
    await _bookings.add(
      BookingRecord(
        id: '',
        userId: userId,
        type: type,
        itemId: itemId,
        title: title,
        subtitle: subtitle,
        price: price,
        status: 'pending',
        createdAt: DateTime.now(),
      ).toMap(),
    );
  }

  @override
  Future<List<BookingRecord>> getBookings() async {
    final userId = _services.auth.currentUser?.uid;
    if (userId == null) return [];
    final snapshot = await _bookings
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => BookingRecord.fromMap(doc.id, doc.data()))
        .toList();
  }

  @override
  Future<List<HotelDeal>> getHotels() async {
    final snapshot = await _hotels.get();
    if (snapshot.docs.isEmpty) {
      return MockDataService().hotels();
    }
    return snapshot.docs
        .map((doc) => HotelDeal.fromMap(doc.id, doc.data()))
        .toList();
  }

  @override
  Future<List<TicketDeal>> getTickets() async {
    final snapshot = await _tickets.get();
    if (snapshot.docs.isEmpty) {
      return MockDataService().tickets();
    }
    return snapshot.docs
        .map((doc) => TicketDeal.fromMap(doc.id, doc.data()))
        .toList();
  }
}

class FirebaseProfileRepository implements ProfileRepository {
  FirebaseProfileRepository(this._authRepository);

  final FirebaseAuthRepository _authRepository;

  @override
  Future<AppUser?> getProfile() => _authRepository.currentUser();
}
