import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
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
import 'package:orient/ui/connect_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fakes.dart';

Map<String, dynamic> tj(String name,
        {String state = 'downloading', double progress = 0.4}) =>
    {
      'name': name,
      'state': state,
      'progress': progress,
      'size': 4096,
      'added_on': 1700000000,
    };

Future<({AppState state, FakeQbApi api})> pump(
  WidgetTester tester, {
  bool wide = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final r = await makeConnectedState();
  r.api.mainDataResponses.add(fullUpdate(torrents: {
    'h1': {...tj('alpha'), 'category': 'iso', 'tags': 'a'},
    'h2': tj('beta', state: 'stoppedDL', progress: 0.2),
  }, categories: {
    'iso': {}
  }, tags: [
    'a',
    'b'
  ], serverState: {
    'connection_status': 'connected',
    'dl_info_speed': 1,
    'up_info_speed': 2,
    'use_alt_speed_limits': true,
  }));
  await r.state.refreshOnce();
  tester.view.physicalSize =
      wide ? const Size(1400, 900) : const Size(420, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: r.state, child: const OrientApp()));
  await tester.pumpAndSettle();
  return r;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('wide nav rail switching', (tester) async {
    final r = await pump(tester, wide: true);
    await tester.tap(find.text('Speed'));
    await tester.pumpAndSettle();
    expect(find.text('Session download'), findsOneWidget);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    r.state.dispose();
  });

  testWidgets('connecting state shows spinner on server tile', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await ServerStore.load();
    await store.upsert(testProfile);
    final s = AppState(
        settings: Settings(), store: store, autoPoll: false);
    s.phase = ConnectionPhase.connecting;
    s.activeProfile = testProfile;
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
        value: s,
        child: const MaterialApp(home: ConnectPage())));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    await tester.tap(find.text('Testbox'));
    await tester.pump();
    s.dispose();
  });

  testWidgets('server editor from settings and cancel paths', (tester) async {
    final r = await pump(tester);
    // Navigate to settings
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    // open editor for existing server
    await tester.tap(find.widgetWithText(ListTile, 'Testbox').first);
    await tester.pumpAndSettle();
    expect(find.text('Edit server'), findsOneWidget);
    // dismiss via drag
    await tester.drag(
        find.byType(BottomSheet), const Offset(0, 400));
    await tester.pumpAndSettle();

    // Add server opens empty editor
    await tester.scrollUntilVisible(find.text('Add server'), 100);
    await tester.tap(find.text('Add server'));
    await tester.pumpAndSettle();
    expect(find.text('Add server').evaluate().length, greaterThan(0));
    await tester.drag(find.byType(BottomSheet), const Offset(0, 400));
    await tester.pumpAndSettle();

    // new category cancel
    await tester.tap(find.text('New category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    r.state.dispose();
  });

  testWidgets('selection: resume + cancel delete + overflow all paths',
      (tester) async {
    final r = await pump(tester);
    // select paused torrent only -> resume shows
    await tester.longPress(find.text('beta'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Resume'));
    await tester.pumpAndSettle();
    expect(r.api.calls, contains('resume:modern'));

    // delete dialog cancel
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // upload limit
    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upload limit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '200');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(r.api.calls, contains('ulLimit:204800'));

    // category: uncategorized + new category inline + cancel paths
    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Set category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Uncategorized'));
    await tester.pumpAndSettle();
    expect(r.api.calls, contains('setCategory:'));

    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Set category'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'New category'), 'fresh');
    await tester.tap(find.byTooltip('Create and apply'));
    await tester.pumpAndSettle();
    expect(r.api.calls, contains('createCategory:fresh'));

    // new category via onSubmitted
    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Set category'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'New category'), 'viaenter');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // tags dialog: toggle checkbox, create tag, cancel, apply with removal
    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit tags'));
    await tester.pumpAndSettle();
    // toggle tag 'a' off
    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pumpAndSettle();
    // create a new tag via the + button
    await tester.enterText(
        find.widgetWithText(TextField, 'New tag'), 'created');
    await tester.tap(find.byTooltip('Create tag'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(r.api.calls.any((c) => c.startsWith('addTags:')), isTrue);
    expect(r.api.calls.any((c) => c.startsWith('removeTags:')), isTrue);

    // tags dialog cancel
    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit tags'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // uncheck an existing tag on a single-selected torrent -> remove branch
    await tester.tap(find.byTooltip('Clear selection'));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('alpha'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit tags'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'a'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(r.api.calls.any((c) => c.startsWith('removeTags:a')), isTrue);
    r.state.dispose();
  });

  testWidgets('filter popups show check marks when selected', (tester) async {
    final r = await pump(tester);
    // select category filter
    await tester.tap(find.byTooltip('Category'));
    await tester.pumpAndSettle();
    await tester.tap(find
        .descendant(
            of: find.byType(PopupMenuItem<String?>),
            matching: find.text('iso'))
        .last);
    await tester.pumpAndSettle();
    // reopen -> check icon present
    await tester.tap(find.byTooltip('Category'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_rounded), findsWidgets);
    Navigator.of(tester.element(find.byTooltip('Category'))).pop();
    await tester.pumpAndSettle();

    // tag filter select + reopen
    await tester.tap(find.byTooltip('Tag'));
    await tester.pumpAndSettle();
    await tester.tap(find
        .descendant(
            of: find.byType(PopupMenuItem<String?>), matching: find.text('a'))
        .last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Tag'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_rounded), findsWidgets);
    r.state.dispose();
  });

  testWidgets('alt speed icon shows in status bar', (tester) async {
    final r = await pump(tester);
    expect(find.byIcon(Icons.slow_motion_video_rounded), findsOneWidget);
    r.state.dispose();
  });

  testWidgets('empty-then-filtered list shows empty states', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final r = await makeConnectedState();
    r.api.mainDataResponses.add(fullUpdate());
    await r.state.refreshOnce();
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
        value: r.state, child: const OrientApp()));
    await tester.pumpAndSettle();
    expect(find.text('No torrents'), findsOneWidget);
    r.state.torrents['x'] =
        Torrent.fromJson('x', {'name': 'seed', 'state': 'uploading'});
    r.state.setFilter(TorrentFilter.downloading);
    await tester.pumpAndSettle();
    expect(find.text('Nothing matches'), findsOneWidget);
    r.state.dispose();
  });

  testWidgets('add torrent file pick success + failure + cancel',
      (tester) async {
    final fake = FakeFilePickerPlatform();
    FilePickerPlatform.instance = fake;
    addTearDown(() =>
        FilePickerPlatform.instance = MethodChannelFilePicker());
    final r = await pump(tester);
    await tester.tap(find.byTooltip('Add torrent'));
    await tester.pumpAndSettle();

    // empty pick
    fake.next = [];
    await tester.tap(find.text('.torrent file'));
    await tester.pumpAndSettle();

    // success pick
    fake.next = [FakePlatformFile(name: 'linux.torrent')];
    await tester.tap(find.text('.torrent file'));
    await tester.pumpAndSettle();
    expect(r.api.calls, contains('addFile:linux.torrent'));

    // reopen sheet, category picker, then failing pick
    await tester.tap(find.byTooltip('Add torrent'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('iso').last);
    await tester.pumpAndSettle();
    fake.next = [
      FakePlatformFile(name: 'bad.torrent')..readError = StateError('io')
    ];
    await tester.tap(find.text('.torrent file'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Bad state'), findsOneWidget);
    r.state.dispose();
  });

  testWidgets('add torrent submit failure shows error', (tester) async {
    final r = await pump(tester);
    await tester.tap(find.byTooltip('Add torrent'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(
            TextField, 'Magnet link or torrent URL, one per line'),
        'magnet:?xt=x');
    r.api.failNextCall = true;
    await tester.tap(find.text('Add').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('boom'), findsOneWidget);
    r.state.dispose();
  });

  testWidgets('add torrent sheet standalone + category none', (tester) async {
    final r = await pump(tester);
    await tester.tap(find.byTooltip('Add torrent'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No category'));
    await tester.pumpAndSettle();
    r.state.dispose();
  });

  testWidgets('detail page: close button, paused resume, peers rows',
      (tester) async {
    final r = await pump(tester);
    r.api.props['h2'] = const TorrentProperties();
    r.api.peerResponses.add(TorrentDataUpdate.fromJson({
      'rid': 1,
      'full_update': true,
      'peers': {
        '1.1.1.1:1': {
          'ip': '1.1.1.1',
          'port': 1,
          'client': 'qB',
          'country': 'NL',
          'connection': 'μTP',
          'dl_speed': 5,
          'up_speed': 2,
        },
        '2.2.2.2:2': {'ip': '2.2.2.2', 'port': 2},
      }
    }));
    // open paused torrent in compact (push detail page)
    await tester.tap(find.text('beta'));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // peers tab renders rows
    await tester.tap(find.descendant(of: find.byType(TabBar), matching: find.text('Peers')));
    await tester.pumpAndSettle();
    expect(find.text('1.1.1.1:1'), findsOneWidget);
    expect(find.text('2.2.2.2:2'), findsOneWidget);

    // resume via header on paused torrent
    await tester.tap(find.byTooltip('Resume'));
    await tester.pumpAndSettle();
    expect(r.api.calls, contains('resume:modern'));

    // add tracker dialog cancel
    await tester.tap(find.text('Trackers'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add tracker'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // close via header button (TorrentDetailPage onClose)
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Torrents'), findsWidgets);
    r.state.dispose();
  });

  testWidgets('panel opens detail when hash set without props',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final r = await makeConnectedState();
    r.api.mainDataResponses.add(fullUpdate(torrents: {'h1': tj('alpha')}));
    await r.state.refreshOnce();
    r.state.detailHash = 'h1'; // set without loading detail
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
        value: r.state, child: const OrientApp()));
    await tester.pumpAndSettle();
    expect(find.text('Trackers'), findsOneWidget);
    r.state.dispose();
  });

  testWidgets('transfer page alt statuses render', (tester) async {
    final r = await pump(tester);
    await tester.tap(find.text('Speed'));
    await tester.pumpAndSettle();
    r.state.serverState.connectionStatus = 'firewalled';
    r.state.applySettings();
    await tester.pumpAndSettle();
    expect(find.text('Firewalled', skipOffstage: false), findsWidgets);
    r.state.serverState.connectionStatus = 'down';
    r.state.applySettings();
    await tester.pumpAndSettle();
    expect(find.text('Disconnected', skipOffstage: false), findsWidgets);
    r.state.dispose();
  });

  testWidgets('rss open item without articleUrl uses torrentUrl',
      (tester) async {
    final r = await pump(tester);
    r.api.rssResult = RssFeedNode.fromFeedsJson({
      'F': {
        'url': 'u',
        'articles': [
          {'id': '1', 'title': 'magnet only', 'torrentURL': 'magnet:?x'},
        ]
      }
    });
    await tester.tap(find.text('RSS'));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await tester.tap(find.text('magnet only'));
    await tester.pumpAndSettle();
    expect(r.api.calls, contains('rssRead:F'));

    // refresh all + cancel add feed + remove selected feed resets chip
    await tester.tap(find.byTooltip('Refresh all'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add feed'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('F'));
    await tester.pumpAndSettle();
    await tester.longPress(find.textContaining('F'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unsubscribe'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove').last);
    await tester.pumpAndSettle();
    r.state.dispose();
  });
}
