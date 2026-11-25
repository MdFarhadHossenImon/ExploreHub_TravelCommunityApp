import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;
import '../data/backend.dart';
import '../core/i18n.dart';
import 'package:provider/provider.dart';

import '../core/responsive.dart';
import '../core/theme.dart';
import '../data/social.dart';
import '../state/social_state.dart';
import '../widgets/common.dart';
import '../widgets/pull_refresh.dart';
import '../widgets/social_widgets.dart';
import 'traveler_profile.dart';

/// Messenger. Phone: list then chat. Tablet / desktop: list and chat side by side.
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});
  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  Conversation? _open;
  String _q = '';

  void _select(Conversation c) {
    context.read<SocialState>().openConversation(c);
    if (Bp.isWide(context)) {
      setState(() => _open = c);
    } else {
      go(context, ChatScreen(conversation: c));
    }
  }

  @override
  Widget build(BuildContext context) {
    final social = context.watch<SocialState>();
    final wide = Bp.isWide(context);
    final list = social.conversations.where((c) => c.title.toLowerCase().contains(_q.toLowerCase())).toList();
    if (wide && _open == null && list.isNotEmpty) _open = list.first;

    final inbox = Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: TextField(
          onChanged: (v) => setState(() => _q = v),
          decoration: InputDecoration(hintText: tr('Search messages'), prefixIcon: Icon(Icons.search_rounded, color: C.muted), isDense: true),
        ),
      ),
      SizedBox(
        height: 92,
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
          for (final t in social.onlineBuddies)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _select(social.chatWith(t)),
              child: SizedBox(
                width: 70,
                child: Column(children: [
                  const SizedBox(height: 6),
                  PersonAvatar(t, radius: 26, showOnline: true),
                  const SizedBox(height: 6),
                  Text(t.first, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                ]),
              ),
            ),
        ]),
      ),
      Expanded(
        child: list.isEmpty
            ? const EmptyState(Icons.chat_bubble_outline_rounded, 'No conversations', 'Say hi to a travel buddy.')
            : PullRefresh(
                child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: list.length,
                itemBuilder: (c, i) {
                  final cv = list[i];
                  final last = cv.last;
                  final selected = wide && _open == cv;
                  final people = cv.memberIds.map(travelerById).toList();
                  return Material(
                    color: selected ? C.tint : Colors.transparent,
                    child: ListTile(
                      onTap: () => _select(cv),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      leading: cv.isGroup
                          ? SizedBox(
                              width: 48,
                              height: 48,
                              child: Stack(children: [
                                Positioned(right: 0, top: 0, child: Avatar(people[0].seed, name: people[0].name, radius: 17)),
                                Positioned(left: 0, bottom: 0, child: CircleAvatar(radius: 19, backgroundColor: C.bg, child: Avatar(people[1].seed, name: people[1].name, radius: 17))),
                              ]))
                          : PersonAvatar(people.first, radius: 24, showOnline: true),
                      title: Text(cv.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: cv.unread > 0 ? FontWeight.w800 : FontWeight.w600, fontSize: 14.5)),
                      subtitle: Text(
                        last == null ? 'Start chatting' : '${last.fromId == meId ? 'You: ' : ''}${last.text}  ·  ${last.time}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: cv.unread > 0 ? C.ink : C.muted, fontWeight: cv.unread > 0 ? FontWeight.w600 : FontWeight.w400, fontSize: 12.5),
                      ),
                      trailing: cv.unread > 0
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(color: C.primary, borderRadius: BorderRadius.circular(10)),
                              child: Text('${cv.unread}', style: const TextStyle(color: C.on, fontWeight: FontWeight.w800, fontSize: 11)),
                            )
                          : null,
                    ),
                  );
                },
              )),
      ),
    ]);

    final newChat = IconButton(
      tooltip: tr('New message'),
      icon: const Icon(Icons.edit_square, color: C.primary),
      onPressed: () async {
        final t = await showModalBottomSheet<Traveler>(
          context: context,
          constraints: const BoxConstraints(maxWidth: 560),
          builder: (c) => SafeArea(
            child: ListView(shrinkWrap: true, children: [
              Padding(padding: EdgeInsets.all(16), child: Text(tr('New message'), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
              for (final t in social.buddyList) ListTile(leading: PersonAvatar(t, showOnline: true), title: Text(t.name), subtitle: Text(t.home), onTap: () => Navigator.pop(c, t)),
            ]),
          ),
        );
        if (t != null) _select(social.chatWith(t));
      },
    );

    if (!wide) {
      return Scaffold(
        appBar: AppBar(leading: const BackCircle(), leadingWidth: 56, title: Text(tr('Messages')), actions: [newChat]),
        body: Constrained(maxWidth: 640, child: inbox),
      );
    }
    return Scaffold(
      appBar: AppBar(leading: const BackCircle(), leadingWidth: 56, title: Text(tr('Messages')), actions: [newChat]),
      body: Row(children: [
        SizedBox(width: 360, child: inbox),
        const VerticalDivider(width: 1, color: C.line),
        Expanded(child: _open == null ? const EmptyState(Icons.forum_outlined, 'Pick a chat', 'Your conversations show here.') : ChatView(key: ValueKey(_open!.id), conversation: _open!)),
      ]),
    );
  }
}

class ChatScreen extends StatelessWidget {
  final Conversation conversation;
  const ChatScreen({super.key, required this.conversation});

  @override
  Widget build(BuildContext context) {
    final people = conversation.memberIds.map(travelerById).toList();
    return Scaffold(
      appBar: AppBar(
        leading: const BackCircle(),
        leadingWidth: 56,
        centerTitle: false,
        titleSpacing: 0,
        title: InkWell(
          onTap: conversation.isGroup ? null : () => go(context, TravelerProfileScreen(traveler: people.first)),
          child: Row(children: [
            conversation.isGroup ? AvatarStack(people, radius: 14) : PersonAvatar(people.first, radius: 18, showOnline: true),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(conversation.title, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                Text(
                  conversation.isGroup ? '${people.length + 1} travelers' : (context.watch<SocialState>().isOnline(people.first) ? 'Active now' : 'Offline'),
                  style: const TextStyle(fontSize: 11.5, color: C.muted, fontWeight: FontWeight.w400),
                ),
              ]),
            ),
          ]),
        ),
        actions: [
          IconButton(tooltip: tr('Voice call'), onPressed: () => toast(context, tr('Calling is coming soon')), icon: const Icon(Icons.call_rounded, color: C.primary)),
          IconButton(tooltip: tr('Video call'), onPressed: () => toast(context, tr('Video calls are coming soon')), icon: const Icon(Icons.videocam_rounded, color: C.primary)),
        ],
      ),
      body: Constrained(maxWidth: 760, child: ChatView(conversation: conversation, showHeader: false)),
    );
  }
}

/// Message list + composer. Used in the phone chat screen and the desktop split view.
class ChatView extends StatefulWidget {
  final Conversation conversation;
  final bool showHeader;
  const ChatView({super.key, required this.conversation, this.showHeader = true});
  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final _ctl = TextEditingController();
  final _scroll = ScrollController();
  RealtimeChannel? _signals;
  DateTime _lastTypingSent = DateTime(2000);
  final _typing = <String, DateTime>{}; // who is typing, until when
  final _readAt = <String, DateTime>{}; // when each other member last read this chat
  Timer? _typingTimer;
  int _theirCount = -1;
  bool _sendingPhoto = false;

  bool get _live => Backend.on && !widget.conversation.id.startsWith('pending-');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SocialState>().markRead(widget.conversation);
      _jumpToEnd();
    });
    if (_live) {
      final id = widget.conversation.id;
      _signals = Backend.chatSignals(id, _onSignal);
      Backend.othersLastRead(id).then((m) {
        if (mounted) setState(() => _readAt.addAll(m));
      }).catchError((_) {});
      // Tell the others we've seen the chat once the channel is up.
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted && _signals != null) Backend.signal(_signals!, 'seen');
      });
    }
  }

  void _onSignal(String event, Map<String, dynamic> p) {
    final data = p['payload'] is Map ? Map<String, dynamic>.from(p['payload'] as Map) : p;
    final user = data['user'] as String?;
    if (user == null || user == Backend.uid || !mounted) return;
    setState(() {
      if (event == 'typing') {
        _typing[user] = DateTime.now().add(const Duration(seconds: 4));
      } else if (event == 'seen') {
        _readAt[user] = DateTime.now();
        _typing.remove(user);
      }
    });
    if (event == 'typing') {
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(milliseconds: 4100), () {
        if (mounted) setState(() => _typing.removeWhere((_, until) => until.isBefore(DateTime.now())));
      });
    }
  }

  void _onTyping(String v) {
    if (_signals == null || v.trim().isEmpty) return;
    final now = DateTime.now();
    if (now.difference(_lastTypingSent) < const Duration(milliseconds: 2500)) return;
    _lastTypingSent = now;
    Backend.signal(_signals!, 'typing');
  }

  void _jumpToEnd({bool animate = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final end = _scroll.position.maxScrollExtent;
      animate ? _scroll.animateTo(end, duration: const Duration(milliseconds: 250), curve: Curves.easeOut) : _scroll.jumpTo(end);
    });
  }

  void _send([String? text]) {
    final v = (text ?? _ctl.text).trim();
    if (v.isEmpty) return;
    context.read<SocialState>().send(widget.conversation, v);
    _ctl.clear();
    _lastTypingSent = DateTime(2000);
    _jumpToEnd(animate: true);
  }

  Future<void> _pickPhoto() async {
    if (_sendingPhoto) return;
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (f == null || !mounted) return;
    setState(() => _sendingPhoto = true);
    try {
      final bytes = await f.readAsBytes();
      if (bytes.length > 10 * 1024 * 1024) {
        if (mounted) toast(context, tr('Photo is too large. Pick one up to 10 MB.'));
        return;
      }
      final name = f.name.toLowerCase();
      final dot = name.lastIndexOf('.');
      var ext = dot > 0 ? name.substring(dot + 1) : 'jpg';
      if (!const ['jpg', 'jpeg', 'png', 'webp', 'gif', 'heic'].contains(ext)) ext = 'jpg';
      final mime = f.mimeType ?? (ext == 'png' ? 'image/png' : ext == 'webp' ? 'image/webp' : ext == 'gif' ? 'image/gif' : 'image/jpeg');
      if (!mounted) return;
      context.read<SocialState>().sendPhoto(widget.conversation, bytes, ext, mime);
      _jumpToEnd(animate: true);
    } finally {
      if (mounted) setState(() => _sendingPhoto = false);
    }
  }

  /// "Seen", "Sent" or "Sending…" for my last message.
  String _status(Conversation cv) {
    final last = cv.messages.last;
    if (Backend.on && last.id == null) return tr('Sending…');
    if (!Backend.on) return tr('Sent');
    final at = last.at ?? DateTime.now();
    final seenBy = cv.memberIds.where((u) => (_readAt[u] ?? DateTime(2000)).isAfter(at.subtract(const Duration(seconds: 1)))).toList();
    if (seenBy.isEmpty) return tr('Sent');
    if (!cv.isGroup) return tr('Seen');
    if (seenBy.length == cv.memberIds.length) return tr('Seen by everyone');
    return tr('Seen by {n}').replaceAll('{n}', seenBy.map((u) => travelerById(u).first).join(', '));
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _signals?.unsubscribe();
    _ctl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<SocialState>();
    final cv = context.read<SocialState>().current(widget.conversation);
    final people = cv.memberIds.map(travelerById).toList();
    final theirs = cv.messages.where((m) => m.fromId != meId).length;
    if (theirs != _theirCount) {
      final grew = _theirCount >= 0 && theirs > _theirCount;
      _theirCount = theirs;
      if (grew) {
        // A new message came in while the chat is open: it's read, and the sender stopped typing.
        for (final m in cv.messages.reversed.take(3)) {
          _typing.remove(m.fromId);
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          context.read<SocialState>().markRead(cv);
          if (_signals != null) Backend.signal(_signals!, 'seen');
        });
        _jumpToEnd(animate: true);
      }
    }
    final typingNow = _typing.entries.where((e) => e.value.isAfter(DateTime.now())).map((e) => travelerById(e.key)).toList();
    return Column(children: [
      if (widget.showHeader)
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.line))),
          child: Row(children: [
            cv.isGroup ? AvatarStack(people, radius: 14) : PersonAvatar(people.first, radius: 20, showOnline: true),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(cv.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                Text(cv.isGroup ? '${people.length + 1} travelers' : (context.watch<SocialState>().isOnline(people.first) ? 'Active now' : 'Offline'),
                    style: const TextStyle(color: C.muted, fontSize: 12)),
              ]),
            ),
            IconButton(tooltip: tr('Voice call'), onPressed: () => toast(context, tr('Calling is coming soon')), icon: const Icon(Icons.call_rounded, color: C.primary)),
            IconButton(tooltip: tr('Video call'), onPressed: () => toast(context, tr('Video calls are coming soon')), icon: const Icon(Icons.videocam_rounded, color: C.primary)),
            if (!cv.isGroup)
              IconButton(tooltip: tr('Profile'), onPressed: () => go(context, TravelerProfileScreen(traveler: people.first)), icon: const Icon(Icons.info_outline_rounded, color: C.primary)),
          ]),
        ),
      Expanded(
        child: ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 10),
          itemCount: cv.messages.length + 1 + (typingNow.isEmpty ? 0 : 1),
          itemBuilder: (c, i) {
            if (i == cv.messages.length + 1) return _TypingBubble(typingNow, showName: cv.isGroup);
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(children: [
                  cv.isGroup ? AvatarStack(people, radius: 22) : Avatar(people.first.seed, name: people.first.name, radius: 34),
                  const SizedBox(height: 8),
                  Text(cv.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  Text(cv.isGroup ? tr('Group chat for your trip') : tr('You are travel buddies on ExploreHub'), style: const TextStyle(color: C.muted, fontSize: 12)),
                ]),
              );
            }
            final m = cv.messages[i - 1];
            final mine = m.fromId == meId;
            final prevSame = i > 1 && cv.messages[i - 2].fromId == m.fromId;
            final sender = mine ? null : travelerById(m.fromId);
            return Padding(
              padding: EdgeInsets.only(top: prevSame ? 2 : 10),
              child: Row(
                mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!mine) ...[
                    prevSame ? const SizedBox(width: 28) : Avatar(sender!.seed, name: sender.name, radius: 14),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
                        if (cv.isGroup && !mine && !prevSame)
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 2),
                            child: Text(sender!.first, style: const TextStyle(color: C.muted, fontSize: 11)),
                          ),
                        GestureDetector(
                          onLongPress: mine ? () => _confirmDelete(context, cv, m) : null,
                          child: m.isPhoto
                              ? ChatPhoto(m)
                              : Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                  decoration: BoxDecoration(
                                    color: mine ? C.primary : C.card,
                                    border: mine ? null : Border.all(color: C.line),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Text(m.text, style: TextStyle(color: mine ? C.on : C.ink, fontSize: 14, height: 1.35)),
                                ),
                        ),
                        if (mine && i == cv.messages.length)
                          Padding(
                            padding: const EdgeInsets.only(top: 3, right: 4),
                            child: Text('${_status(cv)} · ${tr('Hold to delete')}', style: const TextStyle(color: C.muted, fontSize: 10.5)),
                          ),
                      ]),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.line))),
          child: Row(children: [
            IconButton(tooltip: tr('Share location'), onPressed: () => _send('📍 Shared my location'), icon: const Icon(Icons.location_on_rounded, color: C.primary)),
            IconButton(
              tooltip: tr('Send a photo'),
              onPressed: _sendingPhoto ? null : _pickPhoto,
              icon: _sendingPhoto
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.image_rounded, color: C.primary),
            ),
            Expanded(
              child: TextField(
                controller: _ctl,
                onSubmitted: (_) => _send(),
                onChanged: _onTyping,
                decoration: InputDecoration(
                  hintText: tr('Message...'),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: C.line)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: C.line)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: C.primary)),
                ),
              ),
            ),
            IconButton(tooltip: tr('Send'), onPressed: _send, icon: const Icon(Icons.send_rounded, color: C.primary)),
          ]),
        ),
      ),
    ]);
  }
}

/// "Ayesha is typing…" with three bouncing dots.
class _TypingBubble extends StatefulWidget {
  final List<Traveler> who;
  final bool showName;
  const _TypingBubble(this.who, {this.showName = false});
  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble> with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.who.first;
    final label = widget.who.length == 1 ? tr('{name} is typing…').replaceAll('{name}', t.first) : tr('Several people are typing…');
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Avatar(t.seed, name: t.name, radius: 14),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: C.card, border: Border.all(color: C.line), borderRadius: BorderRadius.circular(18)),
          child: AnimatedBuilder(
            animation: _anim,
            builder: (_, __) => Row(mainAxisSize: MainAxisSize.min, children: [
              for (var k = 0; k < 3; k++)
                Transform.translate(
                  offset: Offset(0, -3 * sin(((_anim.value - k * 0.18) % 1.0) * pi).clamp(0.0, 1.0)),
                  child: Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: const BoxDecoration(color: C.muted, shape: BoxShape.circle),
                  ),
                ),
            ]),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(child: Text(label, style: const TextStyle(color: C.muted, fontSize: 11.5), overflow: TextOverflow.ellipsis)),
      ]),
    );
  }
}

/// A photo in a chat: shown from memory while uploading, then from a private signed link.
class ChatPhoto extends StatelessWidget {
  final Message m;
  const ChatPhoto(this.m, {super.key});

  Widget _image(BoxFit fit) {
    if (m.bytes != null) return Image.memory(m.bytes!, fit: fit, gaplessPlayback: true);
    if (m.media != null && Backend.on) {
      return FutureBuilder<String>(
        future: Backend.chatMediaUrl(m.media!),
        builder: (_, snap) => snap.hasData
            ? Image.network(snap.data!, fit: fit, errorBuilder: (_, __, ___) => const _PhotoMissing())
            : snap.hasError
                ? const _PhotoMissing()
                : const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    if (m.imageSeed != null) return Image.network('https://picsum.photos/seed/${m.imageSeed}/600/600', fit: fit);
    return const _PhotoMissing();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        barrierColor: Colors.black87,
        builder: (c) => GestureDetector(
          onTap: () => Navigator.pop(c),
          child: InteractiveViewer(maxScale: 5, child: Center(child: _image(BoxFit.contain))),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 220,
          height: 260,
          color: C.line,
          child: _image(BoxFit.cover),
        ),
      ),
    );
  }
}

class _PhotoMissing extends StatelessWidget {
  const _PhotoMissing();
  @override
  Widget build(BuildContext context) =>
      Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.broken_image_outlined, color: C.muted), Text(tr('Photo unavailable'), style: const TextStyle(color: C.muted, fontSize: 11))]));
}

Future<void> _confirmDelete(BuildContext context, Conversation cv, Message m) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (c) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.delete_outline_rounded, color: C.danger),
          title: Text(tr('Delete for everyone'), style: TextStyle(color: C.danger)),
          onTap: () => Navigator.pop(c, true),
        ),
        ListTile(leading: const Icon(Icons.close_rounded), title: Text(tr('Cancel')), onTap: () => Navigator.pop(c, false)),
      ]),
    ),
  );
  if (ok == true && context.mounted) await context.read<SocialState>().deleteMessage(cv, m);
}
