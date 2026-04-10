import '../models/app_models.dart';
import '../services/app_services.dart';

class AuthRepository {
  AuthRepository(this._service);

  final MockDataService _service;

  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    return _service.currentUser();
  }

  Future<AppUser> signUp({
    required String email,
    required String password,
  }) async {
    return _service.currentUser();
  }

  Future<void> sendOtp(String email) async {}

  Future<void> verifyOtp(String otp) async {}
}

class CommunityRepository {
  CommunityRepository(this._service);

  final MockDataService _service;

  Future<List<CommunityPost>> getPosts() => _service.posts();

  Future<List<DestinationSpot>> getDestinations() => _service.destinations();
}

class BookingRepository {
  BookingRepository(this._service);

  final MockDataService _service;

  Future<List<HotelDeal>> getHotels() => _service.hotels();

  Future<List<TicketDeal>> getTickets() => _service.tickets();
}

class ProfileRepository {
  ProfileRepository(this._service);

  final MockDataService _service;

  Future<AppUser> getProfile() => _service.currentUser();
}
