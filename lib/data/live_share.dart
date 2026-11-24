import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'backend.dart';

/// Shares your location with buddies while the app is open, until the time you chose.
class LiveShare {
  static final until = ValueNotifier<DateTime?>(null);
  static final me = ValueNotifier<Position?>(null);
  static Timer? _timer;

  static bool get sharing => until.value != null && until.value!.isAfter(DateTime.now());

  /// Ask for permission and read the current position. Returns null if denied or unavailable.
  static Future<Position?> locate() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) return null;
      final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)));
      me.value = pos;
      return pos;
    } catch (e) {
      debugPrint('locate failed: $e');
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) me.value = last;
        return last;
      } catch (_) {
        return null;
      }
    }
  }

  /// Start sharing for [d]. Returns false when location permission was refused.
  static Future<bool> start(Duration d) async {
    final pos = await locate();
    if (pos == null) return false;
    until.value = DateTime.now().add(d);
    await _push(pos);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 45), (_) async {
      if (!sharing) return stop();
      final p = await locate();
      if (p != null) await _push(p);
    });
    return true;
  }

  static Future<void> _push(Position p) async {
    if (!Backend.on || Backend.uid == null) return;
    try {
      await Backend.shareLocation(p.latitude, p.longitude, p.accuracy, until.value!);
    } catch (_) {}
  }

  static Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    until.value = null;
    if (Backend.on && Backend.uid != null) {
      try {
        await Backend.stopSharingLocation();
      } catch (_) {}
    }
  }
}
