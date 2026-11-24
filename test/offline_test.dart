import 'dart:io';
import 'package:explorehub/data/offline.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Offline.online.value = true;
    await Offline.init(watch: false);
  });

  test('saved copy is used when the network fails', () async {
    final live = await Offline.rows('trips', () async => [
          {'id': 't1', 'title': 'Sajek', 'stops': [{'n': 1}]}
        ]);
    expect(live.first['title'], 'Sajek');

    final cached = await Offline.rows('trips', () async => throw const SocketException('no internet'));
    expect(cached.first['title'], 'Sajek');
    expect((cached.first['stops'] as List).first['n'], 1);
    expect(Offline.online.value, isFalse);
  });

  test('offline answers from the saved copy without calling the server', () async {
    await Offline.rows('bookings', () async => [{'id': 'b1'}]);
    Offline.online.value = false;
    var called = false;
    final r = await Offline.rows('bookings', () async {
      called = true;
      return [];
    });
    expect(called, isFalse);
    expect(r.single['id'], 'b1');
  });

  test('server errors are not hidden by the cache', () async {
    await Offline.rows('posts', () async => [{'id': 'p1'}]);
    expect(() => Offline.rows('posts', () async => throw const PostgrestException(message: 'denied')), throwsA(isA<PostgrestException>()));
  });

  test('no saved copy: the network error is passed on', () async {
    expect(() => Offline.rows('nothing', () async => throw const SocketException('x')), throwsA(isA<SocketException>()));
  });

  test('single rows round-trip', () async {
    await Offline.row('profile', () async => {'name': 'Asif'});
    final r = await Offline.row('profile', () async => throw const SocketException('x'));
    expect(r?['name'], 'Asif');
  });
}
