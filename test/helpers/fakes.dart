import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:orient/app_state.dart';
import 'package:orient/models/rss.dart';
import 'package:orient/models/server_profile.dart';
import 'package:orient/models/torrent_detail.dart';
import 'package:orient/models/transfer.dart';
import 'package:orient/services/qb_api.dart';
import 'package:orient/services/server_store.dart';
import 'package:orient/services/settings.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A recording in-memory QbApi for AppState tests.
class FakeQbApi extends QbApi {
  FakeQbApi(ServerProfile profile) : super(profile: profile);

  final List<String> calls = [];
  final List<MainDataUpdate> mainDataResponses = [];
  int mainDataCalls = 0;
  bool loginResult = true;
  Object? loginError;
  bool failNextCall = false;
  String serverVersionResponse = '5.0.0';
  String apiVersionResponse = '2.11.0';
  final Map<String, TorrentProperties> props = {};
  final Map<String, List<TorrentFile>> files = {};
  final Map<String, List<TorrentTracker>> trackersByHash = {};
  final List<TorrentDataUpdate> peerResponses = [];
  RssFeedNode? rssResult;
  Object? mainDataError;
  Object? detailError;
  Object? reloginError;

  String? _lastAction;

  String? get lastAction => _lastAction;

  Future<void> _record(String name) async {
    calls.add(name);
    _lastAction = name;
    if (failNextCall) {
      failNextCall = false;
      throw const QbApiException('boom');
    }
  }

  @override
  bool get hasSession => loginResult;

  @override
  void clearSession() {}

  @override
  Future<bool> login() async {
    calls.add('login');
    if (reloginError != null) {
      final e = reloginError!;
      reloginError = null;
      throw e;
    }
    if (loginError != null) throw loginError!;
    return loginResult;
  }

  @override
  Future<void> logout() async {
    calls.add('logout');
  }

  @override
  Future<({String version, String api})> versionInfo() async =>
      (version: serverVersionResponse, api: apiVersionResponse);

  @override
  Future<MainDataUpdate> mainData(int rid) async {
    calls.add('mainData:$rid');
    mainDataCalls++;
    if (mainDataError != null) {
      final e = mainDataError!;
      mainDataError = null;
      throw e;
    }
    if (mainDataResponses.isNotEmpty) return mainDataResponses.removeAt(0);
    return MainDataUpdate(rid: rid + 1);
  }

  @override
  Future<TorrentProperties> torrentProperties(String hash) async {
    calls.add('properties:$hash');
    if (detailError != null) throw detailError!;
    return props[hash] ?? const TorrentProperties();
  }

  @override
  Future<List<TorrentFile>> torrentContents(String hash) async {
    calls.add('contents:$hash');
    return files[hash] ?? const [];
  }

  @override
  Future<List<TorrentTracker>> torrentTrackers(String hash) async {
    calls.add('trackers:$hash');
    return trackersByHash[hash] ?? const [];
  }

  @override
  Future<TorrentDataUpdate> torrentData(String hash, int rid) async {
    calls.add('torrentData:$hash:$rid');
    if (peerResponses.isNotEmpty) return peerResponses.removeAt(0);
    return TorrentDataUpdate(rid: rid + 1);
  }

  @override
  Future<void> pauseTorrents(List<String> h, {bool modern = false}) =>
      _record('pause${modern ? ':modern' : ''}');

  @override
  Future<void> resumeTorrents(List<String> h, {bool modern = false}) =>
      _record('resume${modern ? ':modern' : ''}');

  @override
  Future<void> deleteTorrents(List<String> h, {bool deleteFiles = false}) =>
      _record('delete:$deleteFiles');

  @override
  Future<void> recheckTorrents(List<String> h) => _record('recheck');

  @override
  Future<void> reannounceTorrents(List<String> h) => _record('reannounce');

  @override
  Future<void> setCategory(List<String> h, String category) =>
      _record('setCategory:$category');

  @override
  Future<void> addTags(List<String> h, List<String> tags) =>
      _record('addTags:${tags.join(',')}');

  @override
  Future<void> removeTags(List<String> h, List<String> tags) =>
      _record('removeTags:${tags.join(',')}');

  @override
  Future<void> createCategory(String name, {String savePath = ''}) =>
      _record('createCategory:$name');

  @override
  Future<void> editCategory(String name, String savePath) =>
      _record('editCategory:$name');

  @override
  Future<void> removeCategories(List<String> names) =>
      _record('removeCategories:${names.join(',')}');

  @override
  Future<void> createTags(List<String> tags) =>
      _record('createTags:${tags.join(',')}');

  @override
  Future<void> deleteTags(List<String> tags) =>
      _record('deleteTags:${tags.join(',')}');

  @override
  Future<void> setLocation(List<String> h, String location) =>
      _record('setLocation:$location');

  @override
  Future<void> rename(String hash, String name) => _record('rename:$name');

  @override
  Future<void> topPrio(List<String> h) => _record('topPrio');

  @override
  Future<void> bottomPrio(List<String> h) => _record('bottomPrio');

  @override
  Future<void> increasePrio(List<String> h) => _record('increasePrio');

  @override
  Future<void> decreasePrio(List<String> h) => _record('decreasePrio');

  @override
  Future<void> setDownloadLimit(List<String> h, int limit) =>
      _record('dlLimit:$limit');

  @override
  Future<void> setUploadLimit(List<String> h, int limit) =>
      _record('ulLimit:$limit');

  @override
  Future<void> setShareLimits(List<String> h,
          {double ratio = -2,
          int seedingTime = -2,
          int inactiveSeedingTime = -2}) =>
      _record('shareLimits:$ratio:$seedingTime');

  @override
  Future<void> toggleSequential(List<String> h) => _record('seq');

  @override
  Future<void> toggleFirstLastPiece(List<String> h) =>
      _record('firstLast');

  @override
  Future<void> setForceStart(List<String> h, bool value) =>
      _record('forceStart:$value');

  @override
  Future<void> setSuperSeeding(List<String> h, bool value) =>
      _record('superSeeding:$value');

  @override
  Future<void> setAutoManagement(List<String> h, bool enable) =>
      _record('autoTmm:$enable');

  @override
  Future<void> setFilePriority(String hash, List<int> fileIds, int priority) =>
      _record('filePrio:${fileIds.join('|')}:$priority');

  @override
  Future<void> addTrackers(String hash, List<String> urls) =>
      _record('addTrackers:${urls.length}');

  @override
  Future<void> removeTrackers(String hash, List<String> urls) =>
      _record('removeTrackers:${urls.length}');

  @override
  Future<void> editTracker(String hash, String origUrl, String newUrl) =>
      _record('editTracker');

  @override
  Future<void> addTorrentUrls(String urls,
          {String? savePath,
          String? category,
          List<String>? tags,
          bool? paused,
          bool? sequential,
          bool? firstLastPiece,
          String? contentLayout}) =>
      _record('addUrls:$urls');

  @override
  Future<void> addTorrentFile(Uint8List bytes, String fileName,
          {String? savePath,
          String? category,
          List<String>? tags,
          bool? paused}) =>
      _record('addFile:$fileName');

  @override
  Future<int> speedLimitsMode() async => 0;

  @override
  Future<void> toggleSpeedLimitsMode() => _record('altSpeed');

  @override
  Future<void> setGlobalDownloadLimit(int bytes) => _record('gdl:$bytes');

  @override
  Future<void> setGlobalUploadLimit(int bytes) => _record('gul:$bytes');

  @override
  Future<void> setPreferences(Map<String, dynamic> prefs) =>
      _record('prefs:${prefs.keys.join(',')}');

  @override
  Future<RssFeedNode> rssFeeds({bool withData = true}) async =>
      rssResult ?? const RssFeedNode();

  @override
  Future<void> rssAddFeed(String url, String path) => _record('rssAdd:$url');

  @override
  Future<void> rssRemoveFeed(String path) => _record('rssRemove:$path');

  @override
  Future<void> rssRefreshItem(String path) => _record('rssRefresh:$path');

  @override
  Future<void> rssMarkAsRead(String path, [String? articleId]) =>
      _record('rssRead:$path');

  @override
  void close() {
    calls.add('close');
  }
}

const testProfile = ServerProfile(
  id: 'srv1',
  name: 'Testbox',
  baseUrl: 'http://localhost:8080',
  username: 'admin',
  password: 'adminadmin',
);

/// AppState wired to an in-memory store and a fake api.
Future<({AppState state, FakeQbApi api})> makeConnectedState({
  Settings? settings,
  bool autoPoll = false,
  bool loginOk = true,
}) async {
  SharedPreferences.setMockInitialValues({});
  final store = await ServerStore.load();
  FakeQbApi? api;
  final state = AppState(
    settings: settings ?? Settings(),
    store: store,
    autoPoll: autoPoll,
    apiFactory: (p) => api = FakeQbApi(p),
  );
  if (loginOk) {
    await store.upsert(testProfile);
    await state.connect(testProfile);
  }
  return (state: state, api: api ?? FakeQbApi(testProfile));
}

MainDataUpdate fullUpdate({
  Map<String, Map<String, dynamic>> torrents = const {},
  Map<String, Map<String, dynamic>> categories = const {},
  List<String> tags = const [],
  Map<String, dynamic>? serverState,
}) {
  return MainDataUpdate(
    rid: 1,
    fullUpdate: true,
    torrents: torrents,
    categories: categories,
    tags: tags,
    serverState: serverState ??
        {
          'connection_status': 'connected',
          'dht_nodes': 200,
          'dl_info_speed': 1024,
          'up_info_speed': 512,
          'dl_info_data': 100000,
          'up_info_data': 50000,
        },
  );
}

final class FakePlatformFile extends PlatformFile {
  FakePlatformFile({required this.name, this.bytes = const [1, 2, 3]});

  @override
  final String name;
  final List<int> bytes;
  Object? readError;

  @override
  Uri get uri => Uri.parse('file:///tmp/$name');

  @override
  XFile get xFile => XFile(uri.toFilePath(), name: name);

  @override
  Future<Uint8List> readAsBytes() async {
    if (readError != null) throw readError!;
    return Uint8List.fromList(bytes);
  }

  @override
  Future<int?> length() async => bytes.length;

  @override
  int? lengthSync() => bytes.length;

  @override
  Stream<Uint8List> readAsByteStream() =>
      Stream.value(Uint8List.fromList(bytes));
}

class FakeFilePickerPlatform extends FilePickerPlatform
    with MockPlatformInterfaceMixin {
  List<PlatformFile> next = [];

  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async =>
      next;
}
