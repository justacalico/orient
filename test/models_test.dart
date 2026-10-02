import 'package:flutter_test/flutter_test.dart';
import 'package:orient/models/rss.dart';
import 'package:orient/models/server_profile.dart';
import 'package:orient/models/torrent.dart';
import 'package:orient/models/torrent_detail.dart';
import 'package:orient/models/transfer.dart';

void main() {
  group('ServerProfile', () {
    test('normalizes base urls', () {
      expect(ServerProfile.normalizeBaseUrl('192.168.1.5:8080'),
          'http://192.168.1.5:8080');
      expect(ServerProfile.normalizeBaseUrl('https://nas.local/qbit/'),
          'https://nas.local/qbit');
      expect(ServerProfile.normalizeBaseUrl(''), '');
      expect(
          ServerProfile.normalizeBaseUrl('https://h:8080/p?q=1#f'),
          'https://h:8080/p');
    });

    test('displayHost strips scheme and default ports', () {
      expect(
          const ServerProfile(
                  id: 'a', name: 'n', baseUrl: 'http://nas.local:8080')
              .displayHost,
          'nas.local:8080');
      expect(
          const ServerProfile(id: 'a', name: 'n', baseUrl: 'http://nas.local')
              .displayHost,
          'nas.local');
      expect(
          const ServerProfile(id: 'a', name: 'n', baseUrl: 'not a url')
              .displayHost,
          isNotEmpty);
    });

    test('json round trip', () {
      const p = ServerProfile(
          id: 'x',
          name: 'srv',
          baseUrl: 'http://h:1',
          username: 'u',
          password: 'p',
          rememberSession: false);
      final back = ServerProfile.fromJson(p.toJson());
      expect(back, equals(p));
      expect(back.hashCode, equals(p.hashCode));
      expect(p.copyWith(name: 'new').name, 'new');
      expect(p.copyWith().id, 'x');
      expect(back == const ServerProfile(id: 'x', name: 'y', baseUrl: 'z'),
          isFalse);
      // fromJson defaults
      final empty = ServerProfile.fromJson(const {});
      expect(empty.rememberSession, isTrue);
    });
  });

  group('TorrentState', () {
    test('parses every known state', () {
      const raw = [
        'error', 'missingFiles', 'uploading', 'pausedUP', 'stoppedUP',
        'queuedUP', 'stalledUP', 'checkingUP', 'forcedUP', 'allocating',
        'downloading', 'metaDL', 'forcedMetaDL', 'pausedDL', 'stoppedDL',
        'queuedDL', 'stalledDL', 'checkingDL', 'forcedDL',
        'checkingResumeData', 'moving', 'unknown', '???',
      ];
      for (final r in raw) {
        expect(TorrentState.parse(r).label, isNotEmpty);
      }
      expect(TorrentState.parse('???'), TorrentState.unknown);
    });

    test('classifies states', () {
      expect(TorrentState.downloading.isDownloading, isTrue);
      expect(TorrentState.stalledDl.isDownloading, isTrue);
      expect(TorrentState.uploading.isSeeding, isTrue);
      expect(TorrentState.stalledUp.isSeeding, isTrue);
      expect(TorrentState.pausedDl.isPaused, isTrue);
      expect(TorrentState.stoppedUp.isPaused, isTrue);
      expect(TorrentState.downloading.isPaused, isFalse);
      expect(TorrentState.error.isErrored, isTrue);
      expect(TorrentState.missingFiles.isErrored, isTrue);
      expect(TorrentState.downloading.isActive, isTrue);
      expect(TorrentState.moving.isActive, isTrue);
      expect(TorrentState.pausedDl.isActive, isFalse);
    });
  });

  group('Torrent', () {
    test('fromJson + applyJson partial merge', () {
      final t = Torrent.fromJson('h1', {
        'name': 'Ubuntu ISO',
        'size': 4000,
        'progress': 0.5,
        'state': 'downloading',
        'dlspeed': 1000,
        'upspeed': 200,
        'tags': 'linux, iso ',
        'eta': 30,
        'auto_tmm': true,
        'force_start': false,
        'seq_dl': true,
        'f_l_piece_prio': true,
        'super_seeding': false,
        'infohash_v1': 'abc',
        'ratio_limit': 1.5,
        'max_ratio': 2.0,
      });
      expect(t.hash, 'h1');
      expect(t.name, 'Ubuntu ISO');
      expect(t.progress, 0.5);
      expect(t.state, TorrentState.downloading);
      expect(t.tags, ['linux', 'iso']);
      expect(t.isPaused, isFalse);
      expect(t.progressClamped, 0.5);

      // partial update keeps untouched fields
      t.applyJson({'progress': 0.9, 'name': 'Renamed', 'tags': ''});
      expect(t.name, 'Renamed');
      expect(t.progress, 0.9);
      expect(t.size, 4000);
      expect(t.tags, isEmpty);

      t.applyJson({'progress': 1.4});
      expect(t.progressClamped, 1.0);
    });

    test('applyJson covers every field', () {
      final t = Torrent(hash: 'h');
      t.applyJson({
        'total_size': 1, 'priority': 2, 'num_seeds': 3, 'num_complete': 4,
        'num_leechs': 5, 'num_incomplete': 6, 'save_path': 'a',
        'content_path': 'b', 'added_on': 7, 'completion_on': 8,
        'uploaded': 9, 'uploaded_session': 10, 'downloaded': 11,
        'downloaded_session': 12, 'amount_left': 13, 'time_active': 14,
        'seeding_time': 15, 'seeding_time_limit': 16, 'dl_limit': 17,
        'up_limit': 18, 'availability': 1.5, 'last_activity': 19,
        'magnet_uri': 'm', 'tracker': 'tr', 'trackers_count': 2,
        'max_seeding_time': 30, 'category': 'cat', 'infohash_v2': 'v2',
      });
      expect(t.totalSize, 1);
      expect(t.priority, 2);
      expect(t.numSeeds, 3);
      expect(t.numComplete, 4);
      expect(t.numLeechs, 5);
      expect(t.numIncomplete, 6);
      expect(t.savePath, 'a');
      expect(t.contentPath, 'b');
      expect(t.addedOn, 7);
      expect(t.completionOn, 8);
      expect(t.uploaded, 9);
      expect(t.uploadedSession, 10);
      expect(t.downloaded, 11);
      expect(t.downloadedSession, 12);
      expect(t.amountLeft, 13);
      expect(t.timeActive, 14);
      expect(t.seedingTime, 15);
      expect(t.seedingTimeLimit, 16);
      expect(t.dlLimit, 17);
      expect(t.upLimit, 18);
      expect(t.availability, 1.5);
      expect(t.lastActivity, 19);
      expect(t.magnetUri, 'm');
      expect(t.tracker, 'tr');
      expect(t.trackersCount, 2);
      expect(t.maxSeedingTime, 30);
      expect(t.category, 'cat');
      expect(t.infohashV2, 'v2');
    });
  });

  group('ServerState + MainDataUpdate', () {
    test('parses server_state and helpers', () {
      final s = ServerState();
      s.applyJson({
        'connection_status': 'connected',
        'dht_nodes': 42,
        'dl_info_speed': 1,
        'dl_info_data': 2,
        'up_info_speed': 3,
        'up_info_data': 4,
        'dl_rate_limit': 5,
        'up_rate_limit': 6,
        'alltime_dl': 7,
        'alltime_ul': 8,
        'total_wasted_session': 9,
        'free_space_on_disk': 10,
        'global_ratio': '1.2',
        'queued_io_jobs': 11,
        'queueing': true,
        'use_alt_speed_limits': true,
        'refresh_interval': 2000,
        'total_peer_connections': 12,
      });
      expect(s.connected, isTrue);
      expect(s.firewalled, isFalse);
      expect(s.connectionLabel, 'Connected');
      expect(s.dhtNodes, 42);
      expect(s.globalRatio, '1.2');
      expect(s.useAltSpeedLimits, isTrue);

      s.applyJson({'connection_status': 'firewalled'});
      expect(s.firewalled, isTrue);
      expect(s.connectionLabel, 'Firewalled');
      s.applyJson({'connection_status': 'x'});
      expect(s.connectionLabel, 'Disconnected');
    });

    test('MainDataUpdate parses nested maps', () {
      final u = MainDataUpdate.fromJson({
        'rid': 5,
        'full_update': true,
        'torrents': {
          'h': {'name': 'n'},
          'bad': 'notamap',
        },
        'torrents_removed': ['x'],
        'categories': {
          'iso': {'savePath': '/dl'}
        },
        'categories_removed': ['old'],
        'tags': ['a'],
        'tags_removed': ['b'],
        'trackers': {
          'udp://t': ['h']
        },
        'trackers_removed': ['gone'],
        'server_state': {'dht_nodes': 3},
      });
      expect(u.rid, 5);
      expect(u.fullUpdate, isTrue);
      expect(u.torrents['h']!['name'], 'n');
      expect(u.torrents['bad'], isEmpty);
      expect(u.torrentsRemoved, ['x']);
      expect(u.categories['iso']!['savePath'], '/dl');
      expect(u.categoriesRemoved, ['old']);
      expect(u.tags, ['a']);
      expect(u.tagsRemoved, ['b']);
      expect(u.trackers['udp://t'], ['h']);
      expect(u.trackersRemoved, ['gone']);
      expect(u.serverState!['dht_nodes'], 3);

      final empty = MainDataUpdate.fromJson({});
      expect(empty.fullUpdate, isFalse);
      expect(empty.serverState, isNull);
      expect(empty.torrents, isEmpty);
    });

    test('Category.fromJson', () {
      final c = Category.fromJson('iso', {'savePath': '/x'});
      expect(c.name, 'iso');
      expect(c.savePath, '/x');
      expect(Category.fromJson('e', {}).savePath, '');
    });
  });

  group('torrent_detail models', () {
    test('TorrentProperties.fromJson', () {
      final p = TorrentProperties.fromJson(const {
        'save_path': '/dl',
        'creation_date': 1,
        'piece_size': 2,
        'comment': 'c',
        'total_wasted': 3,
        'total_uploaded': 4,
        'total_uploaded_session': 5,
        'total_downloaded': 6,
        'total_downloaded_session': 7,
        'up_limit': 8,
        'dl_limit': 9,
        'time_elapsed': 10,
        'seeding_time': 11,
        'nb_connections': 12,
        'nb_connections_limit': 13,
        'share_ratio': 1.5,
        'addition_date': 14,
        'completion_date': 15,
        'created_by': 'me',
        'dl_speed_avg': 16,
        'dl_speed': 17,
        'eta': 18,
        'last_seen': 19,
        'peers': 20,
        'peers_total': 21,
        'pieces_have': 22,
        'pieces_num': 23,
        'reannounce': 24,
        'seeds': 25,
        'seeds_total': 26,
        'total_size': 27,
        'up_speed_avg': 28,
        'up_speed': 29,
      });
      expect(p.savePath, '/dl');
      expect(p.shareRatio, 1.5);
      expect(p.upSpeed, 29);
      expect(p.seedsTotal, 26);
      final empty = TorrentProperties.fromJson(const {});
      expect(empty.creationDate, -1);
      expect(empty.eta, 8640000);
    });

    test('FilePriority + TorrentFile', () {
      expect(FilePriority.fromValue(0), FilePriority.skip);
      expect(FilePriority.fromValue(6), FilePriority.high);
      expect(FilePriority.fromValue(7), FilePriority.maximum);
      expect(FilePriority.fromValue(99), FilePriority.normal);
      for (final p in FilePriority.values) {
        expect(p.label, isNotEmpty);
      }
      final f = TorrentFile.fromJson(const {
        'index': 2,
        'name': 'dir/sub/file.mkv',
        'size': 1000,
        'progress': 0.25,
        'priority': 6,
        'is_seed': true,
        'availability': 0.9,
      });
      expect(f.fileName, 'file.mkv');
      expect(f.directory, 'dir/sub');
      expect(f.downloaded, 250);
      expect(f.priority, FilePriority.high);
      final bare = TorrentFile.fromJson(const {'name': 'solo.bin'});
      expect(bare.directory, '');
      expect(bare.fileName, 'solo.bin');
    });

    test('TorrentTracker', () {
      expect(TrackerStatus.fromValue(0), TrackerStatus.disabled);
      expect(TrackerStatus.fromValue(1), TrackerStatus.notContacted);
      expect(TrackerStatus.fromValue(2), TrackerStatus.working);
      expect(TrackerStatus.fromValue(3), TrackerStatus.updating);
      expect(TrackerStatus.fromValue(4), TrackerStatus.error);
      expect(TrackerStatus.fromValue(99), TrackerStatus.notContacted);
      for (final s in TrackerStatus.values) {
        expect(s.label, isNotEmpty);
      }
      final t = TorrentTracker.fromJson(const {
        'url': '** [DHT] **',
        'status': 0,
        'tier': -1,
      });
      expect(t.isSpecial, isTrue);
      final normal = TorrentTracker.fromJson(const {
        'url': 'https://t/announce',
        'status': 2,
        'num_seeds': 10,
        'num_peers': 5,
        'num_leeches': 3,
        'num_downloaded': 1,
        'msg': 'ok',
      });
      expect(normal.isSpecial, isFalse);
      expect(normal.numSeeds, 10);
    });

    test('Peer + TorrentDataUpdate', () {
      final p = Peer.fromJson(const {
        'ip': '1.2.3.4',
        'port': 6881,
        'client': 'qBittorrent',
        'progress': 0.5,
        'dl_speed': 100,
        'up_speed': 50,
        'downloaded': 9,
        'uploaded': 8,
        'connection': 'μTP',
        'flags': 'U',
        'country': 'NL',
        'country_code': 'nl',
        'relevance': 0.1,
      });
      expect(p.address, '1.2.3.4:6881');
      expect(p.client, 'qBittorrent');

      final noPort = Peer.fromJson(const {'ip': '5.6.7.8'});
      expect(noPort.address, '5.6.7.8');

      final u = TorrentDataUpdate.fromJson({
        'rid': 2,
        'full_update': true,
        'peers': {
          '1.2.3.4:1': {'ip': '1.2.3.4', 'port': 1},
          'bad': 'x',
        },
        'peers_removed': ['old'],
      });
      expect(u.peers.length, 1);
      expect(u.peersRemoved, ['old']);
      expect(u.fullUpdate, isTrue);
      final empty = TorrentDataUpdate.fromJson({});
      expect(empty.peers, isEmpty);
      expect(empty.peersRemoved, isEmpty);
    });
  });

  group('rss models', () {
    test('RssItem.fromJson', () {
      final i = RssItem.fromJson(const {
        'id': '1',
        'title': 'T',
        'torrentURL': 'magnet:?x',
        'articleURL': 'https://a',
        'date': 'today',
        'author': 'me',
        'isRead': true,
        'torrentSize': 9,
      });
      expect(i.isRead, isTrue);
      expect(i.torrentSize, 9);
      expect(RssItem.fromJson(const {}).torrentSize, -1);
    });

    test('RssFeed + feed tree flatten', () {
      final root = RssFeedNode.fromFeedsJson({
        'Feed A': {
          'url': 'https://a/rss',
          'isLoading': false,
          'hasError': true,
          'lastBuildDate': 'd',
          'articles': [
            {'id': '1', 'title': 'a1', 'isRead': false},
            'garbage',
          ],
        },
        'Folder': {
          'Feed B': {
            'url': 'https://b/rss',
            'articles': [],
          },
        },
      });
      final flat = root.flatten();
      expect(flat.length, 2);
      expect(flat[0].feed.name, 'Feed A');
      expect(flat[0].feed.hasError, isTrue);
      expect(flat[0].feed.unreadCount, 1);
      expect(flat[1].path, 'Folder\\Feed B');
      expect(flat[1].feed.name, 'Feed B');
      expect(root.isFolder, isTrue);

      final single = RssFeedNode.fromJson(const {'url': 'u'});
      expect(single.isFolder, isFalse);
      expect(single.feed!.name, '');
      final folder = RssFeedNode.fromJson(const {
        'sub': {'url': 'u2'}
      });
      expect(folder.children['sub']!.feed!.url, 'u2');

      // fromJson leaf with articles parses items
      final leaf = RssFeedNode.fromJson(const {
        'url': 'u',
        'articles': [
          {'id': '1', 'title': 't'},
          'garbage',
        ],
      });
      expect(leaf.feed!.items.single.id, '1');
    });
  });
}
