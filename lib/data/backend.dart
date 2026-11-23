import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/env.dart';
import 'models.dart';
import 'social.dart';

/// Turns any error into a message a traveler can read.
String errText(Object e) {
  if (e is AuthException) return e.message;
  if (e is PostgrestException) return e.message;
  if (e is StorageException) return e.message;
  return 'Something went wrong. Check your connection and try again.';
}

/// Every call to Supabase lives here, so screens never touch the SDK directly.
/// Row Level Security (see supabase/schema.sql) decides what each user may read or write.
class Backend {
  static bool get on => Env.configured;
  static SupabaseClient get _c => Supabase.instance.client;
  static User? get user => on ? _c.auth.currentUser : null;
  static String? get uid => user?.id;
  static Stream<AuthState> get authChanges => _c.auth.onAuthStateChange;

  static Future<void> init() async {
    if (!on) return;
    await Supabase.initialize(url: Env.supabaseUrl, anonKey: Env.supabaseAnonKey);
  }

  // ---------- auth ----------
  /// Where links in auth emails send people back to: this web page, or the app's deep link on phones.
  static String get returnUrl => kIsWeb ? '${Uri.base.origin}${Uri.base.path}' : Env.authRedirect;

  static Future<AuthResponse> signUp(String email, String password) =>
      _c.auth.signUp(email: email, password: password, emailRedirectTo: returnUrl);

  static Future<AuthResponse> signIn(String email, String password) =>
      _c.auth.signInWithPassword(email: email, password: password);

  static Future<AuthResponse> verifyOtp(String email, String code, {bool recovery = false}) =>
      _c.auth.verifyOTP(email: email, token: code, type: recovery ? OtpType.recovery : OtpType.signup);

  static Future<void> resendSignupCode(String email) =>
      _c.auth.resend(type: OtpType.signup, email: email, emailRedirectTo: returnUrl);

  static Future<void> sendResetCode(String email) => _c.auth.resetPasswordForEmail(email, redirectTo: returnUrl);

  static Future<void> updatePassword(String password) async {
    await _c.auth.updateUser(UserAttributes(password: password));
  }

  static Future<void> oauth(OAuthProvider provider) async {
    await _c.auth.signInWithOAuth(provider, redirectTo: kIsWeb ? null : Env.authRedirect);
  }

  static Future<void> signOut() async {
    try {
      await _c.auth.signOut();
    } catch (_) {/* already signed out or account deleted */}
  }

  /// Deletes the account and uploaded files through the `delete-account` Edge Function.
  static Future<void> deleteAccount() async {
    final res = await _c.functions.invoke('delete-account', method: HttpMethod.post);
    if (res.status != 200) throw Exception('Could not delete the account. Please try again.');
  }

  // ---------- profile ----------
  static Future<Map<String, dynamic>?> profile() =>
      _c.from('profiles_view').select().eq('id', uid!).maybeSingle();

  static Future<void> updateName(String name) async {
    await _c.from('profiles').update({'name': name}).eq('id', uid!);
  }

  static Future<void> updateProfile(Map<String, dynamic> fields) async {
    await _c.from('profiles').update(fields).eq('id', uid!);
  }

  // ---------- catalog ----------
  static Future<List<Place>> places() async {
    final rows = await _c.from('places').select().order('reviews', ascending: false);
    return rows.map<Place>((r) => Place.fromRow(r)).toList();
  }

  static Future<List<Guide>> guides() async {
    final rows = await _c.from('guides').select().order('rating', ascending: false);
    return rows.map<Guide>((r) => Guide.fromRow(r)).toList();
  }

  static Future<List<Review>> reviews(String placeId) async {
    final rows = await _c
        .from('reviews')
        .select('rating, body, created_at, profiles(name)')
        .eq('place_id', placeId)
        .order('created_at', ascending: false)
        .limit(30);
    return rows.map<Review>((r) {
      final who = (r['profiles'] is Map ? r['profiles']['name'] : null) as String? ?? 'Traveler';
      return Review(who, (r['rating'] as num).toDouble(), r['body'] as String,
          ago(DateTime.parse(r['created_at'] as String).toLocal()));
    }).toList();
  }

  static Future<void> addReview(String placeId, double rating, String body) async {
    await _c.from('reviews').insert({'place_id': placeId, 'rating': rating, 'body': body});
  }

  // ---------- community ----------
  static Future<List<Post>> posts() async {
    final rows = await _c.from('posts_feed').select().isFilter('group_id', null).order('created_at', ascending: false).limit(60);
    return rows.map<Post>((r) => Post.fromRow(r)).toList();
  }

  static Future<Set<String>> _ids(String table, String column) async {
    final rows = await _c.from(table).select(column).eq(table == 'follows' ? 'follower_id' : 'user_id', uid!);
    return rows.map<String>((r) => r[column] as String).toSet();
  }

  static Future<Set<String>> myLikes() => _ids('likes', 'post_id');
  static Future<Set<String>> mySavedPosts() => _ids('saved_posts', 'post_id');
  static Future<Set<String>> mySavedPlaces() => _ids('saved_places', 'place_id');
  static Future<Set<String>> myFollowing() => _ids('follows', 'following_id');

  static Future<Map<String, String>> myReactions() async {
    final rows = await _c.from('likes').select('post_id, emoji').eq('user_id', uid!);
    return {for (final r in rows) r['post_id'] as String: r['emoji'] as String? ?? '❤️'};
  }

  static Future<void> setReaction(String postId, String emoji) async {
    await _c.from('likes').upsert({'post_id': postId, 'user_id': uid, 'emoji': emoji});
  }

  static Future<void> setLike(String postId, bool on) async {
    if (on) {
      await _c.from('likes').insert({'post_id': postId});
    } else {
      await _c.from('likes').delete().eq('post_id', postId).eq('user_id', uid!);
    }
  }

  static Future<void> setSavedPost(String postId, bool on) async {
    if (on) {
      await _c.from('saved_posts').insert({'post_id': postId});
    } else {
      await _c.from('saved_posts').delete().eq('post_id', postId).eq('user_id', uid!);
    }
  }

  static Future<void> setSavedPlace(String placeId, bool on) async {
    if (on) {
      await _c.from('saved_places').insert({'place_id': placeId});
    } else {
      await _c.from('saved_places').delete().eq('place_id', placeId).eq('user_id', uid!);
    }
  }

  static Future<void> setFollow(String userId, bool on) async {
    if (on) {
      await _c.from('follows').insert({'following_id': userId});
    } else {
      await _c.from('follows').delete().eq('following_id', userId).eq('follower_id', uid!);
    }
  }

  static Future<List<Comment>> comments(String postId) async {
    final rows =
        await _c.from('comments').select('body, profiles(name)').eq('post_id', postId).order('created_at');
    return rows.map<Comment>((r) {
      final who = (r['profiles'] is Map ? r['profiles']['name'] : null) as String? ?? 'Traveler';
      return Comment(who, r['body'] as String);
    }).toList();
  }

  static Future<void> addComment(String postId, String body) async {
    await _c.from('comments').insert({'post_id': postId, 'body': body});
  }

  /// Uploads to Storage under "<user id>/<timestamp>.<ext>" (the folder rule in schema.sql)
  /// and returns the public URL.
  static Future<String> upload(Uint8List bytes, String ext, String mime, {String bucket = 'post-media'}) async {
    final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _c.storage.from(bucket).uploadBinary(path, bytes, fileOptions: FileOptions(contentType: mime));
    return _c.storage.from(bucket).getPublicUrl(path);
  }

  static Future<void> createPost({
    required String caption,
    String mediaUrl = '',
    String? placeId,
    bool isVideo = false,
    String? sharedPostId,
    String? locationName,
    String? locationCountry,
  }) async {
    await _c.from('posts').insert({
      'caption': caption,
      'media_url': mediaUrl,
      'place_id': placeId,
      'is_video': isVideo,
      if (sharedPostId != null) 'shared_post_id': sharedPostId,
      if (placeId == null && locationName != null && locationCountry != null) ...{
        'location_name': locationName,
        'location_country': locationCountry,
      },
    });
  }

  static Future<void> editPost(String postId, String caption) async {
    await _c.from('posts').update({'caption': caption, 'edited_at': DateTime.now().toUtc().toIso8601String()}).eq('id', postId);
  }

  /// Posts written by one traveler (for their profile page).
  static Future<List<Post>> postsBy(String userId) async {
    final rows = await _c.from('posts_feed').select().eq('user_id', userId).isFilter('group_id', null).order('created_at', ascending: false).limit(60);
    return rows.map<Post>((r) => Post.fromRow(r)).toList();
  }

  static Future<int> mutualBuddies(String other) async {
    final r = await _c.rpc('mutual_buddies', params: {'other': other});
    return (r as num?)?.toInt() ?? 0;
  }

  // ---------- meetups ----------
  static Future<List<Meetup>> meetups() async {
    final since = DateTime.now().subtract(const Duration(hours: 6)).toUtc().toIso8601String();
    final rows = await _c.from('meetups_view').select().gte('starts_at', since).order('starts_at').limit(100);
    return rows.map<Meetup>((r) => Meetup.fromRow(r)).toList();
  }

  static Future<Map<String, String>> myRsvps() async {
    final rows = await _c.from('meetup_rsvps').select('meetup_id, status').eq('user_id', uid!);
    return {for (final r in rows) r['meetup_id'] as String: r['status'] as String};
  }

  static Future<List<Map<String, dynamic>>> meetupGoing(String meetupId) async {
    final rows = await _c.from('meetup_rsvps').select('user_id, status, profiles(name, avatar_url)').eq('meetup_id', meetupId).order('created_at');
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<String> createMeetup({
    required String title,
    required String about,
    required String location,
    required DateTime startsAt,
    String? placeId,
    int? capacity,
    String? coverUrl,
  }) async {
    final r = await _c.from('meetups').insert({
      'title': title,
      'about': about,
      'location': location,
      'starts_at': startsAt.toUtc().toIso8601String(),
      'place_id': placeId,
      'capacity': capacity,
      'cover_url': coverUrl,
    }).select('id').single();
    return r['id'] as String;
  }

  static Future<void> deleteMeetup(String id) async {
    await _c.from('meetups').delete().eq('id', id);
  }

  static Future<void> setRsvp(String meetupId, String? status) async {
    if (status == null) {
      await _c.from('meetup_rsvps').delete().eq('meetup_id', meetupId).eq('user_id', uid!);
    } else {
      await _c.from('meetup_rsvps').upsert({'meetup_id': meetupId, 'user_id': uid, 'status': status});
    }
  }

  // ---------- presence & live notifications ----------
  static RealtimeChannel? _presence;

  /// Joins the shared presence channel. [onSync] gets the ids of everyone online right now.
  static void joinPresence(void Function(Set<String> online) onSync) {
    if (_presence != null || uid == null) return;
    final ch = _c.channel('online-travelers', opts: const RealtimeChannelConfig(self: true));
    ch.onPresenceSync((_) {
      final ids = <String>{};
      for (final s in ch.presenceState()) {
        for (final p in s.presences) {
          final id = p.payload['user_id'];
          if (id is String) ids.add(id);
        }
      }
      onSync(ids);
    }).subscribe((status, _) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        await ch.track({'user_id': uid, 'at': DateTime.now().toUtc().toIso8601String()});
      }
    });
    _presence = ch;
  }

  static Future<void> leavePresence() async {
    final ch = _presence;
    _presence = null;
    if (ch != null) await _c.removeChannel(ch);
  }

  static RealtimeChannel? _notif;

  /// Calls [onNew] whenever a notification for the signed-in user arrives.
  static void onNotification(void Function() onNew) {
    if (_notif != null || uid == null) return;
    _notif = _c
        .channel('notif-$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: uid),
          callback: (_) => onNew(),
        )
        .subscribe();
  }

  static Future<void> stopNotifications() async {
    final ch = _notif;
    _notif = null;
    if (ch != null) await _c.removeChannel(ch);
  }

  static Future<void> deletePost(String postId) async {
    await _c.from('posts').delete().eq('id', postId);
  }

  static Future<void> reportPost(String postId, String? userId, String reason) async {
    await _c.from('reports').insert({'post_id': postId, 'reported_user_id': userId, 'reason': reason});
  }

  static Future<void> blockUser(String userId) async {
    await _c.from('blocks').insert({'blocked_id': userId});
  }

  // ---------- bookings & notifications ----------
  static Future<List<Booking>> bookings() async {
    final rows = await _c.from('bookings').select().order('created_at', ascending: false);
    return rows.map<Booking>((r) => Booking.fromRow(r)).toList();
  }

  static Future<Booking> createBooking(BookingDraft d, double total, DateTime start, DateTime end) async {
    final ref = 'EH-${(DateTime.now().millisecondsSinceEpoch ~/ 1000).toRadixString(36).toUpperCase()}${Random().nextInt(90) + 10}';
    final row = await _c
        .from('bookings')
        .insert({
          'title': d.title,
          'location': d.location,
          'type': d.type,
          'seed': d.seed,
          'ref': ref,
          'amount': double.parse(total.toStringAsFixed(2)),
          'start_date': _date(start),
          'end_date': _date(end),
        })
        .select()
        .single();
    return Booking.fromRow(row);
  }

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Future<void> cancelBooking(String id) async {
    await _c.rpc('cancel_booking', params: {'b_id': id});
  }

  static Future<List<AppNotification>> notifications() async {
    final rows = await _c.from('notifications').select().order('created_at', ascending: false).limit(50);
    return rows.map<AppNotification>((r) => AppNotification.fromRow(r)).toList();
  }

  static Future<void> markRead(String id) async {
    await _c.from('notifications').update({'read': true}).eq('id', id);
  }

  static Future<void> markAllRead() async {
    await _c.from('notifications').update({'read': true}).eq('user_id', uid!).eq('read', false);
  }

  // ================= social =================

  static Future<List<Traveler>> travelers() async {
    final rows = await _c.from('profiles_view').select().order('created_at', ascending: false).limit(300);
    return rows.map<Traveler>((r) => Traveler.fromRow(r)).toList();
  }

  // ---- buddies ----
  static Future<List<Map<String, dynamic>>> buddyRows() async =>
      List<Map<String, dynamic>>.from(await _c.from('buddy_requests').select().or('from_id.eq.$uid,to_id.eq.$uid'));

  static Future<void> sendBuddyRequest(String to) async => _c.from('buddy_requests').insert({'from_id': uid, 'to_id': to});
  static Future<void> cancelBuddyRequest(String to) async => _c.from('buddy_requests').delete().eq('from_id', uid!).eq('to_id', to);
  static Future<void> acceptBuddy(String from) async =>
      _c.from('buddy_requests').update({'status': 'accepted'}).eq('from_id', from).eq('to_id', uid!);
  static Future<void> removeBuddy(String other) async =>
      _c.from('buddy_requests').delete().or('and(from_id.eq.$uid,to_id.eq.$other),and(from_id.eq.$other,to_id.eq.$uid)');

  // ---- stories ----
  static Future<List<Story>> stories() async {
    final rows = await _c.from('stories').select().order('created_at', ascending: false).limit(60);
    return rows.map<Story>((r) => Story.fromRow(r)).toList();
  }

  static Future<Set<String>> seenStories() async =>
      (await _c.from('story_views').select('story_id').eq('user_id', uid!)).map<String>((r) => r['story_id'] as String).toSet();

  static Future<void> markStorySeen(String id) async =>
      _c.from('story_views').upsert({'story_id': id, 'user_id': uid});

  static Future<Story> addStory(String mediaUrl, String caption, {String? placeId}) async {
    final r = await _c.from('stories').insert({'user_id': uid, 'media_url': mediaUrl, 'caption': caption, 'place_id': placeId}).select().single();
    return Story.fromRow(r);
  }

  // ---- messaging ----
  static Future<List<Conversation>> conversations() async {
    final mine = await _c.from('conversation_members').select('conversation_id, last_read_at').eq('user_id', uid!);
    if (mine.isEmpty) return [];
    final ids = mine.map((r) => r['conversation_id'] as String).toList();
    final lastRead = {for (final r in mine) r['conversation_id'] as String: DateTime.parse(r['last_read_at'] as String)};
    final convs = await _c.from('conversations').select('id, title, is_group, conversation_members(user_id)').inFilter('id', ids);
    final msgs = await _c.from('messages').select().inFilter('conversation_id', ids).order('created_at').limit(1000);
    final out = <Conversation>[];
    for (final c in convs) {
      final id = c['id'] as String;
      final members = (c['conversation_members'] as List).map((m) => m['user_id'] as String).where((u) => u != uid).toList();
      final list = msgs.where((m) => m['conversation_id'] == id).toList();
      final title = (c['title'] as String?) ?? (members.isEmpty ? 'Just you' : members.map((u) => travelerById(u).name).join(', '));
      out.add(Conversation(
        id: id,
        title: title,
        memberIds: members,
        isGroup: c['is_group'] as bool? ?? false,
        messages: [for (final m in list) messageFromRow(m)],
        unread: list.where((m) => m['sender_id'] != uid && DateTime.parse(m['created_at'] as String).isAfter(lastRead[id]!)).length,
      ));
    }
    DateTime lastAt(Conversation c) => c.messages.isEmpty ? DateTime(2000) : (c.messages.last.at ?? DateTime(2000));
    out.sort((a, b) => lastAt(b).compareTo(lastAt(a)));
    return out;
  }

  static Message messageFromRow(Map<String, dynamic> m) {
    final t = DateTime.parse(m['created_at'] as String).toLocal();
    return Message(m['sender_id'] == uid ? meId : m['sender_id'] as String, m['body'] as String, clock(t), at: t, id: m['id']?.toString());
  }

  static Future<String> dmWith(String other) async => await _c.rpc('dm_with', params: {'other': other}) as String;

  /// Sends a message and returns its id.
  static Future<String> sendMessage(String conversationId, String body) async {
    final r = await _c.from('messages').insert({'conversation_id': conversationId, 'sender_id': uid, 'body': body}).select('id').single();
    return r['id'].toString();
  }

  static Future<void> deleteMessage(String id) async {
    await _c.from('messages').delete().eq('id', int.parse(id));
  }

  static Future<void> deleteStory(String id) async {
    await _c.from('stories').delete().eq('id', id);
  }

  static Future<void> markConversationRead(String conversationId) async => _c
      .from('conversation_members')
      .update({'last_read_at': DateTime.now().toUtc().toIso8601String()})
      .eq('conversation_id', conversationId)
      .eq('user_id', uid!);

  static RealtimeChannel onNewMessage(void Function(Map<String, dynamic> row) cb) => _c
      .channel('messages-$uid')
      .onPostgresChanges(event: PostgresChangeEvent.insert, schema: 'public', table: 'messages', callback: (p) => cb(p.newRecord))
      .subscribe();

  // ---- groups ----
  static Future<List<TravelGroup>> groups() async {
    final rows = await _c.from('groups_view').select().order('created_at');
    return rows.map<TravelGroup>((r) => TravelGroup.fromRow(r)).toList();
  }

  static Future<List<Map<String, dynamic>>> myMemberships() async =>
      List<Map<String, dynamic>>.from(await _c.from('group_members').select('group_id, status').eq('user_id', uid!));

  static Future<void> joinGroup(String id, {bool pending = false}) async =>
      _c.from('group_members').insert({'group_id': id, 'user_id': uid, 'status': pending ? 'pending' : 'active'});
  static Future<void> leaveGroup(String id) async => _c.from('group_members').delete().eq('group_id', id).eq('user_id', uid!);

  static Future<List<Post>> groupPosts(String groupId) async {
    final rows = await _c.from('posts_feed').select().eq('group_id', groupId).order('created_at', ascending: false).limit(60);
    return rows.map<Post>((r) => Post.fromRow(r)).toList();
  }

  static Future<TravelGroup> createGroup(String name, String about, bool private) async {
    final r = await _c.from('groups').insert({'name': name, 'about': about, 'private': private, 'owner_id': uid}).select().single();
    return TravelGroup.fromRow({...r, 'member_count': 1});
  }

  static Future<void> createGroupPost(String groupId, String caption, String mediaUrl) async =>
      _c.from('posts').insert({'caption': caption, 'media_url': mediaUrl, 'group_id': groupId});

  // ---- trips ----
  static Future<List<TripPlan>> trips() async {
    final rows = await _c.from('trips').select('*, trip_members(user_id), trip_stops(*)').order('start_date');
    return rows.map<TripPlan>((r) {
      final days = (r['days'] as num).toInt();
      final stops = List<Map<String, dynamic>>.from(r['trip_stops'] as List? ?? const []);
      stops.sort((a, b) => (a['created_at'] as String).compareTo(b['created_at'] as String));
      return TripPlan(
        id: r['id'] as String,
        title: r['title'] as String,
        placeId: r['place_id'] as String? ?? '',
        start: DateTime.parse(r['start_date'] as String),
        budget: (r['budget'] as num?)?.toDouble() ?? 0,
        public: r['public'] as bool? ?? true,
        buddies: [
          for (final m in (r['trip_members'] as List? ?? const []))
            if (m['user_id'] != r['owner_id']) m['user_id'] as String
        ],
        days: [
          for (var d = 0; d < days; d++)
            TripDay([
              for (final s in stops.where((s) => s['day'] == d))
                TripStop(s['at_time'] as String? ?? '', s['title'] as String, s['note'] as String? ?? '', s['kind'] as String? ?? 'sight', id: s['id'] as String)
            ])
        ],
      );
    }).toList();
  }

  static Future<String> createTrip(String title, String placeId, DateTime start, int days, double budget) async {
    final r = await _c
        .from('trips')
        .insert({'owner_id': uid, 'title': title, 'place_id': placeId, 'start_date': _date(start), 'days': days, 'budget': budget})
        .select('id')
        .single();
    return r['id'] as String;
  }

  static Future<void> updateTrip(String id, Map<String, dynamic> fields) async => _c.from('trips').update(fields).eq('id', id);
  static Future<void> deleteTrip(String id) async => _c.from('trips').delete().eq('id', id);
  static Future<void> inviteToTrip(String tripId, String userId) async =>
      _c.from('trip_members').insert({'trip_id': tripId, 'user_id': userId});

  static Future<String> addStop(String tripId, int day, TripStop s) async {
    final r = await _c
        .from('trip_stops')
        .insert({'trip_id': tripId, 'day': day, 'at_time': s.time, 'title': s.title, 'note': s.note, 'kind': s.kind, 'created_by': uid})
        .select('id')
        .single();
    return r['id'] as String;
  }

  static Future<void> removeStop(String id) async => _c.from('trip_stops').delete().eq('id', id);
}
