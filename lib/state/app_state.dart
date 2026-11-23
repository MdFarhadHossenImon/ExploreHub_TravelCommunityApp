import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../core/env.dart';
import '../data/backend.dart';
import '../data/mock_data.dart';
import '../data/models.dart';

/// Single source of truth for the UI.
/// - With Supabase keys: every action is saved to the backend (optimistic UI, rolled back on error).
/// - Without keys: runs fully offline on the bundled demo data.
class AppState extends ChangeNotifier {
  bool loggedIn = false;
  String name = Backend.on ? '' : 'Emmie Watson';
  String email = Backend.on ? '' : 'emmie1709@gmail.com';
  String? username;
  String? avatarUrl;
  // traveler profile (live: from the profiles table)
  String bio = Backend.on ? '' : 'Exploring one place at a time. Mountains over beaches (most days).';
  String home = Backend.on ? '' : 'Dhaka, Bangladesh';
  String? coverUrl;
  List<String> countries = Backend.on ? [] : ['Bangladesh', 'Nepal', 'Thailand', 'Indonesia'];
  int followers = Backend.on ? 0 : 1240, followingCount = Backend.on ? 0 : 310, tripCount = Backend.on ? 0 : 9;
  String language = 'English (US)';
  bool push = true;
  bool promo = false;

  final Set<String> likedPosts = {};
  final Set<String> savedPosts = {};
  final Set<String> savedPlaces = {};
  final Set<String> following = {};

  final List<Post> posts = Backend.on ? <Post>[] : seedPosts();
  final List<Booking> bookings = Backend.on ? <Booking>[] : seedBookings();
  final List<AppNotification> notifications = Backend.on ? <AppNotification>[] : seedNotifications();

  String get avatarSeed => Backend.on ? (avatarUrl ?? '') : 'me';
  int get unread => notifications.where((n) => !n.read).length;
  List<Post> get myPosts =>
      posts.where((p) => Backend.on ? p.userId == Backend.uid : p.userName == name).toList();

  // ---------- session ----------
  /// Called once at startup: loads the public catalog, then the user's data if a session exists.
  Future<void> bootstrap() async {
    if (!Backend.on) return;
    try {
      final pl = await Backend.places();
      if (pl.isNotEmpty) places..clear()..addAll(pl);
      final gd = await Backend.guides();
      if (gd.isNotEmpty) guides..clear()..addAll(gd);
    } catch (e) {
      say(errText(e));
    }
    if (Backend.user != null) await onSignedIn();
    notifyListeners();
  }

  /// Demo mode only.
  void login(String mail) {
    loggedIn = true;
    email = mail;
    notifyListeners();
  }

  Future<void> onSignedIn() async {
    if (!Backend.on) return;
    final u = Backend.user;
    if (u == null) return;
    loggedIn = true;
    email = u.email ?? '';
    try {
      final p = await Backend.profile();
      final n = (p?['name'] as String?)?.trim() ?? '';
      name = n.isNotEmpty ? n : email.split('@').first;
      username = p?['username'] as String?;
      avatarUrl = p?['avatar_url'] as String?;
      bio = p?['bio'] as String? ?? '';
      home = p?['home'] as String? ?? '';
      coverUrl = p?['cover_url'] as String?;
      countries = List<String>.from(p?['countries'] as List? ?? const []);
      followers = (p?['followers'] as num?)?.toInt() ?? 0;
      followingCount = (p?['following'] as num?)?.toInt() ?? 0;
      tripCount = (p?['trips'] as num?)?.toInt() ?? 0;
    } catch (_) {
      name = email.split('@').first;
    }
    Backend.onNotification(refreshNotifications);
    await refreshAll();
  }

  Future<void> refreshAll() async {
    if (!Backend.on || Backend.user == null) return;
    try {
      posts..clear()..addAll(await Backend.posts());
      bookings..clear()..addAll(await Backend.bookings());
      notifications..clear()..addAll(await Backend.notifications());
      likedPosts..clear()..addAll(await Backend.myLikes());
      savedPosts..clear()..addAll(await Backend.mySavedPosts());
      savedPlaces..clear()..addAll(await Backend.mySavedPlaces());
      following..clear()..addAll(await Backend.myFollowing());
    } catch (e) {
      say(errText(e));
    }
    notifyListeners();
  }

  Future<void> logout() async {
    if (Backend.on) await Backend.signOut();
    markLoggedOut();
  }

  void markLoggedOut() {
    loggedIn = false;
    if (Backend.on) {
      Backend.stopNotifications();
      posts.clear();
      bookings.clear();
      notifications.clear();
      name = '';
      email = '';
    }
    likedPosts.clear();
    savedPosts.clear();
    savedPlaces.clear();
    following.clear();
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    try {
      if (Backend.on) await Backend.deleteAccount();
      await logout();
    } catch (e) {
      say(errText(e));
    }
  }

  // ---------- settings ----------
  Future<void> updateName(String v) async {
    final old = name;
    name = v;
    notifyListeners();
    if (!Backend.on) return;
    try {
      await Backend.updateName(v);
    } catch (e) {
      name = old;
      notifyListeners();
      say(errText(e));
    }
  }

  /// Saves the traveler profile. New avatar / cover photos are uploaded first.
  Future<bool> saveProfile({
    required String name,
    required String username,
    required String bio,
    required String home,
    required List<String> countries,
    Uint8List? avatar,
    Uint8List? cover,
  }) async {
    try {
      String? newAvatar, newCover;
      if (Backend.on && avatar != null) newAvatar = await Backend.upload(avatar, 'jpg', 'image/jpeg', bucket: 'avatars');
      if (Backend.on && cover != null) newCover = await Backend.upload(cover, 'jpg', 'image/jpeg', bucket: 'avatars');
      if (Backend.on) {
        await Backend.updateProfile({
          'name': name,
          'username': username.isEmpty ? null : username,
          'bio': bio,
          'home': home,
          'countries': countries,
          if (newAvatar != null) 'avatar_url': newAvatar,
          if (newCover != null) 'cover_url': newCover,
        });
      }
      this.name = name;
      this.username = username.isEmpty ? null : username;
      this.bio = bio;
      this.home = home;
      this.countries = countries;
      if (newAvatar != null) avatarUrl = newAvatar;
      if (newCover != null) coverUrl = newCover;
      notifyListeners();
      return true;
    } catch (e) {
      say(errText(e));
      return false;
    }
  }

  void setPush(bool v) {
    push = v;
    notifyListeners();
  }

  void setPromo(bool v) {
    promo = v;
    notifyListeners();
  }

  void setLanguage(String v) {
    language = v;
    notifyListeners();
  }

  // ---------- community ----------
  Future<void> toggleLike(Post p) async {
    final on = !likedPosts.contains(p.id);
    on ? likedPosts.add(p.id) : likedPosts.remove(p.id);
    p.likes += on ? 1 : -1;
    notifyListeners();
    if (!Backend.on) return;
    try {
      await Backend.setLike(p.id, on);
    } catch (e) {
      on ? likedPosts.remove(p.id) : likedPosts.add(p.id);
      p.likes += on ? -1 : 1;
      notifyListeners();
      say(errText(e));
    }
  }

  Future<void> toggleSavePost(Post p) async {
    final on = !savedPosts.contains(p.id);
    on ? savedPosts.add(p.id) : savedPosts.remove(p.id);
    notifyListeners();
    if (!Backend.on) return;
    try {
      await Backend.setSavedPost(p.id, on);
    } catch (e) {
      on ? savedPosts.remove(p.id) : savedPosts.add(p.id);
      notifyListeners();
      say(errText(e));
    }
  }

  Future<void> toggleSavePlace(String id) async {
    final on = !savedPlaces.contains(id);
    on ? savedPlaces.add(id) : savedPlaces.remove(id);
    notifyListeners();
    if (!Backend.on) return;
    try {
      await Backend.setSavedPlace(id, on);
    } catch (e) {
      on ? savedPlaces.remove(id) : savedPlaces.add(id);
      notifyListeners();
      say(errText(e));
    }
  }

  /// [key] is the author's user id (backend) or name (demo).
  Future<void> toggleFollow(String key) async {
    final on = !following.contains(key);
    on ? following.add(key) : following.remove(key);
    notifyListeners();
    if (!Backend.on) return;
    try {
      await Backend.setFollow(key, on);
    } catch (e) {
      on ? following.remove(key) : following.add(key);
      notifyListeners();
      say(errText(e));
    }
  }

  Future<void> loadComments(Post p) async {
    if (!Backend.on) return;
    try {
      final list = await Backend.comments(p.id);
      p.comments
        ..clear()
        ..addAll(list);
      p.commentCount = list.length;
      notifyListeners();
    } catch (e) {
      say(errText(e));
    }
  }

  Future<void> addComment(Post p, String text) async {
    final c = Comment(name.split(' ').first, text);
    p.comments.add(c);
    p.commentCount++;
    notifyListeners();
    if (!Backend.on) return;
    try {
      await Backend.addComment(p.id, text);
    } catch (e) {
      p.comments.remove(c);
      p.commentCount--;
      notifyListeners();
      say(errText(e));
    }
  }

  /// Demo-mode posting (sample gallery).
  void addPost({
    required String imageSeed,
    required String caption,
    String? placeId,
    bool isVideo = false,
  }) {
    posts.insert(
      0,
      Post(
        id: 'p${DateTime.now().millisecondsSinceEpoch}',
        userName: name,
        userSeed: 'me',
        imageSeed: imageSeed,
        caption: caption,
        placeId: placeId,
        isVideo: isVideo,
        videoTitle: isVideo ? caption.split('.').first : null,
        time: 'now',
      ),
    );
    notifyListeners();
  }

  /// Real posting: upload the photo or video (if any) to Storage, then insert the post row.
  /// A post with no media is a text post. Returns true on success.
  Future<bool> publishPost({
    Uint8List? bytes,
    String ext = 'jpg',
    String mime = 'image/jpeg',
    required String caption,
    String? placeId,
    bool isVideo = false,
  }) async {
    try {
      final url = bytes == null ? '' : await Backend.upload(bytes, ext, mime);
      await Backend.createPost(caption: caption, mediaUrl: url, placeId: placeId, isVideo: bytes != null && isVideo);
      posts..clear()..addAll(await Backend.posts());
      notifyListeners();
      return true;
    } catch (e) {
      say(errText(e));
      return false;
    }
  }

  /// Re-share someone's post to your own feed with an optional note.
  Future<bool> sharePost(Post p, String note) async {
    final original = p.shared ?? p;
    if (!Backend.on) {
      posts.insert(0, Post(id: 'p${DateTime.now().millisecondsSinceEpoch}', userName: name, userSeed: 'me', imageSeed: '', caption: note.isEmpty ? 'Shared a post' : note, time: 'now', shared: original));
      notifyListeners();
      return true;
    }
    try {
      await Backend.createPost(caption: note.isEmpty ? 'Shared a post' : note, sharedPostId: original.id);
      posts..clear()..addAll(await Backend.posts());
      notifyListeners();
      return true;
    } catch (e) {
      say(errText(e));
      return false;
    }
  }

  Future<bool> editPost(Post p, String caption) async {
    final before = p.caption;
    p.caption = caption;
    p.edited = true;
    notifyListeners();
    if (!Backend.on) return true;
    try {
      await Backend.editPost(p.id, caption);
      return true;
    } catch (e) {
      p.caption = before;
      notifyListeners();
      say(errText(e));
      return false;
    }
  }

  /// Reloads notifications (called when a new one arrives in real time).
  Future<void> refreshNotifications() async {
    if (!Backend.on || Backend.user == null) return;
    try {
      notifications..clear()..addAll(await Backend.notifications());
      notifyListeners();
    } catch (_) {}
  }

  Future<void> deletePost(Post p) async {
    try {
      if (Backend.on) await Backend.deletePost(p.id);
      posts.remove(p);
      notifyListeners();
    } catch (e) {
      say(errText(e));
    }
  }

  Future<void> reportPost(Post p, String reason) async {
    try {
      if (Backend.on) await Backend.reportPost(p.id, p.userId, reason);
      say('Thanks. Our team will review this post.');
    } catch (e) {
      say(errText(e));
    }
  }

  Future<void> blockUser(Post p) async {
    try {
      if (Backend.on && p.userId != null) await Backend.blockUser(p.userId!);
      posts.removeWhere((x) => Backend.on ? x.userId == p.userId : x.userName == p.userName);
      notifyListeners();
      say('${p.userName} is blocked. You will no longer see their posts.');
    } catch (e) {
      say(errText(e));
    }
  }

  // ---------- bookings ----------
  Future<Booking> createBooking({
    required BookingDraft draft,
    required double total,
    required DateTime start,
    required DateTime end,
  }) async {
    if (Backend.on) {
      final b = await Backend.createBooking(draft, total, start, end);
      bookings.insert(0, b);
      try {
        notifications..clear()..addAll(await Backend.notifications()); // created by a database trigger
      } catch (_) {}
      notifyListeners();
      return b;
    }
    final b = Booking(
      id: 'b${DateTime.now().millisecondsSinceEpoch}',
      title: draft.title,
      location: draft.location,
      type: draft.type,
      seed: draft.seed,
      ref: 'EH-${10000 + Random().nextInt(89999)}',
      amount: total,
      start: start,
      end: end,
    );
    bookings.insert(0, b);
    notifications.insert(
      0,
      AppNotification(
        id: 'n${b.id}',
        kind: draft.type == 'flight' ? 'flight' : 'hotel',
        title: 'Booking confirmed',
        body: '${draft.title} is booked. Reference ${b.ref}.',
        time: 'Just now',
        day: 'Today',
      ),
    );
    notifyListeners();
    return b;
  }

  Future<void> cancelBooking(Booking b) async {
    try {
      if (Backend.on) await Backend.cancelBooking(b.id);
      b.status = 'Cancelled';
      notifyListeners();
    } catch (e) {
      say(errText(e));
    }
  }

  // ---------- notifications ----------
  Future<void> markRead(AppNotification n) async {
    n.read = true;
    notifyListeners();
    if (Backend.on) {
      try {
        await Backend.markRead(n.id);
      } catch (_) {}
    }
  }

  Future<void> markAllRead() async {
    for (final n in notifications) {
      n.read = true;
    }
    notifyListeners();
    if (Backend.on) {
      try {
        await Backend.markAllRead();
      } catch (_) {}
    }
  }
}
