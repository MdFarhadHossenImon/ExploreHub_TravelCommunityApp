import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;

import '../core/env.dart';
import '../data/backend.dart';
import '../data/offline.dart';
import '../data/models.dart';
import '../data/social.dart';

/// Friends, stories, reactions, messaging, groups and trip planning.
/// - With Supabase keys: everything is loaded from and saved to the database
///   (tables in supabase/social.sql), new chat messages arrive in real time.
/// - Without keys: runs on the bundled demo data.
class SocialState extends ChangeNotifier {
  SocialState() {
    if (Backend.on) {
      travelers.clear();
      buddies.clear();
      incoming.clear();
      stories.clear();
      conversations.clear();
      groups.clear();
      joined.clear();
      trips.clear();
    }
  }

  bool loading = false;
  RealtimeChannel? _chatChannel;

  /// Loads everything for the signed-in user. Safe to call again (pull to refresh).
  Future<void> load() async {
    if (!Backend.on || Backend.uid == null) return;
    loading = true;
    notifyListeners();
    try {
      final people = await Backend.travelers();
      travelers
        ..clear()
        ..addAll(people.where((t) => t.id != Backend.uid));
      await Future.wait([_loadBuddies(), _loadStories(), _loadChats(), _loadGroups(), _loadTrips(), _loadReactions(), loadMeetups()]);
      _chatChannel ??= Backend.onNewMessage(_onMessage);
      Backend.joinPresence((ids) {
        online
          ..clear()
          ..addAll(ids);
        notifyListeners();
      });
    } catch (e) {
      if (Offline.online.value) say(errText(e));
    }
    loading = false;
    notifyListeners();
  }

  void clear() {
    _chatChannel?.unsubscribe();
    _chatChannel = null;
    Backend.leavePresence();
    online.clear();
    meetups.clear();
    rsvps.clear();
    _mutuals.clear();
    buddies.clear();
    incoming.clear();
    sent.clear();
    stories.clear();
    conversations.clear();
    groups.clear();
    joined.clear();
    pending.clear();
    trips.clear();
    reactions.clear();
    notifyListeners();
  }

  Future<void> _guard(Future<void> Function() call, [VoidCallback? undo]) async {
    if (!Backend.on) return;
    try {
      await call();
    } catch (e) {
      undo?.call();
      notifyListeners();
      say(errText(e));
    }
  }

  // ---------- friends / travel buddies ----------
  final Set<String> buddies = {'ayesha', 'tanvir', 'sam', 'meilin', 'arjun'};
  final Set<String> incoming = {'lena', 'hana'};
  final Set<String> sent = {};

  Future<void> _loadBuddies() async {
    final rows = await Backend.buddyRows();
    buddies.clear();
    incoming.clear();
    sent.clear();
    for (final r in rows) {
      final mineSent = r['from_id'] == Backend.uid;
      final other = (mineSent ? r['to_id'] : r['from_id']) as String;
      if (r['status'] == 'accepted') {
        buddies.add(other);
      } else {
        (mineSent ? sent : incoming).add(other);
      }
    }
  }

  List<Traveler> get buddyList => travelers.where((t) => buddies.contains(t.id)).toList();
  List<Traveler> get requestList => travelers.where((t) => incoming.contains(t.id)).toList();
  List<Traveler> get suggestions =>
      travelers.where((t) => !buddies.contains(t.id) && !incoming.contains(t.id)).toList();
  // ---------- online status (Supabase Realtime presence) ----------
  /// Ids of travelers who have the app open right now.
  final Set<String> online = {};
  bool isOnline(Traveler t) => Backend.on ? online.contains(t.id) : t.online;
  List<Traveler> get onlineBuddies => buddyList.where(isOnline).toList();

  /// Buddies you both have. Live mode asks the database once per traveler and caches it.
  final Map<String, int> _mutuals = {};
  int mutuals(Traveler t) {
    if (!Backend.on) return (t.followers % 23) + 2;
    final cached = _mutuals[t.id];
    if (cached != null) return cached;
    _mutuals[t.id] = 0;
    Backend.mutualBuddies(t.id).then((n) {
      _mutuals[t.id] = n;
      if (n > 0) notifyListeners();
    }).catchError((_) {});
    return 0;
  }

  // ---------- travel meetups ----------
  final List<Meetup> meetups = [];
  /// meetup id -> 'going' | 'interested'
  final Map<String, String> rsvps = {};

  Future<void> loadMeetups() async {
    if (!Backend.on || Backend.uid == null) return;
    final list = await Backend.meetups();
    final mine = await Backend.myRsvps();
    meetups
      ..clear()
      ..addAll(list);
    rsvps
      ..clear()
      ..addAll(mine);
    notifyListeners();
  }

  Future<bool> createMeetup({
    required String title,
    required String about,
    required String location,
    required DateTime startsAt,
    String? placeId,
    int? capacity,
    Uint8List? cover,
  }) async {
    try {
      String? coverUrl;
      if (cover != null) coverUrl = await Backend.upload(cover, 'jpg', 'image/jpeg');
      await Backend.createMeetup(
          title: title, about: about, location: location, startsAt: startsAt, placeId: placeId, capacity: capacity, coverUrl: coverUrl);
      await loadMeetups();
      return true;
    } catch (e) {
      say(errText(e));
      return false;
    }
  }

  Future<void> deleteMeetup(Meetup m) async {
    meetups.remove(m);
    notifyListeners();
    await _guard(() => Backend.deleteMeetup(m.id), () => meetups.add(m));
  }

  /// [status] 'going', 'interested' or null to cancel.
  Future<void> setRsvp(Meetup m, String? status) async {
    final before = rsvps[m.id];
    void count(String? st, int d) {
      if (st == 'going') m.going += d;
      if (st == 'interested') m.interested += d;
    }

    count(before, -1);
    count(status, 1);
    if (status == null) {
      rsvps.remove(m.id);
    } else {
      rsvps[m.id] = status;
    }
    notifyListeners();
    await _guard(() => Backend.setRsvp(m.id, status), () {
      count(status, -1);
      count(before, 1);
      if (before == null) {
        rsvps.remove(m.id);
      } else {
        rsvps[m.id] = before;
      }
    });
  }

  void acceptRequest(String id) {
    incoming.remove(id);
    buddies.add(id);
    notifyListeners();
    _guard(() => Backend.acceptBuddy(id), () {
      buddies.remove(id);
      incoming.add(id);
    });
  }

  void declineRequest(String id) {
    incoming.remove(id);
    notifyListeners();
    _guard(() => Backend.removeBuddy(id), () => incoming.add(id));
  }

  void toggleRequest(String id) {
    final on = !sent.contains(id);
    on ? sent.add(id) : sent.remove(id);
    notifyListeners();
    _guard(() => on ? Backend.sendBuddyRequest(id) : Backend.cancelBuddyRequest(id), () => on ? sent.remove(id) : sent.add(id));
  }

  void removeBuddy(String id) {
    buddies.remove(id);
    notifyListeners();
    _guard(() => Backend.removeBuddy(id), () => buddies.add(id));
  }

  // ---------- stories ----------
  final List<Story> stories = List.of(seedStories);
  final Set<String> seenStories = {};

  Future<void> _loadStories() async {
    final list = await Backend.stories();
    stories
      ..clear()
      ..addAll(list.map((s) => s.travelerId == Backend.uid ? Story(s.id, meId, s.imageSeed, s.caption, s.time, placeId: s.placeId) : s));
    seenStories
      ..clear()
      ..addAll(await Backend.seenStories());
  }

  void markSeen(String id) {
    if (!seenStories.add(id)) return;
    notifyListeners();
    // Your own views don't count toward your viewer list.
    final own = stories.any((st) => st.id == id && st.travelerId == meId);
    if (!own) _guard(() => Backend.markStorySeen(id));
  }

  /// Reacts to a story: saved on the story and sent to the owner as a chat message.
  void reactStory(Story st, Traveler owner, String emoji) {
    seenStories.add(st.id);
    send(chatWith(owner), '$emoji · Reacted to your story${st.caption.isEmpty ? '' : ' "${st.caption.length > 40 ? '${st.caption.substring(0, 40)}…' : st.caption}"'}');
    _guard(() => Backend.reactStory(st.id, emoji));
  }

  /// Replies to a story privately in chat, quoting it.
  void replyStory(Story st, Traveler owner, String text) {
    final quote = st.caption.isEmpty ? '' : ' "${st.caption.length > 40 ? '${st.caption.substring(0, 40)}…' : st.caption}"';
    send(chatWith(owner), '↩️ Replied to your story$quote: $text');
  }

  /// Demo story (sample image).
  void addStory(String imageSeed, String caption) {
    stories.insert(0, Story('s${DateTime.now().millisecondsSinceEpoch}', meId, imageSeed, caption, 'now'));
    notifyListeners();
  }

  /// Real story: upload the photo, then save the row.
  Future<bool> publishStory(Uint8List bytes, String ext, String mime, String caption) async {
    try {
      final url = await Backend.upload(bytes, ext, mime);
      final st = await Backend.addStory(url, caption);
      stories.insert(0, Story(st.id, meId, st.imageSeed, st.caption, 'now'));
      notifyListeners();
      return true;
    } catch (e) {
      say(errText(e));
      return false;
    }
  }

  // ---------- reactions ----------
  /// post id -> emoji chosen by the user (the like itself is created by AppState.toggleLike).
  final Map<String, String> reactions = {};

  Future<void> _loadReactions() async {
    reactions
      ..clear()
      ..addAll(await Backend.myReactions());
  }

  void react(String postId, String? emoji) {
    emoji == null ? reactions.remove(postId) : reactions[postId] = emoji;
    notifyListeners();
    if (emoji != null) {
      // let AppState's like insert land first
      Future.delayed(const Duration(milliseconds: 600), () => _guard(() => Backend.setReaction(postId, emoji)));
    }
  }

  // ---------- messaging ----------
  final List<Conversation> conversations = seedConversations();
  int get unreadChats => conversations.where((c) => c.unread > 0).length;

  Future<void> _loadChats() async {
    final list = await Backend.conversations();
    conversations
      ..clear()
      ..addAll(list);
  }

  void _onMessage(Map<String, dynamic> row) {
    if (row['sender_id'] == Backend.uid) return; // our own, already shown
    final id = row['conversation_id'] as String;
    final idx = conversations.indexWhere((c) => c.id == id);
    if (idx < 0) {
      _loadChats().then((_) => notifyListeners());
      return;
    }
    final c = conversations[idx];
    c.messages.add(Backend.messageFromRow(row));
    c.unread++;
    conversations
      ..removeAt(idx)
      ..insert(0, c);
    notifyListeners();
  }

  void openConversation(Conversation c) {
    if (c.unread == 0) return;
    c.unread = 0;
    notifyListeners();
    _guard(() => Backend.markConversationRead(c.id));
  }

  void send(Conversation c, String text) {
    c = current(c);
    final m = Message(meId, text, 'Now', at: DateTime.now());
    c.messages.add(m);
    conversations
      ..remove(c)
      ..insert(0, c);
    notifyListeners();
    if (c.id.startsWith('pending-')) return; // sent once the chat id arrives
    final conv = c;
    _guard(() async {
      final id = await Backend.sendMessage(conv.id, text);
      final i = conv.messages.indexOf(m);
      if (i >= 0) conv.messages[i] = Message(m.fromId, m.text, m.time, at: m.at, id: id);
    }, () => conv.messages.remove(m));
  }

  /// Sends a photo. It shows at once from its bytes and uploads to the chat's private folder.
  void sendPhoto(Conversation c, Uint8List bytes, String ext, String mime) {
    c = current(c);
    final m = Message(meId, '📷 Photo', 'Now', at: DateTime.now(), bytes: bytes);
    c.messages.add(m);
    conversations
      ..remove(c)
      ..insert(0, c);
    notifyListeners();
    if (!Backend.on || c.id.startsWith('pending-')) return;
    final conv = c;
    _guard(() async {
      final path = await Backend.uploadChatPhoto(conv.id, bytes, ext, mime);
      final id = await Backend.sendMessage(conv.id, m.text, mediaPath: path);
      final i = conv.messages.indexOf(m);
      if (i >= 0) conv.messages[i] = Message(m.fromId, m.text, m.time, at: m.at, id: id, media: path, bytes: bytes);
    }, () => conv.messages.remove(m));
  }

  /// Marks a chat read on the server (also while it is open and new messages arrive).
  void markRead(Conversation c) {
    c = current(c);
    final had = c.unread;
    c.unread = 0;
    if (had > 0) notifyListeners();
    if (Backend.on && !c.id.startsWith('pending-')) _guard(() => Backend.markConversationRead(c.id));
  }

  /// Deletes one of your own messages for everyone.
  Future<void> deleteMessage(Conversation c, Message m) async {
    c = current(c);
    final i = c.messages.indexOf(m);
    if (i < 0) return;
    c.messages.removeAt(i);
    notifyListeners();
    if (!Backend.on || m.id == null) return;
    final conv = c;
    await _guard(() => Backend.deleteMessage(m.id!), () => conv.messages.insert(i, m));
  }

  /// Stories in viewing order: one group per traveler (you first, then whoever posted most recently),
  /// each group oldest to newest, like Facebook.
  List<Story> get storyQueue {
    final order = <String>[];
    final by = <String, List<Story>>{};
    for (final st in stories) {
      if (!by.containsKey(st.travelerId)) order.add(st.travelerId);
      (by[st.travelerId] ??= []).add(st);
    }
    order.sort((a, b) => a == meId ? -1 : (b == meId ? 1 : 0));
    return [for (final id in order) ...by[id]!.reversed];
  }

  /// Deletes one of your own stories.
  Future<void> deleteStory(Story st) async {
    final i = stories.indexOf(st);
    if (i < 0) return;
    stories.removeAt(i);
    notifyListeners();
    await _guard(() => Backend.deleteStory(st.id), () => stories.insert(i, st));
  }

  /// Opens (or creates) a one-to-one chat. Live: the database returns the conversation id.
  Conversation chatWith(Traveler t) {
    for (final c in conversations) {
      if (!c.isGroup && c.memberIds.length == 1 && c.memberIds.first == t.id) return c;
    }
    final c = Conversation(id: Backend.on ? 'pending-${t.id}' : 'c${DateTime.now().millisecondsSinceEpoch}', title: t.name, memberIds: [t.id], messages: []);
    conversations.insert(0, c);
    if (Backend.on) {
      Backend.dmWith(t.id).then((id) {
        final i = conversations.indexOf(c);
        if (i >= 0) {
          conversations[i] = Conversation(id: id, title: t.name, memberIds: [t.id], messages: c.messages);
          for (final m in c.messages) {
            Backend.sendMessage(id, m.text);
          }
          notifyListeners();
        }
      }).catchError((Object e) {
        say(errText(e));
      });
    }
    return c;
  }

  /// The live version of a conversation (its id changes from pending to real).
  Conversation current(Conversation c) {
    if (!c.id.startsWith('pending-')) return c;
    for (final x in conversations) {
      if (!x.isGroup && x.memberIds.length == 1 && x.memberIds.first == c.memberIds.first) return x;
    }
    return c;
  }

  // ---------- groups ----------
  final List<TravelGroup> groups = seedGroups();
  final Set<String> joined = {'g-bd', 'g-budget', 'g-dive'};
  final Set<String> pending = {};

  Future<void> _loadGroups() async {
    final list = await Backend.groups();
    groups
      ..clear()
      ..addAll(list);
    joined.clear();
    pending.clear();
    for (final m in await Backend.myMemberships()) {
      (m['status'] == 'active' ? joined : pending).add(m['group_id'] as String);
    }
  }

  Future<void> loadGroupPosts(TravelGroup g) async {
    if (!Backend.on) return;
    try {
      final list = await Backend.groupPosts(g.id);
      g.posts
        ..clear()
        ..addAll(list);
      notifyListeners();
    } catch (e) {
      say(errText(e));
    }
  }

  List<TravelGroup> get myGroups => groups.where((g) => joined.contains(g.id)).toList();
  List<TravelGroup> get discoverGroups => groups.where((g) => !joined.contains(g.id)).toList();

  void toggleJoin(TravelGroup g) {
    if (joined.contains(g.id)) {
      joined.remove(g.id);
      notifyListeners();
      _guard(() => Backend.leaveGroup(g.id), () => joined.add(g.id));
    } else if (g.private) {
      final on = !pending.contains(g.id);
      on ? pending.add(g.id) : pending.remove(g.id);
      notifyListeners();
      _guard(() => on ? Backend.joinGroup(g.id, pending: true) : Backend.leaveGroup(g.id), () => on ? pending.remove(g.id) : pending.add(g.id));
    } else {
      joined.add(g.id);
      notifyListeners();
      _guard(() async {
        await Backend.joinGroup(g.id);
        await loadGroupPosts(g);
      }, () => joined.remove(g.id));
    }
  }

  Future<TravelGroup?> createGroup(String name, String about, bool private) async {
    if (!Backend.on) {
      final g = TravelGroup(
          id: 'g${DateTime.now().millisecondsSinceEpoch}', name: name, coverSeed: 'group-${name.toLowerCase()}', about: about,
          category: 'Community', members: 1, private: private, posts: []);
      groups.insert(0, g);
      joined.add(g.id);
      notifyListeners();
      return g;
    }
    try {
      final g = await Backend.createGroup(name, about, private);
      groups.insert(0, g);
      joined.add(g.id);
      notifyListeners();
      return g;
    } catch (e) {
      say(errText(e));
      return null;
    }
  }

  /// Post in a group ([mediaUrl] is an uploaded photo when live).
  void postToGroup(TravelGroup g, Post p, {String? mediaUrl}) {
    g.posts.insert(0, p);
    notifyListeners();
    _guard(() => Backend.createGroupPost(g.id, p.caption, mediaUrl ?? p.imageSeed), () => g.posts.remove(p));
  }

  // ---------- trip planner ----------
  final List<TripPlan> trips = seedTrips();

  Future<void> _loadTrips() async {
    final list = await Backend.trips();
    trips
      ..clear()
      ..addAll(list);
  }

  TripPlan createTrip({required String title, required String placeId, required DateTime start, required int days, double budget = 0}) {
    final t = TripPlan(
      id: 't${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      placeId: placeId,
      start: start,
      budget: budget,
      buddies: [],
      days: [for (var i = 0; i < days; i++) TripDay([])],
    );
    trips.insert(0, t);
    notifyListeners();
    if (Backend.on) {
      Backend.createTrip(title, placeId, start, days, budget).then((id) {
        final i = trips.indexOf(t);
        if (i >= 0) {
          trips[i] = TripPlan(id: id, title: t.title, placeId: t.placeId, start: t.start, days: t.days, buddies: t.buddies, budget: t.budget, public: t.public);
          // stops added before the id arrived
          for (var d = 0; d < t.days.length; d++) {
            for (final s in t.days[d].stops.where((s) => s.id == null)) {
              Backend.addStop(id, d, s).then((sid) => s.id = sid);
            }
          }
          notifyListeners();
        }
      }).catchError((Object e) {
        trips.remove(t);
        notifyListeners();
        say(errText(e));
      });
    }
    return t;
  }

  /// The live version of a trip (its id changes once the database saves it).
  TripPlan currentTrip(TripPlan t) => trips.firstWhere((x) => x.id == t.id || (x.title == t.title && x.start == t.start), orElse: () => t);
  bool _saved(TripPlan t) => !Backend.on || !t.id.startsWith('t');

  void addStop(TripPlan t, int day, TripStop s) {
    t = currentTrip(t);
    t.days[day].stops.add(s);
    notifyListeners();
    if (_saved(t)) _guard(() async => s.id = await Backend.addStop(t.id, day, s), () => t.days[day].stops.remove(s));
  }

  void removeStop(TripPlan t, int day, TripStop s) {
    t = currentTrip(t);
    t.days[day].stops.remove(s);
    notifyListeners();
    if (s.id != null) _guard(() => Backend.removeStop(s.id!), () => t.days[day].stops.add(s));
  }

  void addDay(TripPlan t) {
    t = currentTrip(t);
    t.days.add(TripDay([]));
    notifyListeners();
    if (_saved(t)) _guard(() => Backend.updateTrip(t.id, {'days': t.days.length}));
  }

  void setTripPublic(TripPlan t, bool v) {
    t = currentTrip(t);
    t.public = v;
    notifyListeners();
    if (_saved(t)) _guard(() => Backend.updateTrip(t.id, {'public': v}));
  }

  void setTripDiscoverable(TripPlan t, bool v) {
    t = currentTrip(t);
    t.discoverable = v;
    notifyListeners();
    if (_saved(t)) _guard(() => Backend.updateTrip(t.id, {'discoverable': v}));
  }

  /// Your next trip to this place that has not ended yet.
  TripPlan? myTripTo(String placeId) {
    final today = DateTime.now();
    final list = trips.where((t) => t.placeId == placeId && !t.end.isBefore(DateTime(today.year, today.month, today.day))).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    return list.isEmpty ? null : list.first;
  }

  void inviteBuddy(TripPlan t, String id) {
    t = currentTrip(t);
    if (t.buddies.contains(id)) return;
    t.buddies.add(id);
    notifyListeners();
    if (_saved(t)) _guard(() => Backend.inviteToTrip(t.id, id), () => t.buddies.remove(id));
  }

  void deleteTrip(TripPlan t) {
    t = currentTrip(t);
    trips.remove(t);
    notifyListeners();
    if (_saved(t)) _guard(() => Backend.deleteTrip(t.id), () => trips.insert(0, t));
  }

  void touch() => notifyListeners();

  bool get live => Env.configured;
}
