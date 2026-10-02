import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:orient/models/server_profile.dart';
import 'package:orient/services/qb_api.dart';

const profile = ServerProfile(
  id: 's',
  name: 'n',
  baseUrl: 'http://qb.local:8080',
  username: 'admin',
  password: 'pw',
);

QbApi apiWith(
    Future<http.Response> Function(http.Request req) handler) {
  return QbApi(profile: profile, client: MockClient(handler));
}

http.Response res(String body, [int code = 200, Map<String, String>? h]) =>
    http.Response(body, code, headers: h ?? {});

void main() {
  group('auth + errors', () {
    test('login stores SID and reports Ok', () async {
      http.Request? sent;
      final api = apiWith((req) async {
        sent = req;
        return res('Ok.', 200, {'set-cookie': 'SID=abc123; path=/'});
      });
      expect(await api.login(), isTrue);
      expect(api.hasSession, isTrue);
      expect(sent!.url.path, '/api/v2/auth/login');
      expect(sent!.bodyFields['username'], 'admin');
      expect(sent!.bodyFields['password'], 'pw');
    });

    test('login failure returns false, banned throws', () async {
      final api = apiWith((req) async => res('Fails.'));
      expect(await api.login(), isFalse);

      final banned = apiWith((req) async => res('Your IP address has been banned'));
      expect(() => banned.login(), throwsA(isA<QbApiException>()));
    });

    test('403 clears session and throws auth failure', () async {
      var n = 0;
      final api = apiWith((req) async {
        n++;
        if (n == 1) return res('Ok.', 200, {'set-cookie': 'SID=x; path=/'});
        return res('Forbidden', 403);
      });
      await api.login();
      expect(api.hasSession, isTrue);
      try {
        await api.appVersion();
        fail('expected throw');
      } on QbApiException catch (e) {
        expect(e.authFailure, isTrue);
        expect(e.statusCode, 403);
      }
      expect(api.hasSession, isFalse);
    });

    test('other status codes throw with body', () async {
      final api = apiWith((req) async => res('nope', 500));
      try {
        await api.appVersion();
        fail('expected throw');
      } on QbApiException catch (e) {
        expect(e.statusCode, 500);
        expect(e.message, contains('nope'));
        expect(e.toString(), contains('nope'));
      }
    });

    test('network errors become QbApiException', () async {
      final api = apiWith((req) async => throw Exception('socket'));
      expect(() => api.appVersion(), throwsA(isA<QbApiException>()));
      expect(() => api.pauseTorrents(['a']),
          throwsA(isA<QbApiException>()));
      expect(() => api.addTorrentFile(Uint8List(1), 'f.torrent'),
          throwsA(isA<QbApiException>()));
      expect(() => api.rssFeeds(), throwsA(isA<QbApiException>()));
    });

    test('logout clears sid even on error', () async {
      var n = 0;
      final api = apiWith((req) async {
        n++;
        if (n == 1) return res('Ok.', 200, {'set-cookie': 'SID=s; path=/'});
        return res('x', 500);
      });
      await api.login();
      try {
        await api.logout();
      } catch (_) {}
      expect(api.hasSession, isFalse);
    });

    test('clearSession drops cookie', () async {
      final api = apiWith((req) async => res('Ok.', 200,
          {'set-cookie': 'SID=s; path=/, other=1'}));
      await api.login();
      api.clearSession();
      expect(api.hasSession, isFalse);
    });
  });

  group('endpoints', () {
    test('versionInfo + supportsStopStart', () async {
      final api = apiWith((req) async {
        if (req.url.path.endsWith('app/version')) return res('5.0.4');
        return res('2.11.2');
      });
      final info = await api.versionInfo();
      expect(info.version, '5.0.4');
      expect(info.api, '2.11.2');
      expect(QbApi.supportsStopStart('2.11.0'), isTrue);
      expect(QbApi.supportsStopStart('2.8.3'), isFalse);
      expect(QbApi.supportsStopStart('3.0.0'), isTrue);
      expect(QbApi.supportsStopStart('garbage'), isFalse);
    });

    test('mainData parses and sends rid', () async {
      http.Request? sent;
      final api = apiWith((req) async {
        sent = req;
        return res(jsonEncode({
          'rid': 7,
          'full_update': true,
          'torrents': {
            'h': {'name': 'x'}
          },
        }));
      });
      final u = await api.mainData(3);
      expect(u.rid, 7);
      expect(sent!.url.queryParameters['rid'], '3');
      expect(u.torrents.keys, ['h']);
    });

    test('torrentData parses peers', () async {
      final api = apiWith((req) async => res(jsonEncode({
            'rid': 2,
            'peers': {
              'a:1': {'ip': 'a', 'port': 1}
            },
          })));
      final u = await api.torrentData('h', 0);
      expect(u.peers.single.address, 'a:1');
    });

    test('properties/contents/trackers decode', () async {
      final api = apiWith((req) async {
        if (req.url.path.endsWith('properties')) {
          return res('{"save_path": "/x"}');
        }
        if (req.url.path.endsWith('contents')) {
          return res('[{"name": "f", "size": 1}]');
        }
        return res('[{"url": "u", "status": 2}]');
      });
      expect((await api.torrentProperties('h')).savePath, '/x');
      expect((await api.torrentContents('h')).single.name, 'f');
      expect((await api.torrentTrackers('h')).single.url, 'u');
    });

    test('malformed json handled', () async {
      final api = apiWith((req) async => res('[1,2]'));
      final u = await api.mainData(0);
      expect(u.rid, 0);
      final api2 = apiWith((req) async => res('{"a":1}'));
      expect(await api2.torrentContents('h'), isEmpty);
    });

    test('write verbs send form fields', () async {
      final bodies = <String, Map<String, String>>{};
      final api = apiWith((req) async {
        bodies[req.url.path] = req.bodyFields;
        return res('Ok.');
      });
      await api.pauseTorrents(['a', 'b']);
      await api.pauseTorrents(['a'], modern: true);
      await api.resumeTorrents(['a']);
      await api.resumeTorrents(['a'], modern: true);
      await api.deleteTorrents(['a'], deleteFiles: true);
      await api.recheckTorrents(['a']);
      await api.reannounceTorrents(['a']);
      await api.setCategory(['a'], 'iso');
      await api.addTags(['a'], ['t1', 't2']);
      await api.removeTags(['a'], ['t1']);
      await api.setLocation(['a'], '/x');
      await api.rename('h', 'new');
      await api.topPrio(['a']);
      await api.bottomPrio(['a']);
      await api.increasePrio(['a']);
      await api.decreasePrio(['a']);
      await api.setDownloadLimit(['a'], 100);
      await api.setUploadLimit(['a'], 50);
      await api.setShareLimits(['a'], ratio: 1.5, seedingTime: 60);
      await api.toggleSequential(['a']);
      await api.toggleFirstLastPiece(['a']);
      await api.setForceStart(['a'], true);
      await api.setSuperSeeding(['a'], false);
      await api.setAutoManagement(['a'], true);
      await api.setFilePriority('h', [1, 2], 6);
      await api.addTrackers('h', ['u1', 'u2']);
      await api.removeTrackers('h', ['u1']);
      await api.editTracker('h', 'old', 'new');
      await api.createCategory('cat', savePath: '/p');
      await api.editCategory('cat', '/p2');
      await api.removeCategories(['cat']);
      await api.createTags(['t']);
      await api.deleteTags(['t']);
      await api.setGlobalDownloadLimit(1);
      await api.setGlobalUploadLimit(2);
      await api.toggleSpeedLimitsMode();
      await api.setPreferences({'a': 1});

      expect(bodies['/api/v2/torrents/pause']!['hashes'], 'a|b');
      expect(bodies['/api/v2/torrents/stop']!['hashes'], 'a');
      expect(bodies['/api/v2/torrents/resume']!['hashes'], 'a');
      expect(bodies['/api/v2/torrents/start']!['hashes'], 'a');
      expect(bodies['/api/v2/torrents/delete']!['deleteFiles'], 'true');
      expect(bodies['/api/v2/torrents/setCategory']!['category'], 'iso');
      expect(bodies['/api/v2/torrents/addTags']!['tags'], 't1,t2');
      expect(bodies['/api/v2/torrents/setDownloadLimit']!['limit'], '100');
      expect(bodies['/api/v2/torrents/setShareLimits']!['ratioLimit'], '1.5');
      expect(bodies['/api/v2/torrents/filePrio']!['id'], '1|2');
      expect(bodies['/api/v2/torrents/addTrackers']!['urls'], 'u1\nu2');
      expect(bodies['/api/v2/torrents/editTracker']!['newUrl'], 'new');
      expect(bodies['/api/v2/app/createCategory']!['category'], 'cat');
      expect(bodies['/api/v2/app/editCategory']!['savePath'], '/p2');
      expect(bodies['/api/v2/app/removeCategories']!['categories'], 'cat');
      expect(bodies['/api/v2/app/createTags']!['tags'], 't');
      expect(bodies['/api/v2/app/deleteTags']!['tags'], 't');
      expect(bodies['/api/v2/transfer/setDownloadLimit']!['limit'], '1');
      expect(bodies['/api/v2/transfer/setUploadLimit']!['limit'], '2');
      expect(bodies['/api/v2/app/setPreferences']!['json'], '{"a":1}');
      expect(bodies['/api/v2/torrents/rename']!['name'], 'new');
      expect(bodies['/api/v2/torrents/setLocation']!['location'], '/x');
      expect(bodies['/api/v2/torrents/setForceStart']!['value'], 'true');
      expect(bodies['/api/v2/torrents/setSuperSeeding']!['value'], 'false');
      expect(bodies['/api/v2/torrents/setAutoManagement']!['enable'], 'true');
      expect(bodies.containsKey('/api/v2/transfer/toggleSpeedLimitsMode'),
          isTrue);
      for (final p in [
        'recheck', 'reannounce', 'topPrio', 'bottomPrio',
        'increasePrio', 'decreasePrio', 'toggleSequentialDownload',
        'toggleFirstLastPiecePrio', 'removeTrackers', 'removeTags',
      ]) {
        expect(bodies.keys.any((k) => k.endsWith(p)), isTrue,
            reason: 'missing $p');
      }
    });

    test('appPreferences decodes map', () async {
      final api = apiWith((req) async => res('{"a": 1}'));
      expect((await api.appPreferences())['a'], 1);
      final bad = apiWith((req) async => res('[]'));
      expect(await bad.appPreferences(), isEmpty);
    });

    test('speedLimitsMode parses int', () async {
      final api = apiWith((req) async => res('1'));
      expect(await api.speedLimitsMode(), 1);
      final bad = apiWith((req) async => res('x'));
      expect(await bad.speedLimitsMode(), 0);
    });

    test('addTorrentUrls sends optional fields', () async {
      Map<String, String>? body;
      final api = apiWith((req) async {
        body = req.bodyFields;
        return res('Ok.');
      });
      await api.addTorrentUrls('magnet:?x\nhttps://t/f.torrent',
          savePath: '/dl',
          category: 'iso',
          tags: ['a'],
          paused: true,
          sequential: true,
          firstLastPiece: true,
          contentLayout: 'Subfolder');
      expect(body!['urls'], contains('magnet:'));
      expect(body!['savepath'], '/dl');
      expect(body!['category'], 'iso');
      expect(body!['tags'], 'a');
      expect(body!['paused'], 'true');
      expect(body!['sequentialDownload'], 'true');
      expect(body!['firstLastPiecePrio'], 'true');
      expect(body!['contentLayout'], 'Subfolder');

      await api.addTorrentUrls('magnet:?y');
      expect(body!.containsKey('savepath'), isFalse);
    });

    test('addTorrentFile sends multipart', () async {
      var saw = false;
      final api = apiWith((req) async {
        saw = req.headers['content-type']?.contains('multipart') ?? false;
        return res('Ok.');
      });
      await api.addTorrentFile(Uint8List.fromList([1, 2, 3]), 'f.torrent',
          savePath: '/d', category: 'c', tags: ['t'], paused: false);
      expect(saw, isTrue);
    });

    test('addTorrentFile surfaces errors', () async {
      final api = apiWith((req) async => res('bad', 500));
      expect(() => api.addTorrentFile(Uint8List(1), 'f.torrent'),
          throwsA(isA<QbApiException>()));
    });

    test('rss endpoints', () async {
      final bodies = <String>[];
      final api = apiWith((req) async {
        bodies.add(req.url.path +
            (req.method == 'POST' && req.bodyFields.isNotEmpty
                ? '?${req.bodyFields}'
                : ''));
        if (req.url.path.endsWith('rss/items')) {
          return res(jsonEncode({
            'Feed': {'url': 'u', 'articles': []}
          }));
        }
        return res('Ok.');
      });
      final root = await api.rssFeeds();
      expect(root.children.containsKey('Feed'), isTrue);
      await api.rssAddFeed('u', 'p');
      await api.rssRemoveFeed('p');
      await api.rssRefreshItem('p');
      await api.rssMarkAsRead('p', 'art');
      await api.rssMarkAsRead('p');
      expect(bodies.any((b) => b.contains('articleId')), isTrue);
    });
  });

  test('close disposes client', () {
    final api = apiWith((req) async => res(''));
    api.close();
  });
}
