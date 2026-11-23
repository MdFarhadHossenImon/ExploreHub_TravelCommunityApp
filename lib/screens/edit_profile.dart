import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../data/backend.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';

/// Edit the traveler's public profile: photo, cover, name, handle, bio, home, countries.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final AppState s = context.read<AppState>();
  late final _name = TextEditingController(text: s.name);
  late final _user = TextEditingController(text: s.username ?? '');
  late final _bio = TextEditingController(text: s.bio);
  late final _home = TextEditingController(text: s.home);
  late final _country = TextEditingController();
  late final List<String> _countries = [...s.countries];
  Uint8List? _avatar, _cover;
  bool _busy = false;

  Future<Uint8List?> _pick(double maxWidth) async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: maxWidth, imageQuality: 85);
    return f?.readAsBytes();
  }

  void _addCountry() {
    final v = _country.text.trim();
    if (v.isEmpty || _countries.contains(v)) return;
    setState(() => _countries.add(v));
    _country.clear();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final user = _user.text.trim().toLowerCase().replaceAll('@', '');
    if (name.isEmpty) return toast(context, 'Please enter your name');
    if (user.isNotEmpty && !RegExp(r'^[a-z0-9_.]{3,24}$').hasMatch(user)) {
      return toast(context, 'Username: 3-24 letters, numbers, _ or .');
    }
    setState(() => _busy = true);
    final ok = await s.saveProfile(
      name: name,
      username: user,
      bio: _bio.text.trim(),
      home: _home.text.trim(),
      countries: _countries,
      avatar: _avatar,
      cover: _cover,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      toast(context, 'Profile updated');
      Navigator.pop(context);
    } else {
      toast(context, 'Could not save. That username may be taken.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final coverImg = _cover != null
        ? Image.memory(_cover!, fit: BoxFit.cover)
        : (s.coverUrl != null ? AppImage(s.coverUrl!, radius: 0) : AppImage('cover-me', radius: 0));
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile'), actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: FilledButton(
            onPressed: _busy ? null : _save,
            child: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
          ),
        ),
      ]),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
            SizedBox(
              height: 210,
              child: Stack(children: [
                Positioned.fill(
                  bottom: 50,
                  child: GestureDetector(
                    onTap: () async {
                      final b = await _pick(1800);
                      if (b != null) setState(() => _cover = b);
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Stack(fit: StackFit.expand, children: [
                        coverImg,
                        Container(color: Colors.black26),
                        const Center(child: _Chip(Icons.photo_camera_rounded, 'Change cover')),
                      ]),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: () async {
                        final b = await _pick(800);
                        if (b != null) setState(() => _avatar = b);
                      },
                      child: Stack(children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: _avatar != null
                              ? CircleAvatar(radius: 46, backgroundImage: MemoryImage(_avatar!))
                              : Avatar(s.avatarSeed, name: s.name, radius: 46),
                        ),
                        Positioned(
                          right: 2,
                          bottom: 2,
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(color: C.primary, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                            child: const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 16),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 20),
            _label('Full name'),
            TextField(controller: _name, textCapitalization: TextCapitalization.words),
            const SizedBox(height: 14),
            _label('Username'),
            TextField(controller: _user, decoration: const InputDecoration(prefixText: '@')),
            const SizedBox(height: 14),
            _label('Bio'),
            TextField(controller: _bio, maxLines: 3, maxLength: 160, decoration: const InputDecoration(hintText: 'What kind of traveler are you?')),
            const SizedBox(height: 6),
            _label('Home base'),
            TextField(controller: _home, decoration: const InputDecoration(hintText: 'City, Country', prefixIcon: Icon(Icons.home_rounded))),
            const SizedBox(height: 14),
            _label('Countries visited (${_countries.length})'),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final c in _countries) InputChip(label: Text(c), onDeleted: () => setState(() => _countries.remove(c))),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _country,
                  textCapitalization: TextCapitalization.words,
                  onSubmitted: (_) => _addCountry(),
                  decoration: const InputDecoration(hintText: 'Add a country'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(onPressed: _addCountry, icon: const Icon(Icons.add_rounded)),
            ]),
            if (!Backend.on) ...[
              const SizedBox(height: 18),
              const Text('Demo mode: changes stay on this device.', style: TextStyle(color: C.muted, fontSize: 12.5)),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6, left: 2),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      );
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Chip(this.icon, this.text);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(30)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
        ]),
      );
}
