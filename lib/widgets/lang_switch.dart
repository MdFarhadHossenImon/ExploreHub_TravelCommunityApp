import 'package:flutter/material.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../screens/shell.dart';
import 'common.dart';

/// Switch the whole app between English and Bangla. The choice is saved on this device.
Future<void> switchLang(BuildContext context, String v) async {
  if (v == appLang.value) return;
  await setLang(v);
  if (!context.mounted) return;
  // Rebuild every screen in the new language, staying on the current tab.
  goRoot(context, Shell(key: UniqueKey()));
}

/// Two-option toggle: English | বাংলা.
class LangSwitch extends StatelessWidget {
  const LangSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    Widget opt(String code, String label) {
      final on = appLang.value == code;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => switchLang(context, code),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(color: on ? C.primary : Colors.transparent, borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: on ? Colors.white : C.muted)),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: C.tint, borderRadius: BorderRadius.circular(15)),
      child: Row(children: [opt('en', 'English'), opt('bn', 'বাংলা')]),
    );
  }
}
