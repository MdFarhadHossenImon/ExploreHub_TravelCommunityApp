import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Keeps a copy of what the user last saw on this device, so saved places,
/// trip plans, tickets and the feed still open without internet.
class Offline {
  /// false while the device has no connection or the server cannot be reached.
  static final online = ValueNotifier<bool>(true);

  /// Called when the connection comes back, to refresh everything.
  static VoidCallback? onReconnect;

  static SharedPreferences? _p;
  static StreamSubscription<List<ConnectivityResult>>? _sub;

  static Future<void> init({bool watch = true}) async {
    try {
      _p = await SharedPreferences.getInstance();
    } catch (_) {}
    if (!watch) return;
    try {
      final now = await Connectivity().checkConnectivity();
      if (now.every((r) => r == ConnectivityResult.none)) online.value = false;
      _sub ??= Connectivity().onConnectivityChanged.listen((r) {
        final up = r.any((x) => x != ConnectivityResult.none);
        final wasDown = !online.value;
        online.value = up;
        if (up && wasDown) onReconnect?.call();
      });
    } catch (_) {}
  }

  static String _key(String k) {
    String uid = 'anon';
    try {
      uid = Supabase.instance.client.auth.currentUser?.id ?? 'anon';
    } catch (_) {} // Supabase not set up (demo mode or tests)
    return 'off:$uid:$k';
  }

  /// A database error means the server answered; anything else is a network problem.
  static bool isNetwork(Object e) => e is! PostgrestException && e is! AuthException && e is! StorageException;

  static void _save(String k, Object? v) {
    try {
      _p?.setString(_key(k), jsonEncode(v));
    } catch (_) {}
  }

  static Object? _load(String k) {
    final s = _p?.getString(_key(k));
    return s == null ? null : jsonDecode(s);
  }

  static Future<T> _run<T>(String k, Future<T> Function() fetch, T Function(Object) decode) async {
    // No connection at all: answer from the saved copy right away instead of waiting.
    if (!online.value) {
      final c = _load(k);
      if (c != null) return decode(c);
    }
    try {
      final v = await fetch().timeout(const Duration(seconds: 15));
      online.value = true;
      _save(k, v);
      return v;
    } catch (e) {
      if (!isNetwork(e)) rethrow;
      final c = _load(k);
      if (c == null) rethrow;
      online.value = false;
      return decode(c);
    }
  }

  /// Rows from a query; falls back to the saved copy when offline.
  static Future<List<Map<String, dynamic>>> rows(String k, Future<List<Map<String, dynamic>>> Function() fetch) =>
      _run(k, fetch, (c) => [for (final r in c as List) Map<String, dynamic>.from(r as Map)]);

  /// One row (or null); falls back to the saved copy when offline.
  static Future<Map<String, dynamic>?> row(String k, Future<Map<String, dynamic>?> Function() fetch) =>
      _run(k, fetch, (c) => Map<String, dynamic>.from(c as Map));

  /// Read a saved value directly (used by screens that build their own cache, like routes).
  static Object? read(String k) => _load(k);
  static void write(String k, Object? v) => _save(k, v);
}
