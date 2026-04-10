import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../backend/models/app_models.dart';
import '../../backend/repositories/app_repositories.dart';
import '../../backend/services/app_services.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
final mockDataServiceProvider = Provider<MockDataService>(
  (ref) => const MockDataService(),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(mockDataServiceProvider)),
);
final communityRepositoryProvider = Provider<CommunityRepository>(
  (ref) => CommunityRepository(ref.watch(mockDataServiceProvider)),
);
final bookingRepositoryProvider = Provider<BookingRepository>(
  (ref) => BookingRepository(ref.watch(mockDataServiceProvider)),
);
final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(mockDataServiceProvider)),
);

final currentUserProvider = FutureProvider<AppUser>(
  (ref) => ref.watch(profileRepositoryProvider).getProfile(),
);
final postsProvider = FutureProvider<List<CommunityPost>>(
  (ref) => ref.watch(communityRepositoryProvider).getPosts(),
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

final rememberMeProvider = StateProvider<bool>((ref) => true);
