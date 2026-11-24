import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/social_widgets.dart';

class PhraseLang {
  final String code, name, bn, tts;
  final List<String> countries;
  final List<(String, String)> rows; // native, pronunciation
  const PhraseLang(this.code, this.name, this.bn, this.tts, this.countries, this.rows);
}

class Phrasebook {
  static List<Map<String, dynamic>> phrases = [];
  static List<PhraseLang> langs = [];

  static Future<void> load() async {
    if (langs.isNotEmpty) return;
    final d = jsonDecode(await rootBundle.loadString('assets/phrasebook.json')) as Map<String, dynamic>;
    phrases = List<Map<String, dynamic>>.from(d['phrases'] as List);
    langs = [
      for (final e in (d['languages'] as Map<String, dynamic>).entries)
        PhraseLang(
          e.key,
          e.value['name'] as String,
          e.value['bn'] as String,
          e.value['tts'] as String,
          List<String>.from(e.value['countries'] as List),
          [for (final r in e.value['rows'] as List) ((r as List)[0] as String, r[1] as String)],
        ),
    ];
  }

  /// The language to show for a country, if the phrasebook has one.
  static PhraseLang? forCountry(String country) {
    final c = country.toLowerCase();
    for (final l in langs) {
      if (l.countries.any((x) => x.toLowerCase() == c)) return l;
    }
    return null;
  }
}

/// Useful phrases in the local language, with pronunciation and a play button.
class PhrasebookScreen extends StatefulWidget {
  final String? country;
  const PhrasebookScreen({super.key, this.country});
  @override
  State<PhrasebookScreen> createState() => _PhrasebookScreenState();
}

class _PhrasebookScreenState extends State<PhrasebookScreen> {
  PhraseLang? _lang;
  final _tts = FlutterTts();
  int? _playing;
  bool _ready = false;
  String _cat = 'all';

  @override
  void initState() {
    super.initState();
    Phrasebook.load().then((_) {
      if (!mounted) return;
      setState(() {
        _ready = true;
        _lang = (widget.country == null ? null : Phrasebook.forCountry(widget.country!)) ?? Phrasebook.langs.firstWhere((l) => l.code == 'hi');
      });
    });
    _tts.setCompletionHandler(() => mounted ? setState(() => _playing = null) : null);
    _tts.setErrorHandler((_) => mounted ? setState(() => _playing = null) : null);
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _say(int i, String text) async {
    setState(() => _playing = i);
    try {
      await _tts.stop();
      await _tts.setLanguage(_lang!.tts);
      await _tts.setSpeechRate(0.42);
      await _tts.speak(text);
    } catch (_) {
      if (mounted) {
        setState(() => _playing = null);
        toast(context, tr('This phone has no voice for this language. Read the pronunciation instead.'));
      }
    }
  }

  Future<void> _pick() async {
    final l = await showModalBottomSheet<PhraseLang>(
      context: context,
      isScrollControlled: true,
      builder: (c) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .7,
        builder: (c, sc) => ListView(controller: sc, children: [
          ListTile(title: Text(tr('Choose language'), style: const TextStyle(fontWeight: FontWeight.w800))),
          for (final l in [...Phrasebook.langs]..sort((a, b) => a.name.compareTo(b.name)))
            ListTile(
              title: Text(isBangla ? l.bn : l.name),
              subtitle: Text(l.countries.take(4).join(', '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.muted, fontSize: 12)),
              trailing: l == _lang ? const Icon(Icons.check_rounded, color: C.primary) : null,
              onTap: () => Navigator.pop(c, l),
            ),
        ]),
      ),
    );
    if (l != null) setState(() => _lang = l);
  }

  @override
  Widget build(BuildContext context) {
    final l = _lang;
    const cats = ['all', 'basics', 'shopping', 'food', 'getting around', 'emergency'];
    const catLabel = {'all': 'All', 'basics': 'Basics', 'shopping': 'Shopping', 'food': 'Food', 'getting around': 'Getting around', 'emergency': 'Emergency'};
    return ScreenScaffold(
      title: tr('Phrasebook'),
      body: !_ready || l == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _pick,
                child: Panel(
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(color: C.tint, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.translate_rounded, color: C.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(isBangla ? l.bn : l.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        Text(trf('Spoken in {0}', [l.countries.take(3).join(', ')]), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.muted, fontSize: 12)),
                      ]),
                    ),
                    Text(tr('Change'), style: const TextStyle(color: C.primary, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 38,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  for (final c in cats)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(label: Text(tr(catLabel[c]!)), selected: _cat == c, onSelected: (_) => setState(() => _cat = c)),
                    ),
                ]),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < Phrasebook.phrases.length; i++)
                if (_cat == 'all' || Phrasebook.phrases[i]['cat'] == _cat)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                    decoration: BoxDecoration(
                      color: Phrasebook.phrases[i]['cat'] == 'emergency' ? const Color(0x22E5484D) : C.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: C.line),
                    ),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(isBangla ? Phrasebook.phrases[i]['bn'] as String : Phrasebook.phrases[i]['en'] as String,
                              style: const TextStyle(color: C.muted, fontSize: 12)),
                          const SizedBox(height: 4),
                          SelectableText(l.rows[i].$1, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                          const SizedBox(height: 2),
                          Text(l.rows[i].$2, style: const TextStyle(color: C.primary, fontStyle: FontStyle.italic, fontSize: 13.5)),
                        ]),
                      ),
                      IconButton(
                        tooltip: tr('Listen'),
                        onPressed: () => _say(i, l.rows[i].$1),
                        icon: Icon(_playing == i ? Icons.graphic_eq_rounded : Icons.volume_up_rounded, color: C.primary),
                      ),
                    ]),
                  ),
              const SizedBox(height: 6),
              Text(tr('Tap the speaker to hear it. Sound uses your phone or browser voice, so a few languages may not play on every device.'),
                  style: const TextStyle(color: C.muted, fontSize: 11.5)),
            ]),
    );
  }
}
