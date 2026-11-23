import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/responsive.dart';
import '../core/theme.dart';
import '../data/social.dart';
import '../state/social_state.dart';
import '../widgets/common.dart';
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
          decoration: const InputDecoration(hintText: 'Search messages', prefixIcon: Icon(Icons.search_rounded, color: C.muted), isDense: true),
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
            : ListView.builder(
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
                          ? SizedBox(width: 48, height: 48, child: Stack(children: [
                              Positioned(right: 0, top: 0, child: Avatar(people[0].seed, name: people[0].name, radius: 17)),
                              Positioned(left: 0, bottom: 0, child: CircleAvatar(radius: 19, backgroundColor: C.bg, child: Avatar(people[1].seed, name: people[1].name, radius: 17))),
                            ]))
                          : PersonAvatar(people.first, radius: 24, showOnline: true),
                      title: Text(cv.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: cv.unread > 0 ? FontWeight.w800 : FontWeight.w600, fontSize: 14.5)),
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
              ),
      ),
    ]);

    final newChat = IconButton(
      tooltip: 'New message',
      icon: const Icon(Icons.edit_square, color: C.primary),
      onPressed: () async {
        final t = await showModalBottomSheet<Traveler>(
          context: context,
          constraints: const BoxConstraints(maxWidth: 560),
          builder: (c) => SafeArea(
            child: ListView(shrinkWrap: true, children: [
              const Padding(padding: EdgeInsets.all(16), child: Text('New message', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
              for (final t in social.buddyList)
                ListTile(leading: PersonAvatar(t, showOnline: true), title: Text(t.name), subtitle: Text(t.home), onTap: () => Navigator.pop(c, t)),
            ]),
          ),
        );
        if (t != null) _select(social.chatWith(t));
      },
    );

    if (!wide) {
      return Scaffold(
        appBar: AppBar(leading: const BackCircle(), leadingWidth: 56, title: const Text('Messages'), actions: [newChat]),
        body: Constrained(maxWidth: 640, child: inbox),
      );
    }
    return Scaffold(
      appBar: AppBar(leading: const BackCircle(), leadingWidth: 56, title: const Text('Messages'), actions: [newChat]),
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
          IconButton(tooltip: 'Voice call', onPressed: () => toast(context, 'Calling is coming soon'), icon: const Icon(Icons.call_rounded, color: C.primary)),
          IconButton(tooltip: 'Video call', onPressed: () => toast(context, 'Video calls are coming soon'), icon: const Icon(Icons.videocam_rounded, color: C.primary)),
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

  void _send([String? text]) {
    final v = (text ?? _ctl.text).trim();
    if (v.isEmpty) return;
    context.read<SocialState>().send(widget.conversation, v);
    _ctl.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  @override
  void dispose() {
    _ctl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<SocialState>();
    final cv = context.read<SocialState>().current(widget.conversation);
    final people = cv.memberIds.map(travelerById).toList();
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
            IconButton(tooltip: 'Voice call', onPressed: () => toast(context, 'Calling is coming soon'), icon: const Icon(Icons.call_rounded, color: C.primary)),
            IconButton(tooltip: 'Video call', onPressed: () => toast(context, 'Video calls are coming soon'), icon: const Icon(Icons.videocam_rounded, color: C.primary)),
            if (!cv.isGroup)
              IconButton(
                  tooltip: 'Profile',
                  onPressed: () => go(context, TravelerProfileScreen(traveler: people.first)),
                  icon: const Icon(Icons.info_outline_rounded, color: C.primary)),
          ]),
        ),
      Expanded(
        child: ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 10),
          itemCount: cv.messages.length + 1,
          itemBuilder: (c, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(children: [
                  cv.isGroup ? AvatarStack(people, radius: 22) : Avatar(people.first.seed, name: people.first.name, radius: 34),
                  const SizedBox(height: 8),
                  Text(cv.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  Text(cv.isGroup ? 'Group chat for your trip' : 'You are travel buddies on ExploreHub',
                      style: const TextStyle(color: C.muted, fontSize: 12)),
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
                          child: Container(
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
                          const Padding(padding: EdgeInsets.only(top: 3, right: 4), child: Text('Hold a message to delete it', style: TextStyle(color: C.muted, fontSize: 10.5))),
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
            IconButton(tooltip: 'Share location', onPressed: () => _send('📍 Shared my location'), icon: const Icon(Icons.location_on_rounded, color: C.primary)),
            IconButton(tooltip: 'Photo', onPressed: () => toast(context, 'Photo sharing uses your gallery'), icon: const Icon(Icons.image_rounded, color: C.primary)),
            Expanded(
              child: TextField(
                controller: _ctl,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Message...',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: C.line)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: C.line)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: C.primary)),
                ),
              ),
            ),
            IconButton(tooltip: 'Send', onPressed: _send, icon: const Icon(Icons.send_rounded, color: C.primary)),
          ]),
        ),
      ),
    ]);
  }
}

Future<void> _confirmDelete(BuildContext context, Conversation cv, Message m) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (c) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.delete_outline_rounded, color: C.danger),
          title: const Text('Delete for everyone', style: TextStyle(color: C.danger)),
          onTap: () => Navigator.pop(c, true),
        ),
        ListTile(leading: const Icon(Icons.close_rounded), title: const Text('Cancel'), onTap: () => Navigator.pop(c, false)),
      ]),
    ),
  );
  if (ok == true && context.mounted) await context.read<SocialState>().deleteMessage(cv, m);
}
