import 'offline.dart';
import '../core/i18n.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:math';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/env.dart';
import 'models.dart';
import 'social.dart';

/// Turns any error into a message a traveler can read.
String errText(Object e) {
  if (e is AuthException) return e.message;
  if (e is PostgrestException) return e.message;
  if (e is StorageException) return e.message;
  if (!Offline.online.value) return tr('You are offline. This needs internet, try again when you are connected.');
  return tr('Something went wrong. Check your connection and try again.');
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
      Offline.row('profile', () => _c.from('profiles_view').select().eq('id', uid!).maybeSingle());

  static Future<void> updateName(String name) async {
    await _c.from('profiles').update({'name': name}).eq('id', uid!);
  }

  static Future<void> updateProfile(Map<String, dynamic> fields) async {
    await _c.from('profiles').update(fields).eq('id', uid!);
  }

  // ---------- catalog ----------
  static Future<List<Place>> places() async {
    const cols = 'id,name,location,country,category,hub,rating,reviews,price,season,last_mode,last_detail,last_duration,facilities,'
        'address,lat,lng,hours,maps_url,image_url,wiki_title,video_url,continent,budget_low,budget_high,popularity';
    final all = await Offline.rows('places', () async {
      final acc = <Map<String, dynamic>>[];
      // The API returns at most 1000 rows per request, so page through the catalog.
      for (var from = 0; from < 5000; from += 1000) {
        final rows = await _c
            .from('places')
            .select(cols)
            .order('popularity', ascending: false, nullsFirst: true)
            .order('id')
            .range(from, from + 999);
        acc.addAll(rows);
        if (rows.length < 1000) break;
      }
      return acc;
    });
    return all.map<Place>((r) => Place.fromRow(r)).toList();
  }

  static Future<String?> placeAbout(String id) async {
    final r = await Offline.row('about:$id', () => _c.from('places').select('about').eq('id', id).maybeSingle());
    return r?['about'] as String?;
  }

  static Future<List<Guide>> guides() async {
    final rows = await Offline.rows('guides', () => _c.from('guides').select().eq('status', 'approved').order('rating', ascending: false).order('created_at'));
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
    final rows = await Offline.rows('posts', () => _c.from('posts_feed').select().isFilter('group_id', null).order('created_at', ascending: false).limit(60));
    return rows.map<Post>((r) => Post.fromRow(r)).toList();
  }

  static Future<Set<String>> _ids(String table, String column) async {
    final rows = await Offline.rows('ids:$table', () => _c.from(table).select(column).eq(table == 'follows' ? 'follower_id' : 'user_id', uid!));
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

  /// Everyone who reacted to a post, newest first: (user id, name, avatar, emoji).
  static Future<List<(String, String, String, String)>> postReactions(String postId) async {
    final rows = await _c
        .from('likes')
        .select('user_id, emoji, created_at, who:profiles!likes_user_id_fkey(name, avatar_url)')
        .eq('post_id', postId)
        .order('created_at', ascending: false)
        .limit(500);
    return [
      for (final r in rows)
        (
          r['user_id'] as String,
          ((r['who'] as Map?)?['name'] as String?) ?? 'Traveler',
          ((r['who'] as Map?)?['avatar_url'] as String?) ?? '',
          (r['emoji'] as String?) ?? '❤️',
        )
    ];
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
    final rows = await Offline.rows('bookings', () => _c.from('bookings').select().order('created_at', ascending: false));
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
    final rows = await Offline.rows('notifications', () => _c.from('notifications').select('*, actor:profiles!notifications_actor_id_fkey(name, avatar_url)').order('created_at', ascending: false).limit(50));
    return rows.map<AppNotification>((r) => AppNotification.fromRow(r)).toList();
  }

  static Future<void> markRead(String id) async {
    await _c.from('notifications').update({'read': true}).eq('id', id);
  }

  static Future<void> markAllRead() async {
    await _c.from('notifications').update({'read': true}).eq('user_id', uid!).eq('read', false);
  }

  // ================= social =================

  static Future<Traveler?> fetchTraveler(String id) async {
    final r = await _c.from('profiles_view').select().eq('id', id).maybeSingle();
    return r == null ? null : Traveler.fromRow(r);
  }

  static Future<Post?> postById(String id) async {
    final r = await _c.from('posts_feed').select().eq('id', id).maybeSingle();
    return r == null ? null : Post.fromRow(r);
  }

  static Future<List<Traveler>> travelers() async {
    final rows = await Offline.rows('travelers', () => _c.from('profiles_view').select().order('created_at', ascending: false).limit(300));
    return rows.map<Traveler>((r) => Traveler.fromRow(r)).toList();
  }

  // ---- buddies ----
  static Future<List<Map<String, dynamic>>> buddyRows() async =>
      Offline.rows('buddies', () async => List<Map<String, dynamic>>.from(await _c.from('buddy_requests').select().or('from_id.eq.$uid,to_id.eq.$uid')));

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

  /// Who viewed one of my stories (newest first). Only the story owner can read these.
  static Future<List<(String, String, String, DateTime)>> storyViewers(String storyId) async {
    final rows = await _c
        .from('story_views')
        .select('user_id, seen_at, viewer:profiles!story_views_user_id_fkey(name, avatar_url)')
        .eq('story_id', storyId)
        .neq('user_id', uid!)
        .order('seen_at', ascending: false);
    return [
      for (final r in rows)
        (
          r['user_id'] as String,
          ((r['viewer'] as Map?)?['name'] as String?) ?? 'Traveler',
          ((r['viewer'] as Map?)?['avatar_url'] as String?) ?? '',
          DateTime.parse(r['seen_at'] as String).toLocal(),
        )
    ];
  }

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
    final rows = await Offline.rows('trips', () => _c.from('trips').select('*, trip_members(user_id), trip_stops(*)').order('start_date'));
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
        discoverable: r['discoverable'] as bool? ?? true,
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

  /// Travelers going to [placeId] with dates that overlap [from]..[to]. Blocked users are left out.
  static Future<List<SameTimeMatch>> sameTimeTravelers(String placeId, DateTime from, DateTime to) async {
    String d(DateTime x) => x.toIso8601String().substring(0, 10);
    final rows = await Offline.rows('same:$placeId:${d(from)}:${d(to)}',
        () async => List<Map<String, dynamic>>.from(await _c.rpc('same_time_travelers', params: {'p_place': placeId, 'p_from': d(from), 'p_to': d(to)}) as List));
    return rows.map(SameTimeMatch.fromRow).toList();
  }

  /// Travel passport stats for a traveler (null = you); [year] null = all time.
  static Future<Map<String, dynamic>> passport(String? userId, int? year) async {
    final r = await Offline.row('passport:${userId ?? 'me'}:${year ?? 'all'}',
        () async => Map<String, dynamic>.from(await _c.rpc('travel_passport', params: {'p_user': userId, 'p_year': year}) as Map));
    return r ?? {};
  }

  /// Festivals from today for the next [months] months, soonest first.
  static Future<List<Map<String, dynamic>>> festivals({String? country, int months = 12}) {
    String d(DateTime x) => x.toIso8601String().substring(0, 10);
    final now = DateTime.now();
    final from = d(now), to = d(DateTime(now.year, now.month + months, now.day));
    return Offline.rows('festivals:${country ?? 'all'}:$months', () async {
      var q = _c.from('festivals').select().gte('ends', from).lte('starts', to);
      if (country != null) q = q.eq('country', country);
      return List<Map<String, dynamic>>.from(await q.order('starts'));
    });
  }

  /// AI trip planner (Edge Function `ai-planner`). Returns {plan, remaining} or throws [PlannerError].
  static Future<Map<String, dynamic>> aiPlan({required String destination, required int days, required double budget, required String currency, String style = ''}) async {
    try {
      final res = await _c.functions.invoke('ai-planner', body: {
        'destination': destination,
        'days': days,
        'budget': budget,
        'currency': currency,
        'style': style,
        'lang': isBangla ? 'bn' : 'en',
      });
      return Map<String, dynamic>.from(res.data as Map);
    } on FunctionException catch (e) {
      final d = e.details;
      final code = d is Map ? (d['error'] ?? '').toString() : '';
      final msg = d is Map ? (d['message'] ?? '').toString() : '';
      throw PlannerError(code.isEmpty ? 'server' : code, msg.isEmpty ? 'The planner is busy. Please try again.' : msg);
    }
  }

  // ---- live location & SOS ----
  static Future<void> shareLocation(double lat, double lng, double? accuracy, DateTime until) async => _c.from('live_locations').upsert({
        'user_id': uid,
        'lat': lat,
        'lng': lng,
        'accuracy': accuracy,
        'sharing_until': until.toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

  static Future<void> stopSharingLocation() async =>
      _c.from('live_locations').update({'sharing_until': DateTime.now().toUtc().toIso8601String()}).eq('user_id', uid!);

  /// Your own row plus every buddy who is sharing right now (Row Level Security limits it to buddies).
  static Future<List<Map<String, dynamic>>> liveLocations() async => List<Map<String, dynamic>>.from(await _c
      .from('live_locations')
      .select('user_id, lat, lng, accuracy, sharing_until, updated_at, who:profiles(name, avatar_url)')
      .gt('sharing_until', DateTime.now().toUtc().toIso8601String()));

  static Future<String> sendSos(double? lat, double? lng, String message) async =>
      (await _c.rpc('send_sos', params: {'p_lat': lat, 'p_lng': lng, 'p_message': message})) as String;

  static Future<void> resolveSos() async => _c.rpc('resolve_sos');

  static Future<Map<String, dynamic>?> sosAlert(String id) async => _c.from('sos_alerts').select().eq('id', id).maybeSingle();

  /// Nearest city, its country and the local emergency numbers.
  static Future<Map<String, dynamic>?> emergencyAt(double lat, double lng) async {
    final r = await _c.rpc('emergency_at', params: {'p_lat': lat, 'p_lng': lng}) as List;
    return r.isEmpty ? null : Map<String, dynamic>.from(r.first as Map);
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

  // ---- trip tools: shared expenses and packing list ----
  static Future<List<Map<String, dynamic>>> tripExpenses(String tripId) async =>
      List<Map<String, dynamic>>.from(await _c.from('trip_expenses').select().eq('trip_id', tripId).order('created_at', ascending: false));

  static Future<void> addTripExpense(String tripId, String title, double amount, String paidBy, List<String> splitWith) async {
    await _c.from('trip_expenses').insert({'trip_id': tripId, 'title': title, 'amount': amount, 'paid_by': paidBy, 'split_with': splitWith});
  }

  static Future<void> deleteTripExpense(String id) async => _c.from('trip_expenses').delete().eq('id', id);

  static Future<List<Map<String, dynamic>>> tripItems(String tripId) async =>
      List<Map<String, dynamic>>.from(await _c.from('trip_items').select().eq('trip_id', tripId).order('created_at'));

  static Future<void> addTripItems(String tripId, List<(String, String)> items) async {
    await _c.from('trip_items').insert([for (final i in items) {'trip_id': tripId, 'title': i.$1, 'category': i.$2}]);
  }

  static Future<void> setTripItemDone(String id, bool done) async => _c.from('trip_items').update({'done': done}).eq('id', id);

  static Future<void> deleteTripItem(String id) async => _c.from('trip_items').delete().eq('id', id);

  // ---- country essentials ----
  static Future<Map<String, dynamic>?> countryInfo(String country) async =>
      await _c.from('country_info').select().eq('country', country).maybeSingle();

  // ---------- real travel services ----------
  /// Places to stay near a destination, from OpenStreetMap (fetched and cached by the `stays` edge function).
  static Future<List<Stay>> stays(Place place) async {
    final placeId = place.id;
    final cached = await _c.from('stays').select().eq('place_id', placeId).order('distance_km').limit(120);
    final fetched = await _c.from('stays_fetch').select('fetched_at').eq('place_id', placeId).maybeSingle();
    if (cached.isNotEmpty || fetched != null) return cached.map<Stay>((r) => Stay.fromRow(r)).toList();
    if (place.lat == null || place.lng == null) return const [];
    // OpenStreetMap services allow app traffic from the traveler's own device, not from cloud servers.
    final rows = await osmStays(place.lat!, place.lng!);
    if (rows == null) throw Exception('map service busy');
    if (uid != null) {
      try {
        await _c.rpc('cache_stays', params: {'p_place': placeId, 'p_rows': rows});
      } catch (_) {}
    }
    final out = rows.map((r) => Stay.fromRow({...r, 'id': '$placeId:${r['id']}'})).toList()
      ..sort((a, b) => (a.distanceKm ?? 99).compareTo(b.distanceKm ?? 99));
    return out;
  }

  static double _km(double a, double b, double c, double d) {
    const r = pi / 180;
    final x = pow(sin((c - a) * r / 2), 2) + cos(a * r) * cos(c * r) * pow(sin((d - b) * r / 2), 2);
    return 12742 * asin(sqrt(x));
  }

  static Map<String, dynamic> _stayRow(String id, Map t, double lat, double lng, double plat, double plng, {String? kind, String? name, String? addr}) {
    final stars = double.tryParse('${t['stars'] ?? ''}');
    final a = addr ?? [t['addr:housenumber'], t['addr:street'], t['addr:city'] ?? t['addr:district']].where((e) => e != null).join(', ');
    return {
      'id': id,
      'name': name ?? t['name:en'] ?? t['name'],
      'kind': kind ?? t['tourism'] ?? 'hotel',
      'stars': stars != null && stars > 0 && stars <= 7 ? stars : null,
      'lat': lat,
      'lng': lng,
      'address': a.isEmpty ? null : a,
      'phone': t['phone'] ?? t['contact:phone'],
      'website': t['website'] ?? t['contact:website'],
      'email': t['email'] ?? t['contact:email'],
      'distance_km': (_km(plat, plng, lat, lng) * 10).round() / 10,
    };
  }

  /// Hotels, hostels and guest houses around a point from OpenStreetMap. Null when every service failed.
  static Future<List<Map<String, dynamic>>?> osmStays(double lat, double lng) async {
    const kinds = {'hotel', 'hostel', 'guest_house', 'motel', 'resort', 'apartment', 'chalet', 'camp_site'};
    final q = '[out:json][timeout:20];nwr(around:8000,$lat,$lng)["tourism"~"^(hotel|hostel|guest_house|motel|resort|apartment|chalet|camp_site)\$"]["name"];out center tags 120;';
    for (final m in ['https://overpass-api.de/api/interpreter', 'https://overpass.private.coffee/api/interpreter']) {
      try {
        final r = await http.post(Uri.parse(m), body: {'data': q}).timeout(const Duration(seconds: 25));
        if (r.statusCode != 200) continue;
        final els = (jsonDecode(r.body) as Map)['elements'] as List;
        final out = <Map<String, dynamic>>[];
        for (final e in els) {
          final t = (e['tags'] as Map?) ?? const {};
          final la = (e['lat'] ?? e['center']?['lat']) as num?, lo = (e['lon'] ?? e['center']?['lon']) as num?;
          if (la == null || lo == null || t['name'] == null) continue;
          out.add(_stayRow('${(e['type'] as String)[0]}${e['id']}', t, la.toDouble(), lo.toDouble(), lat, lng));
        }
        if (out.length >= 5) return out;
        if (out.isNotEmpty) return [...out, ...?await _nominatimStays(lat, lng, kinds, skip: out.map((e) => e['id']).toSet())];
        break;
      } catch (_) {}
    }
    return _nominatimStays(lat, lng, kinds);
  }

  static Future<List<Map<String, dynamic>>?> _nominatimStays(double lat, double lng, Set<String> kinds, {Set<Object?> skip = const {}}) async {
    final out = <String, Map<String, dynamic>>{};
    var ok = false;
    for (final span in [0.07, 0.25]) {
      for (final q in ['hotel', 'hostel', 'guest house', 'resort']) {
        try {
          final u = Uri.https('nominatim.openstreetmap.org', '/search', {
            'q': q, 'format': 'jsonv2', 'viewbox': '${lng - span},${lat + span},${lng + span},${lat - span}', 'bounded': '1', 'limit': '40',
            'extratags': '1', 'namedetails': '1', 'addressdetails': '1', 'accept-language': 'en',
          });
          final r = await http.get(u).timeout(const Duration(seconds: 15));
          if (r.statusCode == 200) {
            ok = true;
            for (final e in jsonDecode(r.body) as List) {
              if (e['category'] != 'tourism' || !kinds.contains(e['type'])) continue;
              final nd = (e['namedetails'] as Map?) ?? const {};
              final name = nd['name:en'] ?? nd['name'] ?? e['name'];
              final id = '${(e['osm_type'] as String)[0]}${e['osm_id']}';
              if (name == null || '$name'.isEmpty || skip.contains(id)) continue;
              final a = (e['address'] as Map?) ?? const {};
              final addr = [a['house_number'], a['road'], a['suburb'] ?? a['neighbourhood'], a['city'] ?? a['town'] ?? a['village']].where((x) => x != null).join(', ');
              out[id] = _stayRow(id, (e['extratags'] as Map?) ?? const {}, double.parse('${e['lat']}'), double.parse('${e['lon']}'), lat, lng,
                  kind: e['type'] as String, name: '$name', addr: addr);
            }
          }
        } catch (_) {}
        await Future.delayed(const Duration(milliseconds: 1100));
      }
      if (out.length >= 8) break;
    }
    return ok ? out.values.toList() : null;
  }

  static Future<List<Airport>> airports(String q) async {
    final t = q.trim().replaceAll(RegExp(r'[,()%]'), ' ').trim();
    if (t.isEmpty) return const [];
    final rows = t.length == 3
        ? await _c.from('airports').select().or('iata.eq.${t.toUpperCase()},city.ilike.$t%,name.ilike.%$t%').order('kind').limit(20)
        : await _c.from('airports').select().or('city.ilike.$t%,name.ilike.%$t%,country.ilike.$t').order('kind').limit(20);
    final out = rows.map<Airport>((r) => Airport.fromRow(r)).toList();
    out.sort((a, b) => (a.iata == t.toUpperCase() ? 0 : 1).compareTo(b.iata == t.toUpperCase() ? 0 : 1));
    return out;
  }

  static Future<Airport?> airport(String iata) async {
    final r = await _c.from('airports').select().eq('iata', iata).maybeSingle();
    return r == null ? null : Airport.fromRow(r);
  }

  static Future<List<Train>> trains() async {
    final rows = await _c.from('trains').select().order('number');
    return rows.map<Train>((r) => Train.fromRow(r)).toList();
  }

  static Future<List<BusOperator>> busOperators() async {
    final rows = await _c.from('bus_operators').select().order('name');
    return rows.map<BusOperator>((r) => BusOperator.fromRow(r)).toList();
  }

  // ---------- guide applications ----------
  static Future<bool> isAdmin() async {
    if (uid == null) return false;
    final r = await _c.from('app_admins').select('user_id').eq('user_id', uid!).maybeSingle();
    return r != null;
  }

  static Future<GuideApplication?> myGuideApplication() async {
    if (uid == null) return null;
    final r = await _c.from('guide_applications').select().eq('user_id', uid!).order('created_at', ascending: false).limit(1).maybeSingle();
    return r == null ? null : GuideApplication.fromRow(r);
  }

  /// Uploads an identity document to the private `guide-docs` bucket and returns its storage path.
  static Future<String> uploadPrivateDoc(Uint8List bytes, String ext, String mime) async {
    final path = '$uid/${DateTime.now().microsecondsSinceEpoch}.$ext';
    await _c.storage.from('guide-docs').uploadBinary(path, bytes, fileOptions: FileOptions(contentType: mime));
    return path;
  }

  static Future<String> signedDocUrl(String path) => _c.storage.from('guide-docs').createSignedUrl(path, 3600);

  static Future<void> applyGuide(Map<String, dynamic> row) async {
    await _c.from('guide_applications').insert({...row, 'user_id': uid, 'agreed_at': DateTime.now().toUtc().toIso8601String()});
  }

  static Future<List<GuideApplication>> guideApplications({String status = 'pending'}) async {
    final rows = await _c.from('guide_applications').select().eq('status', status).order('created_at');
    return rows.map<GuideApplication>((r) => GuideApplication.fromRow(r)).toList();
  }

  static Future<void> reviewGuide(String id, bool approve, String? note) async {
    await _c.rpc('review_guide_application', params: {'app_id': id, 'approve': approve, 'note': note});
  }

  static Future<Guide?> myGuide() async {
    if (uid == null) return null;
    final r = await _c.from('guides').select().eq('user_id', uid!).neq('status', 'left').maybeSingle();
    return r == null ? null : Guide.fromRow(r);
  }

  /// Unverified guides can go back to being a traveler. Verified guides cannot.
  static Future<void> leaveGuide() => _c.rpc('leave_guide');

  /// Basic guide signup / edit. Verification is separate (documents + admin approval).
  static Future<void> saveGuide(Map<String, dynamic> row) async {
    final me = await _c.from('profiles').select('avatar_url').eq('id', uid!).maybeSingle();
    await _c.from('guides').upsert({...row, 'id': 'g-$uid', 'user_id': uid, 'status': 'approved', 'avatar_url': me?['avatar_url']});
  }
}

class PlannerError implements Exception {
  final String code, message;
  PlannerError(this.code, this.message);
  @override
  String toString() => message;
}
