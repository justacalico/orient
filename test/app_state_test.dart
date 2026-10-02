import 'package:flutter_test/flutter_test.dart';
import 'package:orient/app_state.dart';
import 'package:orient/models/torrent_detail.dart';
import 'package:orient/models/transfer.dart';
import 'package:orient/services/qb_api.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:orient/services/server_store.dart';
import 'package:orient/services/settings.dart';
import 'package:orient/models/rss.dart';
import 'package:orient/models/server_profile.dart';

import 'helpers/fakes.dart';

Map<String, dynamic> tJson(String name,
        {String state = 'downloading',
        double progress = 0.4,
        int dlspeed = 0,
        int upspeed = 0,
        String category = '',
        String tags = '',
        int eta = 100,
        int size = 1000,
        int priority = 1,
        double ratio = 0.5,
        int addedOn = 100}) =>
    {
      'name': name,
      'state': state,
      'progress': progress,
      'dlspeed': dlspeed,
      'upspeed': upspeed,
      'category': category,
      'tags': tags,
      'eta': eta,
      'size': size,
      'priority': priority,
      'ratio': ratio,
      'added_on': addedOn,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('connection', () {
    test('connect -> connected, server info stored', () async {
      final (state: s, api: api) = await makeConnectedState();
      expect(s.phase, ConnectionPhase.connected);
      expect(s.isConnected, isTrue);
      expect(s.serverVersion, '5.0.0');
      expect(s.webApiVersion, '2.11.0');
      expect(s.modernVerbs, isTrue);
      expect(s.store.lastServerId, 'srv1');
      expect(api.calls, contains('login'));
      s.dispose();
    });

    test('connect with bad credentials fails', () async {
      SharedPreferences.setMockInitialValues({});
      final store = await ServerStore.load();
      await store.upsert(testProfile);
      final s = AppState(
          settings: Settings(),
          store: store,
          autoPoll: false,
          apiFactory: (p) => FakeQbApi(p)..loginResult = false);
      await s.connect(testProfile);
      expect(s.phase, ConnectionPhase.failed);
      expect(s.lastError, contains('Wrong'));
      s.dispose();
    });

    test('connect network error fails', () async {
      SharedPreferences.setMockInitialValues({});
      final store = await ServerStore.load();
      await store.upsert(testProfile);
      final s = AppState(
          settings: Settings(),
          store: store,
          autoPoll: false,
          apiFactory: (p) => FakeQbApi(p)
            ..loginError = const QbApiException('down'));
      await s.connect(testProfile);
      expect(s.phase, ConnectionPhase.failed);
      expect(s.lastError, 'down');
      s.dispose();

      // non-QbApiException path
      final s2 = AppState(
          settings: Settings(),
          store: store,
          autoPoll: false,
          apiFactory: (p) => FakeQbApi(p)..loginError = StateError('x'));
      await s2.connect(testProfile);
      expect(s2.phase, ConnectionPhase.failed);
      expect(s2.lastError, contains('Bad state'));
      s2.dispose();
    });

    test('old api verbs when api < 2.11', () async {
      SharedPreferences.setMockInitialValues({});
      final store = await ServerStore.load();
      await store.upsert(testProfile);
      final s = AppState(
          settings: Settings(),
          store: store,
          autoPoll: false,
          apiFactory: (p) =>
              FakeQbApi(p)..apiVersionResponse = '2.8.3');
      await s.connect(testProfile);
      expect(s.modernVerbs, isFalse);
      s.dispose();
    });

    test('disconnect clears data', () async {
      final (state: s, api: api) = await makeConnectedState();
      api.mainDataResponses.add(fullUpdate(torrents: {
        'h1': tJson('a'),
      }));
      await s.refreshOnce();
      expect(s.torrents, isNotEmpty);
      await s.disconnect();
      expect(s.phase, ConnectionPhase.disconnected);
      expect(s.torrents, isEmpty);
      expect(api.calls, contains('logout'));
      s.dispose();
    });
  });

  group('sync', () {
    test('full update populates maps, removals clear', () async {
      final (state: s, api: api) = await makeConnectedState();
      api.mainDataResponses.add(fullUpdate(
        torrents: {'h1': tJson('a'), 'h2': tJson('b', state: 'uploading')},
        categories: {
          'iso': {'savePath': '/dl'}
        },
        tags: ['x'],
      ));
      await s.refreshOnce();
      expect(s.torrents.length, 2);
      expect(s.categories['iso']!.savePath, '/dl');
      expect(s.tags, contains('x'));
      expect(s.dlHistory, isNotEmpty);

      api.mainDataResponses.add(MainDataUpdate(
        rid: 2,
        torrentsRemoved: ['h1'],
        categoriesRemoved: ['iso'],
        tagsRemoved: ['x'],
        trackersRemoved: ['t'],
      ));
      await s.refreshOnce();
      expect(s.torrents.keys, ['h2']);
      expect(s.categories, isEmpty);
      expect(s.tags, isEmpty);
      s.dispose();
    });

    test('partial update merges into existing torrent', () async {
      final (state: s, api: api) = await makeConnectedState();
      api.mainDataResponses.add(fullUpdate(torrents: {'h1': tJson('a')}));
      await s.refreshOnce();
      api.mainDataResponses.add(MainDataUpdate(
        rid: 2,
        torrents: {
          'h1': {'progress': 0.9},
          'h2': tJson('new'),
        },
      ));
      await s.refreshOnce();
      expect(s.torrents['h1']!.progress, 0.9);
      expect(s.torrents['h1']!.name, 'a');
      expect(s.torrents['h2']!.name, 'new');
      s.dispose();
    });

    test('relogin on auth failure', () async {
      SharedPreferences.setMockInitialValues({});
      final store = await ServerStore.load();
      await store.upsert(testProfile);
      final api = FakeQbApi(testProfile);
      var failAuth = true;
      // FakeQbApi.mainData doesn't support throwing; use a wrapper subclass.
      final throwing = _AuthFailApi(testProfile, () => failAuth);
      final s = AppState(
        settings: Settings(),
        store: store,
        autoPoll: false,
        apiFactory: (p) => throwing,
      );
      await s.connect(testProfile);
      expect(s.isConnected, isTrue);
      await s.refreshOnce();
      expect(api.calls, isEmpty); // unused
      expect(throwing.loginCalls, 3); // initial + relogin per failed sync
      failAuth = false;
      throwing.responses.add(fullUpdate());
      await s.refreshOnce();
      expect(s.lastError, isNull);
      s.dispose();
    });
  });

  group('filters and sort', () {
    Future<AppState> seeded() async {
      final (state: s, api: api) = await makeConnectedState();
      api.mainDataResponses.add(fullUpdate(torrents: {
        'dl': tJson('downloader',
            state: 'downloading', dlspeed: 100, category: 'iso', tags: 'a'),
        'up': tJson('seeder', state: 'uploading', upspeed: 50, progress: 1.0),
        'stop': tJson('paused', state: 'stoppedDL', priority: 5),
        'err': tJson('broken', state: 'error'),
      }, categories: {
        'iso': {}
      }, tags: [
        'a'
      ]));
      await s.refreshOnce();
      return s;
    }

    test('status filters', () async {
      final s = await seeded();
      s.setFilter(TorrentFilter.all);
      expect(s.visibleTorrents.length, 4);
      s.setFilter(TorrentFilter.downloading);
      expect(s.visibleTorrents.single.name, 'downloader');
      s.setFilter(TorrentFilter.seeding);
      expect(s.visibleTorrents.single.name, 'seeder');
      s.setFilter(TorrentFilter.completed);
      expect(s.visibleTorrents.single.name, 'seeder');
      s.setFilter(TorrentFilter.paused);
      expect(s.visibleTorrents.single.name, 'paused');
      s.setFilter(TorrentFilter.active);
      expect(s.visibleTorrents.length, 2);
      s.setFilter(TorrentFilter.inactive);
      expect(s.visibleTorrents.length, 2);
      s.setFilter(TorrentFilter.errored);
      expect(s.visibleTorrents.single.name, 'broken');
      s.dispose();
    });

    test('category, tag, tracker, search filters', () async {
      final s = await seeded();
      s.setCategory('iso');
      expect(s.visibleTorrents.single.name, 'downloader');
      s.setCategory(null);
      s.setTag('a');
      expect(s.visibleTorrents.single.name, 'downloader');
      s.setTag('nope');
      expect(s.visibleTorrents, isEmpty);
      s.setTag(null);
      s.setTracker('udp://t');
      expect(s.visibleTorrents, isEmpty); // no tracker mapping
      s.trackerToHashes['udp://t'] = ['dl'];
      expect(s.visibleTorrents.single.name, 'downloader');
      s.setTracker(null);
      s.setSearch('PAUS');
      expect(s.visibleTorrents.single.name, 'paused');
      s.setSearch('');
      s.dispose();
    });

    test('sort orders', () async {
      final s = await seeded();
      for (final sort in TorrentSort.values) {
        s.setSort(sort, descending: false);
        expect(s.visibleTorrents, isNotEmpty);
        s.setSort(sort, descending: true);
        expect(s.visibleTorrents, isNotEmpty);
      }
      // name sort ascending puts 'broken' first
      s.setSort(TorrentSort.name, descending: false);
      expect(s.visibleTorrents.first.name, 'broken');
      // toggling same sort flips direction
      s.setSort(TorrentSort.name);
      expect(s.visibleTorrents.first.name, 'seeder');
      s.dispose();
    });

    test('selection', () async {
      final s = await seeded();
      s.select('dl');
      expect(s.selected, contains('dl'));
      s.select('dl');
      expect(s.selected, isEmpty);
      s.select('dl', toggle: false);
      s.selectOnly('up');
      expect(s.selected, {'up'});
      s.clearSelection();
      expect(s.selected, isEmpty);
      s.dispose();
    });
  });

  group('actions', () {
    Future<({AppState s, FakeQbApi api})> armed() async {
      final (state: s, api: api) = await makeConnectedState();
      api.mainDataResponses
          .add(fullUpdate(torrents: {'h1': tJson('a')}));
      await s.refreshOnce();
      s.select('h1');
      return (s: s, api: api);
    }

    test('all torrent actions call through and resync', () async {
      final r = await armed();
      await r.s.pauseSelected();
      await r.s.resumeSelected();
      await r.s.deleteSelected(deleteFiles: true);
      await r.s.recheckSelected();
      await r.s.reannounceSelected();
      await r.s.setCategoryFor(['h1'], 'c');
      await r.s.addTagsFor(['h1'], ['t']);
      await r.s.removeTagsFor(['h1'], ['t']);
      await r.s.createCategory('nc', '/p');
      await r.s.editCategory('nc', '/p2');
      await r.s.removeCategories(['nc']);
      await r.s.createTags(['nt']);
      await r.s.deleteTags(['nt']);
      await r.s.setLocationFor(['h1'], '/x');
      await r.s.renameTorrent('h1', 'n');
      await r.s.setDownloadLimitFor(['h1'], 1);
      await r.s.setUploadLimitFor(['h1'], 2);
      await r.s.setShareLimitsFor(['h1'], ratio: 1.5, seedingTime: 60);
      await r.s.toggleSequentialFor(['h1']);
      await r.s.toggleFirstLastFor(['h1']);
      await r.s.setForceStartFor(['h1'], true);
      await r.s.setAutoTmmFor(['h1'], true);
      await r.s.topPrioFor(['h1']);
      await r.s.bottomPrioFor(['h1']);
      await r.s.increasePrioFor(['h1']);
      await r.s.decreasePrioFor(['h1']);
      await r.s.addTorrentUrls('magnet:?x', savePath: '/d', category: 'c');
      await r.s.addTorrentFile([1, 2], 'f.torrent');
      await r.s.toggleAltSpeed();
      await r.s.setGlobalDlLimit(10);
      await r.s.setGlobalUlLimit(20);
      await r.s.setPreference('k', 'v');
      await r.s.addTrackers('h1', ['u']);
      await r.s.removeTrackers('h1', ['u']);
      await r.s.setFilePriority('h1', [0], 6);

      expect(r.api.calls, containsAll([
        'pause:modern',
        'resume:modern',
        'delete:true',
        'recheck',
        'reannounce',
        'setCategory:c',
        'addTags:t',
        'removeTags:t',
        'createCategory:nc',
        'editCategory:nc',
        'removeCategories:nc',
        'createTags:nt',
        'deleteTags:nt',
        'setLocation:/x',
        'rename:n',
        'dlLimit:1',
        'ulLimit:2',
        'shareLimits:1.5:60',
        'seq',
        'firstLast',
        'forceStart:true',
        'autoTmm:true',
        'topPrio',
        'bottomPrio',
        'increasePrio',
        'decreasePrio',
        'altSpeed',
        'gdl:10',
        'gul:20',
        'prefs:k',
      ]));
      expect(r.api.calls.any((c) => c.startsWith('addUrls:')), isTrue);
      expect(r.api.calls, contains('addFile:f.torrent'));
      r.s.dispose();
    });

    test('action failure surfaces error and rethrows', () async {
      final r = await armed();
      r.api.failNextCall = true;
      await expectLater(
          r.s.pauseSelected(), throwsA(isA<QbApiException>()));
      expect(r.s.lastError, 'boom');
      r.s.dispose();
    });

    test('actions no-op without api', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppState(
          settings: Settings(),
          store: await ServerStore.load(),
          autoPoll: false);
      await s.pauseSelected();
      await s.refreshOnce();
      await s.loadDetail('x');
      await s.refreshRss();
      await s.rssAdd('u', 'p');
      await s.rssRemove('p');
      await s.rssRefresh('p');
      await s.rssMarkRead('p');
      await s.setFilePriority('h', [0], 1);
      s.dispose();
    });
  });

  group('detail', () {
    test('loadDetail populates caches and peers', () async {
      final (state: s, api: api) = await makeConnectedState();
      api.mainDataResponses.add(fullUpdate(torrents: {'h1': tJson('a')}));
      api.props['h1'] = const TorrentProperties(savePath: '/dl');
      api.files['h1'] = const [
        TorrentFile(
            index: 0,
            name: 'f',
            size: 10,
            progress: 1,
            priority: FilePriority.normal,
            isSeed: false)
      ];
      api.trackersByHash['h1'] = const [
        TorrentTracker(url: 'u', status: TrackerStatus.working)
      ];
      api.peerResponses.add(TorrentDataUpdate.fromJson({
        'rid': 1,
        'peers': {
          '1.1.1.1:5': {'ip': '1.1.1.1', 'port': 5}
        }
      }));
      await s.refreshOnce();
      s.detailHash = 'h1';
      await s.loadDetail('h1');
      expect(s.detailProperties['h1']!.savePath, '/dl');
      expect(s.detailFiles['h1']!.single.name, 'f');
      expect(s.detailTrackers['h1']!.single.url, 'u');
      expect(s.detailPeers['h1']!.single.address, '1.1.1.1:5');
      s.closeDetail();
      expect(s.detailHash, isNull);
      s.dispose();
    });

    test('peer incremental merge', () async {
      final (state: s, api: api) = await makeConnectedState();
      api.mainDataResponses.add(fullUpdate(torrents: {'h1': tJson('a')}));
      await s.refreshOnce();
      s.detailHash = 'h1';
      // first full
      api.peerResponses.add(TorrentDataUpdate.fromJson({
        'rid': 1,
        'full_update': true,
        'peers': {
          'a:1': {'ip': 'a', 'port': 1}
        }
      }));
      // then incremental add + remove
      api.peerResponses.add(TorrentDataUpdate.fromJson({
        'rid': 2,
        'peers': {
          'b:2': {'ip': 'b', 'port': 2}
        },
        'peers_removed': ['a:1'],
      }));
      await s.loadDetail('h1');
      expect(s.detailPeers['h1']!.map((p) => p.address), ['a:1']);
      await s.refreshOnce(); // triggers incremental peer refresh
      await Future.delayed(Duration.zero);
      expect(s.detailPeers['h1']!.map((p) => p.address), ['b:2']);
      s.dispose();
    });

    test('removed torrent clears detail', () async {
      final (state: s, api: api) = await makeConnectedState();
      api.mainDataResponses.add(fullUpdate(torrents: {'h1': tJson('a')}));
      await s.refreshOnce();
      s.openDetail('h1');
      s.select('h1');
      api.mainDataResponses
          .add(MainDataUpdate(rid: 9, torrentsRemoved: ['h1']));
      await s.refreshOnce();
      expect(s.detailHash, isNull);
      expect(s.selected, isEmpty);
      s.dispose();
    });
  });

  group('rss', () {
    test('refresh + feed ops', () async {
      final (state: s, api: api) = await makeConnectedState();
      api.rssResult = RssFeedNode.fromFeedsJson({
        'F': {
          'url': 'u',
          'articles': [
            {'id': '1', 'title': 't'}
          ]
        }
      });
      await s.refreshRss();
      expect(s.rssRoot!.flatten().single.feed.name, 'F');
      await s.rssAdd('u2', 'p');
      await s.rssRemove('p');
      await s.rssRefresh('p');
      await s.rssMarkRead('p', 'a');
      expect(api.calls, containsAll([
        'rssAdd:u2',
        'rssRemove:p',
        'rssRefresh:p',
        'rssRead:p'
      ]));
      s.dispose();
    });
  });

  group('poll timer', () {
    test('autoPoll restarts on settings change', () async {
      SharedPreferences.setMockInitialValues({});
      final store = await ServerStore.load();
      await store.upsert(testProfile);
      FakeQbApi? api;
      final s = AppState(
        settings: Settings()..pollInterval = const Duration(milliseconds: 50),
        store: store,
        autoPoll: true,
        apiFactory: (p) => api = FakeQbApi(p),
      );
      await s.connect(testProfile);
      await Future.delayed(const Duration(milliseconds: 160));
      expect(api!.mainDataCalls, greaterThan(0));
      s.applySettings();
      await Future.delayed(const Duration(milliseconds: 120));
      s.dispose();
    });
  });

  test('applySettings notifies', () async {
    final (state: s, api: _) = await makeConnectedState();
    var notified = 0;
    s.addListener(() => notified++);
    s.applySettings();
    expect(notified, 1);
    s.dispose();
  });

  group('coverage extras', () {
    test('default api factory and api getter', () async {
      SharedPreferences.setMockInitialValues({});
      final store = await ServerStore.load();
      final s = AppState(
          settings: Settings(), store: store, autoPoll: false);
      expect(s.api, isNull);
      // connect with the real QbApi -> network fails fast on localhost
      await store.upsert(const ServerProfile(
          id: 'x', name: 'n', baseUrl: 'http://127.0.0.1:1'));
      await s.connect(s.servers.first);
      expect(s.phase, ConnectionPhase.failed);
      s.dispose();
    });

    test('api getter returns active client', () async {
      final r = await makeConnectedState();
      expect(r.state.api, isNotNull);
      r.state.dispose();
    });

    test('refreshOnce restores connected phase after failure', () async {
      final r = await makeConnectedState();
      r.state.phase = ConnectionPhase.failed;
      r.api.mainDataResponses.add(fullUpdate());
      await r.state.refreshOnce();
      expect(r.state.phase, ConnectionPhase.connected);
      r.state.dispose();
    });

    test('non-auth errors set lastError', () async {
      final r = await makeConnectedState();
      r.api.mainDataError = const QbApiException('server busy');
      await r.state.refreshOnce();
      expect(r.state.lastError, 'server busy');
      r.api.mainDataError = StateError('generic');
      await r.state.refreshOnce();
      expect(r.state.lastError, contains('Bad state'));
      r.state.dispose();
    });

    test('failed relogin reports error', () async {
      final r = await makeConnectedState();
      r.api.mainDataError =
          const QbApiException('forbidden', statusCode: 403, authFailure: true);
      r.api.reloginError = const QbApiException('down');
      await r.state.refreshOnce();
      expect(r.state.lastError, 'Re-authentication failed');
      r.state.dispose();
    });

    test('speed history trims at limit', () async {
      final r = await makeConnectedState();
      for (var i = 0; i < 125; i++) {
        r.api.mainDataResponses.add(MainDataUpdate(
            rid: i + 1,
            serverState: {'dl_info_speed': i, 'up_info_speed': i * 2}));
        await r.state.refreshOnce();
      }
      expect(r.state.dlHistory.length, AppState.speedHistoryLength);
      expect(r.state.dlHistory.last, 124);
      r.state.dispose();
    });

    test('loadDetail failure sets lastError', () async {
      final r = await makeConnectedState();
      r.api.mainDataResponses.add(fullUpdate(torrents: {'h': tJson('a')}));
      await r.state.refreshOnce();
      r.api.detailError = const QbApiException('detail down');
      await r.state.loadDetail('h');
      expect(r.state.lastError, contains('detail down'));
      r.state.dispose();
    });

    test('openDetail triggers async load', () async {
      final r = await makeConnectedState();
      r.api.mainDataResponses.add(fullUpdate(torrents: {'h': tJson('a')}));
      await r.state.refreshOnce();
      r.state.openDetail('h');
      await Future.delayed(const Duration(milliseconds: 50));
      expect(r.state.detailHash, 'h');
      expect(r.api.calls.any((c) => c == 'properties:h'), isTrue);
      r.state.dispose();
    });
  });
}

class _AuthFailApi extends FakeQbApi {
  _AuthFailApi(super.profile, this.shouldFail);

  final bool Function() shouldFail;
  int loginCalls = 0;
  final List<MainDataUpdate> responses = [];

  @override
  Future<bool> login() async {
    loginCalls++;
    return true;
  }

  @override
  Future<MainDataUpdate> mainData(int rid) async {
    if (shouldFail()) {
      throw const QbApiException('forbidden',
          statusCode: 403, authFailure: true);
    }
    if (responses.isNotEmpty) return responses.removeAt(0);
    return MainDataUpdate(rid: rid + 1);
  }
}

