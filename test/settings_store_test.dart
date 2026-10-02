import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orient/models/server_profile.dart';
import 'package:orient/services/server_store.dart';
import 'package:orient/services/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Settings', () {
    test('defaults and round trip', () async {
      SharedPreferences.setMockInitialValues({});
      var s = await Settings.load();
      expect(s.themeMode, ThemeMode.system);
      expect(s.accentColor, OrientAccents.blue);
      expect(s.pollInterval, const Duration(seconds: 2));
      expect(s.confirmDeletes, isTrue);
      expect(s.defaultTorrentFilter, TorrentFilter.all);

      s.themeMode = ThemeMode.dark;
      s.accentColor = OrientAccents.teal;
      s.pollInterval = const Duration(seconds: 5);
      s.confirmDeletes = false;
      s.showSpeedInTitle = true;
      s.defaultTorrentFilter = TorrentFilter.seeding;
      await s.save();

      s = await Settings.load();
      expect(s.themeMode, ThemeMode.dark);
      expect(s.accentColor, OrientAccents.teal);
      expect(s.pollInterval, const Duration(seconds: 5));
      expect(s.confirmDeletes, isFalse);
      expect(s.showSpeedInTitle, isTrue);
      expect(s.defaultTorrentFilter, TorrentFilter.seeding);
    });

    test('ignores invalid persisted values', () async {
      SharedPreferences.setMockInitialValues({
        'themeMode': 'bogus',
        'pollIntervalMs': 10,
        'defaultTorrentFilter': 'bogus',
      });
      final s = await Settings.load();
      expect(s.themeMode, ThemeMode.system);
      expect(s.pollInterval, const Duration(seconds: 2));
      expect(s.defaultTorrentFilter, TorrentFilter.all);
    });

    test('accents and filter labels', () {
      expect(OrientAccents.all.length, greaterThan(4));
      for (final f in TorrentFilter.values) {
        expect(f.label, isNotEmpty);
      }
    });
  });

  group('ServerStore', () {
    test('upsert, remove, lastServer', () async {
      SharedPreferences.setMockInitialValues({});
      final store = await ServerStore.load();
      expect(store.servers, isEmpty);

      const a = ServerProfile(id: 'a', name: 'A', baseUrl: 'http://a');
      const b = ServerProfile(id: 'b', name: 'B', baseUrl: 'http://b');
      await store.upsert(a);
      await store.upsert(b);
      expect(store.servers.length, 2);

      // upsert replaces same id
      await store.upsert(a.copyWith(name: 'A2'));
      expect(store.servers.firstWhere((s) => s.id == 'a').name, 'A2');
      expect(store.servers.length, 2);

      await store.setLastServer('a');
      expect(store.lastServerId, 'a');
      await store.setLastServer(null);
      expect(store.lastServerId, isNull);
      await store.setLastServer('b');

      await store.remove('b');
      expect(store.servers.length, 1);
      expect(store.lastServerId, isNull);

      await store.remove('a');
      expect(store.servers, isEmpty);
    });

    test('handles empty persisted list', () async {
      SharedPreferences.setMockInitialValues({'servers': <String>[]});
      final store = await ServerStore.load();
      expect(store.servers, isEmpty);
    });
  });
}
