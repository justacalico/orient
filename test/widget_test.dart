import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:orient/app_state.dart';
import 'package:orient/models/rss.dart';
import 'package:orient/models/torrent.dart';
import 'package:orient/models/torrent_detail.dart';
import 'package:orient/services/server_store.dart';
import 'package:orient/services/settings.dart';
import 'package:orient/ui/app.dart';
import 'package:orient/ui/widgets/common.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fakes.dart';

Map<String, dynamic> tj(String name,
        {String state = 'downloading',
        double progress = 0.4,
        int dlspeed = 2048,
        int upspeed = 512,
        String category = 'iso',
        String tags = 'a',
        int eta = 90,
        int size = 4096,
        int numSeeds = 3,
        int numLeechs = 1,
        double ratio = 1.25,
        int downloaded = 1600,
        int uploaded = 2000,
        String savePath = '/dl'}) =>
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
      'ratio': ratio,
      'downloaded': downloaded,
      'uploaded': uploaded,
      'num_seeds': numSeeds,
      'num_leechs': numLeechs,
      'save_path': savePath,
      'added_on': 1700000000,
      'time_active': 500,
      'seeding_time': 60,
    };

Future<({AppState state, FakeQbApi api})> pump(
  WidgetTester tester, {
  bool wide = false,
  Size? size,
  bool connected = true,
}) async {
  SharedPreferences.setMockInitialValues({});
  final r = await makeConnectedState();
  if (connected) {
    r.api.mainDataResponses.add(fullUpdate(torrents: {
      'h1': tj('alpha download'),
      'h2': tj('beta seed', state: 'uploading', progress: 1.0),
      'h3': tj('gamma paused', state: 'stoppedDL', dlspeed: 0, upspeed: 0),
    }, categories: {
      'iso': {'savePath': '/dl'}
    }, tags: [
      'a'
    ]));
    await r.state.refreshOnce();
  }
  final logicalSize =
      size ?? (wide ? const Size(1400, 900) : const Size(420, 900));
  tester.view.physicalSize = logicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider<AppState>.value(
      value: r.state,
      child: const OrientApp(),
    ),
  );
  await tester.pumpAndSettle();
  return r;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('connect page', () {
    testWidgets('shows server list and empty state', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = await ServerStore.load();
      final s = AppState(
          settings: Settings(),
          store: store,
          autoPoll: false,
          apiFactory: (p) => FakeQbApi(p));
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
          value: s, child: const OrientApp()));
      await tester.pumpAndSettle();
      expect(find.text('Orient'), findsOneWidget);
      expect(find.text('Add server'), findsOneWidget);

      // Add server flow
      await tester.tap(find.text('Add server'));
      await tester.pumpAndSettle();
      expect(find.text('WebUI address'), findsOneWidget);
      // validation error on empty save
      await tester.tap(find.text('Connect'));
      await tester.pumpAndSettle();
      expect(find.text('Enter the WebUI address'), findsOneWidget);

      await tester.enterText(
          find.widgetWithText(TextField, 'WebUI address'), 'nas.local:8080');
      await tester.enterText(find.widgetWithText(TextField, 'Username'), 'u');
      await tester.enterText(find.widgetWithText(TextField, 'Password'), 'p');
      await tester.tap(find.text('Stay signed in'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Connect'));
      await tester.pumpAndSettle();
      // connect fails (no real api) but profile saved; connect page still shown
      expect(store.servers.length, 1);
      s.dispose();
    });

    testWidgets('shows saved servers, edit and remove', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = await ServerStore.load();
      await store.upsert(testProfile);
      final s = AppState(
          settings: Settings(), store: store, autoPoll: false,
          apiFactory: (p) => FakeQbApi(p)..loginResult = false);
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
          value: s, child: const OrientApp()));
      await tester.pumpAndSettle();
      expect(find.text('Testbox'), findsOneWidget);

      // open editor
      await tester.tap(find.byTooltip('Edit'));
      await tester.pumpAndSettle();
      expect(find.text('Edit server'), findsOneWidget);
      // delete
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove').last);
      await tester.pumpAndSettle();
      expect(store.servers, isEmpty);
      s.dispose();
    });

    testWidgets('error banner shows last error', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = await ServerStore.load();
      await store.upsert(testProfile);
      final s = AppState(
          settings: Settings(),
          store: store,
          autoPoll: false,
          apiFactory: (p) => FakeQbApi(p)..loginResult = false);
      await s.connect(testProfile);
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
          value: s, child: const OrientApp()));
      await tester.pumpAndSettle();
      expect(find.text('Wrong username or password'), findsOneWidget);
      s.dispose();
    });

    testWidgets('tap server tile triggers connect', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = await ServerStore.load();
      await store.upsert(testProfile);
      final s = AppState(
          settings: Settings(),
          store: store,
          autoPoll: false,
          apiFactory: (p) => FakeQbApi(p)..loginResult = false);
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
          value: s, child: const OrientApp()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Testbox'));
      await tester.pumpAndSettle();
      expect(s.phase, ConnectionPhase.failed);
      s.dispose();
    });
  });

  group('shell + torrents', () {
    testWidgets('compact layout: nav bar, torrent list, detail push',
        (tester) async {
      final r = await pump(tester);
      expect(find.text('alpha download'), findsOneWidget);
      expect(find.text('Torrents'), findsWidgets);

      // open detail page (compact)
      await tester.tap(find.text('alpha download'));
      await tester.pumpAndSettle();
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.text('General'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      r.state.dispose();
    });

    testWidgets('wide layout: rail + master-detail', (tester) async {
      final r = await pump(tester, wide: true);
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.text('No torrent selected'), findsOneWidget);

      await tester.tap(find.text('alpha download'));
      await tester.pumpAndSettle();
      expect(find.text('Trackers'), findsOneWidget);
      // detail pane tabs
      await tester.tap(find.text('Files'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Peers'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Trackers'));
      await tester.pumpAndSettle();
      r.state.dispose();
    });

    testWidgets('nav switches tabs', (tester) async {
      final r = await pump(tester);
      await tester.tap(find.text('Speed'));
      await tester.pumpAndSettle();
      expect(find.text('Download limit'), findsOneWidget);
      await tester.tap(find.text('RSS'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Appearance'), findsOneWidget);
      await tester.tap(find.text('Torrents'));
      await tester.pumpAndSettle();
      r.state.dispose();
    });

    testWidgets('filters and search', (tester) async {
      final r = await pump(tester);
      // search
      await tester.enterText(
          find.widgetWithText(TextField, 'Search torrents'), 'alpha');
      await tester.pumpAndSettle();
      expect(find.text('alpha download'), findsOneWidget);
      expect(find.text('beta seed'), findsNothing);
      await tester.enterText(
          find.widgetWithText(TextField, 'Search torrents'), '');
      await tester.pumpAndSettle();

      // filter chips
      await tester.ensureVisible(find.text('Paused 1'));
      await tester.tap(find.text('Paused 1'));
      await tester.pumpAndSettle();
      expect(find.text('gamma paused'), findsOneWidget);
      expect(find.text('alpha download'), findsNothing);
      await tester.ensureVisible(find.text('All 3'));
      await tester.tap(find.text('All 3'));
      await tester.pumpAndSettle();

      // category filter
      await tester.tap(find.byTooltip('Category'));
      await tester.pumpAndSettle();
      await tester.tap(find
          .descendant(
              of: find.byType(PopupMenuItem<String?>),
              matching: find.text('iso'))
          .last);
      await tester.pumpAndSettle();
      // tag filter
      await tester.tap(find.byTooltip('Tag'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All tags'));
      await tester.pumpAndSettle();
      r.state.dispose();
    });

    testWidgets('sort menu', (tester) async {
      final r = await pump(tester);
      await tester.tap(find.byTooltip('Sort'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Name'));
      await tester.pumpAndSettle();
      expect(r.state.sort, TorrentSort.name);
      r.state.dispose();
    });

    testWidgets('selection + batch actions', (tester) async {
      final r = await pump(tester);
      await tester.longPress(find.text('alpha download'));
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);
      await tester.tap(find.text('beta seed'));
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);
      // pause both
      await tester.tap(find.byTooltip('Pause'));
      await tester.pumpAndSettle();
      expect(r.api.calls, contains('pause:modern'));
      // recheck
      await tester.tap(find.byTooltip('Recheck'));
      await tester.pumpAndSettle();
      // delete with confirm
      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Also delete files on disk'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      expect(r.api.calls, contains('delete:true'));
      expect(r.state.selected, isEmpty);
      r.state.dispose();
    });

    testWidgets('overflow menu: category/tag/location/limit dialogs',
        (tester) async {
      final r = await pump(tester);
      await tester.longPress(find.text('alpha download'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Set category'));
      await tester.pumpAndSettle();
      await tester.tap(find
          .descendant(
              of: find.byType(SimpleDialog), matching: find.text('iso'))
          .last);
      await tester.pumpAndSettle();
      expect(r.api.calls, contains('setCategory:iso'));

      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit tags'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Set location'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.widgetWithText(TextField, 'Download directory'), '/new');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(r.api.calls, contains('setLocation:/new'));

      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'renamed');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Download limit'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '500');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(r.api.calls, contains('dlLimit:512000'));

      // queue actions
      for (final label in [
        'Reannounce',
        'Move to top of queue',
        'Move up in queue',
        'Move down in queue',
        'Move to bottom',
        'Sequential download',
        'First/last pieces first',
      ]) {
        await tester.tap(find.byTooltip('More actions'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }
      expect(r.api.calls, containsAll([
        'reannounce', 'topPrio', 'increasePrio', 'decreasePrio',
        'bottomPrio', 'seq', 'firstLast',
      ]));
      r.state.dispose();
    });

    testWidgets('disconnect confirm', (tester) async {
      final r = await pump(tester);
      await tester.tap(find.byTooltip('Disconnect'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Disconnect').last);
      await tester.pumpAndSettle();
      expect(r.state.phase, ConnectionPhase.disconnected);
      expect(find.text('Orient'), findsOneWidget);
      r.state.dispose();
    });

    testWidgets('add torrent sheet validates and submits', (tester) async {
      final r = await pump(tester);
      await tester.tap(find.byTooltip('Add torrent'));
      await tester.pumpAndSettle();
      // empty -> error
      await tester.tap(find.text('Add').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('magnet'), findsWidgets);

      await tester.enterText(
          find.widgetWithText(
              TextField, 'Magnet link or torrent URL, one per line'),
          'magnet:?xt=urn:btih:abc');
      await tester.tap(find.text('Add paused'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add').last);
      await tester.pumpAndSettle();
      expect(r.api.calls.any((c) => c.startsWith('addUrls:magnet:')), isTrue);
      r.state.dispose();
    });
  });

  group('detail', () {
    testWidgets('general tab shows stats; files/trackers actions', (tester) async {
      final r = await pump(tester, wide: true);
      r.api.props['h1'] = const TorrentProperties(
          savePath: '/dl', comment: 'hi', createdBy: 'me', piecesNum: 4);
      r.api.files['h1'] = const [
        TorrentFile(
            index: 0,
            name: 'a/b.mkv',
            size: 100,
            progress: 0.5,
            priority: FilePriority.normal,
            isSeed: false)
      ];
      r.api.trackersByHash['h1'] = const [
        TorrentTracker(url: 'udp://t', status: TrackerStatus.working),
        TorrentTracker(url: '** [DHT] **', status: TrackerStatus.disabled),
      ];
      r.api.peerResponses.add(TorrentDataUpdate.fromJson({
        'rid': 1,
        'peers': {
          '1.1.1.1:5': {'ip': '1.1.1.1', 'port': 5, 'client': 'qB'}
        }
      }));

      await tester.tap(find.text('alpha download'));
      await tester.pumpAndSettle();
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.text('Transfer'), findsOneWidget);
      expect(find.text('/dl'), findsWidgets);

      // copy hash
      await tester.tap(find.byTooltip('Copy hash'));
      await tester.pumpAndSettle();
      expect(find.text('Hash copied'), findsOneWidget);

      // pause from header
      await tester.tap(find.byTooltip('Pause'));
      await tester.pumpAndSettle();

      // files tab + priority dialog
      await tester.tap(find.text('Files'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('a/b.mkv'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Maximum'));
      await tester.pumpAndSettle();
      expect(r.api.calls, contains('filePrio:0:7'));

      // trackers tab
      await tester.tap(find.text('Trackers'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add tracker'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byType(TextField).last, 'udp://x\nudp://y');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(r.api.calls, contains('addTrackers:2'));
      // remove tracker
      await tester.tap(find.byTooltip('Remove tracker'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove').last);
      await tester.pumpAndSettle();
      expect(r.api.calls, contains('removeTrackers:1'));

      // peers tab
      await tester.tap(find.text('Peers'));
      await tester.pumpAndSettle();
      r.state.dispose();
    });

    testWidgets('detail close and removed torrent', (tester) async {
      final r = await pump(tester, wide: true);
      await tester.tap(find.text('alpha download'));
      await tester.pumpAndSettle();
      await tester.pumpAndSettle(const Duration(seconds: 1));
      // close pane
      final closeBtn = find.byTooltip('Close');
      if (closeBtn.evaluate().isNotEmpty) {
        await tester.tap(closeBtn);
        await tester.pumpAndSettle();
      }
      r.state.dispose();
    });
  });

  group('transfer', () {
    testWidgets('shows graphs, limits, alt speed', (tester) async {
      final r = await pump(tester);
      await tester.tap(find.text('Speed'));
      await tester.pumpAndSettle();
      expect(find.text('Session download'), findsOneWidget);
      expect(find.text('DHT nodes'), findsOneWidget);

      // alt speed toggle
      await tester.tap(find.text('Alternative speed limits'));
      await tester.pumpAndSettle();
      expect(r.api.calls, contains('altSpeed'));

      // edit dl limit
      await tester.tap(find.text('Download limit'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '100');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(r.api.calls, contains('gdl:102400'));

      // edit ul limit, empty = unlimited
      await tester.tap(find.text('Upload limit'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(r.api.calls, contains('gul:0'));

      r.state.dispose();
    });
  });

  group('rss', () {
    testWidgets('feed chips, items, mark read, add/remove feed', (tester) async {
      final r = await pump(tester);
      r.api.rssResult = RssFeedNode.fromFeedsJson({
        'FeedOne': {
          'url': 'u',
          'articles': [
            {
              'id': '1',
              'title': 'Cool release',
              'articleURL': 'https://x',
              'isRead': false,
              'author': 'me',
              'torrentSize': 2048,
              'date': 'today'
            },
            {'id': '2', 'title': 'Old one', 'isRead': true},
          ]
        }
      });
      await tester.tap(find.text('RSS'));
      await tester.pumpAndSettle();
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.text('Cool release'), findsOneWidget);
      expect(find.textContaining('FeedOne'), findsOneWidget);

      // select feed chip
      await tester.tap(find.textContaining('FeedOne'));
      await tester.pumpAndSettle();
      // back to all
      await tester.tap(find.text('All feeds'));
      await tester.pumpAndSettle();

      // open item (marks read + launches url; launch fails silently in test)
      await tester.tap(find.text('Cool release'));
      await tester.pumpAndSettle();
      expect(r.api.calls, contains('rssRead:FeedOne'));

      // add feed
      await tester.tap(find.byTooltip('Add feed'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.widgetWithText(TextField, 'Feed URL'), 'https://rss/x');
      await tester.enterText(
          find.widgetWithText(TextField, 'Name (optional)'), 'Mine');
      await tester.tap(find.text('Subscribe'));
      await tester.pumpAndSettle();
      expect(r.api.calls, contains('rssAdd:https://rss/x'));

      // feed chip menu: refresh + mark read + unsubscribe
      await tester.longPress(find.textContaining('FeedOne'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Refresh feed'));
      await tester.pumpAndSettle();
      await tester.longPress(find.textContaining('FeedOne'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark all as read'));
      await tester.pumpAndSettle();
      await tester.longPress(find.textContaining('FeedOne'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unsubscribe'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove').last);
      await tester.pumpAndSettle();
      expect(r.api.calls, contains('rssRemove:FeedOne'));
      r.state.dispose();
    });

    testWidgets('empty rss state', (tester) async {
      final r = await pump(tester);
      await tester.tap(find.text('RSS'));
      await tester.pumpAndSettle();
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.text('No feeds'), findsOneWidget);
      r.state.dispose();
    });
  });

  group('settings', () {
    testWidgets('theme, accent, poll interval, server management', (tester) async {
      final r = await pump(tester);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Appearance'), findsOneWidget);

      // theme dark
      await tester.tap(find.byIcon(Icons.dark_mode_rounded));
      await tester.pumpAndSettle();
      expect(r.state.settings.themeMode, ThemeMode.dark);
      // accent
      await tester.tap(
          find.byWidgetPredicate(
              (w) => w is Container && w.decoration is BoxDecoration &&
                  (w.decoration as BoxDecoration).color == OrientAccents.teal,
              description: 'teal accent'));
      await tester.pumpAndSettle();
      expect(r.state.settings.accentColor, OrientAccents.teal);

      // poll interval
      await tester.tap(find.text('2s'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('5s').last);
      await tester.pumpAndSettle();
      expect(r.state.settings.pollInterval, const Duration(seconds: 5));

      // confirm deletes off
      await tester.tap(find.text('Confirm before deleting'));
      await tester.pumpAndSettle();
      expect(r.state.settings.confirmDeletes, isFalse);

      // category manager: new category
      await tester.tap(find.text('New category'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'movies');
      await tester.enterText(
          find.widgetWithText(TextField, 'Save path (optional)'), '/movies');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(r.api.calls, contains('createCategory:movies'));

      // edit existing category
      await tester.tap(find.byTooltip('Edit save path').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '/edit');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(r.api.calls, contains('editCategory:iso'));

      // delete category
      await tester.tap(find.byTooltip('Delete category').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      expect(r.api.calls, contains('removeCategories:iso'));

      // tags: create + delete
      await tester.tap(find.text('New tag'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'fresh');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(r.api.calls, contains('createTags:fresh'));
      await tester.tap(find.byTooltip('Delete tag').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      expect(r.api.calls, contains('deleteTags:a'));

      // disconnect via settings
      await tester.scrollUntilVisible(find.text('Disconnect'), 200);
      await tester.drag(
          find.byType(ListView).first, const Offset(0, -140));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Disconnect'));
      await tester.pumpAndSettle();
      expect(r.state.phase, ConnectionPhase.disconnected);
      r.state.dispose();
    });
  });

  group('widgets/common', () {
    testWidgets('SpeedGraph empty vs data', (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Column(children: const [
        SpeedGraph(series: [], color: Colors.blue),
        SpeedGraph(series: [1], color: Colors.blue),
        SpeedGraph(series: [0, 10, 5, 20], color: Colors.blue, height: 40),
      ]))));
      expect(find.byType(SpeedGraph), findsNWidgets(3));
    });

    testWidgets('StatTile + EmptyState render', (tester) async {
      await tester.pumpWidget(const MaterialApp(
          home: Scaffold(
              body: Column(children: [
        StatTile(label: 'L', value: 'V'),
        EmptyState(icon: Icons.abc, title: 'T', message: 'M',
            action: Text('A')),
      ]))));
      expect(find.text('V'), findsOneWidget);
      expect(find.text('M'), findsOneWidget);
    });

    testWidgets('promptForText cancel/confirm, confirmDialog both ways',
        (tester) async {
      String? v;
      bool? c;
      await tester.pumpWidget(MaterialApp(
          home: Builder(
              builder: (ctx) => Scaffold(
                      body: Column(children: [
                    TextButton(
                        onPressed: () async =>
                            v = await promptForText(ctx, title: 'T'),
                        child: const Text('prompt')),
                    TextButton(
                        onPressed: () async => c =
                            await confirmDialog(ctx, title: 't', message: 'm'),
                        child: const Text('confirm')),
                  ])))));
      await tester.tap(find.text('prompt'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(v, isNull);

      await tester.tap(find.text('prompt'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'val');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(v, 'val');

      // onSubmitted path
      await tester.tap(find.text('prompt'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'sub');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(v, 'sub');

      await tester.tap(find.text('confirm'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(c, isFalse);

      await tester.tap(find.text('confirm'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(c, isTrue);
    });

    testWidgets('torrentStateStyle covers all states', (tester) async {
      for (final s in TorrentState.values) {
        await tester.pumpWidget(MaterialApp(
            home: Builder(
                builder: (ctx) =>
                    Icon(torrentStateStyle(ctx, s).icon))));
        await tester.pump();
      }
      expect(find.byType(Icon), findsWidgets);
    });
  });
}
