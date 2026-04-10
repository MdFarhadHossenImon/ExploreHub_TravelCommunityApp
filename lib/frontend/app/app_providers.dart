import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../app_config.dart';
import '../../backend/models/app_models.dart';
import '../../backend/repositories/app_repositories.dart';
import '../../backend/services/app_services.dart';

final apiClientProvider = Provider<ApiClient>((ref) => const ApiClient());
final mockDataServiceProvider = Provider<MockDataService>(
  (ref) => MockDataService(),
);
final firebaseServicesProvider = Provider<FirebaseServices>(
  (ref) => FirebaseServices(),
);
final useFirebaseProvider = Provider<bool>((ref) => AppConfig.enableFirebase);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (ref.watch(useFirebaseProvider)) {
    return FirebaseAuthRepository(ref.watch(firebaseServicesProvider));
  }
  return MockAuthRepository(ref.watch(mockDataServiceProvider));
});

final communityRepositoryProvider = Provider<CommunityRepository>((ref) {
  if (ref.watch(useFirebaseProvider)) {
    return FirebaseCommunityRepository(ref.watch(firebaseServicesProvider));
  }
  return MockCommunityRepository(ref.watch(mockDataServiceProvider));
});

final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  if (ref.watch(useFirebaseProvider)) {
    return FirebaseBookingRepository(ref.watch(firebaseServicesProvider));
  }
  return MockBookingRepository(ref.watch(mockDataServiceProvider));
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  if (ref.watch(useFirebaseProvider)) {
    return FirebaseProfileRepository(
      FirebaseAuthRepository(ref.watch(firebaseServicesProvider)),
    );
  }
  return MockProfileRepository(ref.watch(mockDataServiceProvider));
});

final authStateProvider = StreamProvider<AppUser?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

final currentUserProvider = FutureProvider<AppUser?>(
  (ref) => ref.watch(profileRepositoryProvider).getProfile(),
);

final postsProvider = FutureProvider<List<CommunityPost>>(
  (ref) => ref.watch(communityRepositoryProvider).getPosts(),
);

final savedPostsProvider = FutureProvider<List<CommunityPost>>(
  (ref) => ref.watch(communityRepositoryProvider).getSavedPosts(),
);

final destinationsProvider = FutureProvider<List<DestinationSpot>>(
  (ref) => ref.watch(communityRepositoryProvider).getDestinations(),
);

final hotelsProvider = FutureProvider<List<HotelDeal>>(
  (ref) => ref.watch(bookingRepositoryProvider).getHotels(),
);

final ticketsProvider = FutureProvider<List<TicketDeal>>(
  (ref) => ref.watch(bookingRepositoryProvider).getTickets(),
);

final bookingsProvider = FutureProvider<List<BookingRecord>>(
  (ref) => ref.watch(bookingRepositoryProvider).getBookings(),
);

final rememberMeProvider = StateProvider<bool>((ref) => true);
