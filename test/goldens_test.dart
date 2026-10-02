import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:orient/app_state.dart';
import 'package:orient/models/rss.dart';
import 'package:orient/models/torrent_detail.dart';
import 'package:orient/services/server_store.dart';
import 'package:orient/services/settings.dart';
import 'package:orient/ui/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fakes.dart';

/// Rasterizers differ slightly between machines — allow a small pixel
/// diff instead of regenerating per host.
class TolerantGoldenComparator extends LocalFileComparator {
  TolerantGoldenComparator(super.testFile, this.tolerance);

  final double tolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
        imageBytes, await getGoldenBytes(golden));
    return result.passed || result.diffPercent <= tolerance;
  }
}

Future<void> settle(WidgetTester tester, [int times = 8]) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Map<String, dynamic> tj(String name,
        {String state = 'downloading',
        double progress = 0.4,
        String? category,
        String? tags}) =>
    {
      'name': name,
      'state': state,
      'progress': progress,
      'size': 3000000000,
      'total_size': 4000000000,
      'dlspeed': 12000000,
      'upspeed': 450000,
      'eta': 200,
      'ratio': 0.82,
      'added_on': 1735000000,
      'num_seeds': 12,
      'num_leechs': 3,
      'category': ?category,
      'tags': ?tags,
    };

Future<({AppState state, FakeQbApi api})> pump(
  WidgetTester tester,
  Size size,
) async {
  SharedPreferences.setMockInitialValues({});
  final r = await makeConnectedState();
  r.api.mainDataResponses.add(fullUpdate(
    torrents: {
      'h1': tj('ubuntu-24.04.iso', category: 'iso', tags: 'linux'),
      'h2': tj('library backup', state: 'uploading', progress: 1),
      'h3': tj('linux mint', state: 'stoppedDL', progress: 0.62),
    },
    categories: {
      'iso': {},
      'media': {},
    },
    tags: ['linux', 'auto'],
    serverState: {
      'connection_status': 'connected',
      'dl_info_speed': 8200000,
      'up_info_speed': 350000,
      'dl_info_data': 41000000000,
      'up_info_data': 9000000000,
    },
  ));
  await r.state.refreshOnce();
  await tester.binding.setSurfaceSize(size);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: r.state, child: const OrientApp()));
  await settle(tester);
  return r;
}

void main() {
  goldenFileComparator =
      TolerantGoldenComparator(Uri.file('test/goldens_test.dart'), 0.5);

  testWidgets('golden: connect screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await ServerStore.load();
    final s = AppState(
        settings: Settings(), store: store, autoPoll: false);
    addTearDown(s.dispose);
    await tester.binding.setSurfaceSize(const Size(420, 900));
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
        value: s, child: const OrientApp()));
    await settle(tester);
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/connect.png'));
  });

  testWidgets('golden: torrents compact', (tester) async {
    final r = await pump(tester, const Size(420, 900));
    addTearDown(r.state.dispose);
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/torrents_compact.png'));
  });

  testWidgets('golden: torrents wide with detail', (tester) async {
    final r = await pump(tester, const Size(1400, 900));
    addTearDown(r.state.dispose);
    r.api.props['h1'] = const TorrentProperties(
        savePath: '/data/torrents', seeds: 12, peers: 3, piecesNum: 4000);
    r.api.files['h1'] = const [
      TorrentFile(
          index: 0,
          name: 'ubuntu-24.04.iso',
          size: 4000000000,
          progress: 0.4,
          priority: FilePriority.normal,
          isSeed: false),
      TorrentFile(
          index: 1,
          name: 'README.txt',
          size: 2000,
          progress: 1,
          priority: FilePriority.high,
          isSeed: true),
    ];
    r.state.openDetail('h1');
    await settle(tester);
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/torrents_wide.png'));
  });

  testWidgets('golden: torrent detail compact', (tester) async {
    final r = await pump(tester, const Size(420, 900));
    addTearDown(r.state.dispose);
    r.api.props['h1'] = const TorrentProperties(
        savePath: '/data/torrents', seeds: 12, peers: 3, piecesNum: 4000);
    r.api.files['h1'] = const [
      TorrentFile(
          index: 0,
          name: 'ubuntu-24.04.iso',
          size: 4000000000,
          progress: 0.4,
          priority: FilePriority.normal,
          isSeed: false),
      TorrentFile(
          index: 1,
          name: 'README.txt',
          size: 2000,
          progress: 1,
          priority: FilePriority.high,
          isSeed: true),
    ];
    r.api.trackersByHash['h1'] = const [
      TorrentTracker(
          url: 'https://tracker.example/announce',
          status: TrackerStatus.working,
          msg: 'working',
          numPeers: 40,
          numSeeds: 120),
    ];
    await tester.tap(find.text('ubuntu-24.04.iso'));
    await settle(tester);
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/detail_compact.png'));
    await tester.pumpWidget(const SizedBox());
    await settle(tester, 2);
  });

  testWidgets('golden: transfer compact', (tester) async {
    final r = await pump(tester, const Size(420, 900));
    addTearDown(r.state.dispose);
    r.state.dlHistory.addAll([3000000, 5000000, 4500000, 8000000, 7000000, 8200000]);
    r.state.upHistory.addAll([100000, 300000, 250000, 400000, 350000, 350000]);
    await tester.tap(find.text('Speed'));
    await settle(tester);
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/transfer.png'));
  });

  testWidgets('golden: rss compact', (tester) async {
    final r = await pump(tester, const Size(420, 900));
    addTearDown(r.state.dispose);
    r.api.rssResult = RssFeedNode.fromFeedsJson(const {
      'Distrowatch': {
        'url': 'https://distrowatch.com/rss',
        'articles': [
          {
            'id': 'a1',
            'title': 'Debian 13 released',
            'torrentURL': 'magnet:?x',
            'date': 'Mon, 23 Dec 2025',
          },
          {
            'id': 'a2',
            'title': 'Fedora 42 released',
            'torrentURL': 'magnet:?y',
            'isRead': true,
          },
        ],
      },
    });
    await tester.tap(find.text('RSS'));
    await settle(tester);
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/rss.png'));
  });

  testWidgets('golden: settings compact', (tester) async {
    final r = await pump(tester, const Size(420, 900));
    addTearDown(r.state.dispose);
    await tester.tap(find.text('Settings'));
    await settle(tester);
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/settings_compact.png'));
  });

  testWidgets('golden: settings wide', (tester) async {
    final r = await pump(tester, const Size(1400, 900));
    addTearDown(r.state.dispose);
    await tester.tap(find.text('Settings'));
    await settle(tester);
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/settings_wide.png'));
  });

  testWidgets('golden: add torrent sheet', (tester) async {
    final r = await pump(tester, const Size(420, 900));
    addTearDown(r.state.dispose);
    await tester.tap(find.byTooltip('Add torrent'));
    await settle(tester);
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/add_torrent.png'));
  });
}
