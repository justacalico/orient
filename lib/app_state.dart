import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'models/rss.dart';
import 'models/server_profile.dart';
import 'models/torrent.dart';
import 'models/torrent_detail.dart';
import 'models/transfer.dart';
import 'services/qb_api.dart';
import 'services/server_store.dart';
import 'services/settings.dart';

enum ConnectionPhase { disconnected, connecting, connected, failed }

enum TorrentSort {
  name,
  size,
  progress,
  dlspeed,
  upspeed,
  eta,
  ratio,
  addedOn,
  priority,
  state;

  String get label => switch (this) {
        TorrentSort.name => 'Name',
        TorrentSort.size => 'Size',
        TorrentSort.progress => 'Progress',
        TorrentSort.dlspeed => 'Download speed',
        TorrentSort.upspeed => 'Upload speed',
        TorrentSort.eta => 'ETA',
        TorrentSort.ratio => 'Ratio',
        TorrentSort.addedOn => 'Added on',
        TorrentSort.priority => 'Queue priority',
        TorrentSort.state => 'State',
      };
}

/// Single source of truth for the whole app. Created once above MaterialApp;
/// layout changes never recreate it.
class AppState extends ChangeNotifier {
  AppState({
    required this.settings,
    required this.store,
    QbApi Function(ServerProfile profile)? apiFactory,
    this.autoPoll = true,
  }) : _apiFactory = apiFactory ?? ((p) => QbApi(profile: p));

  final Settings settings;
  final ServerStore store;
  final QbApi Function(ServerProfile) _apiFactory;
  final bool autoPoll;

  // Connection
  ConnectionPhase phase = ConnectionPhase.disconnected;
  String? lastError;
  ServerProfile? activeProfile;
  QbApi? _api;
  bool _modernVerbs = false;
  String serverVersion = '';
  String webApiVersion = '';

  // Sync data
  final Map<String, Torrent> torrents = {};
  final Map<String, Category> categories = {};
  final Set<String> tags = {};
  final Map<String, List<String>> trackerToHashes = {};
  final ServerState serverState = ServerState();
  int _rid = 0;
  Timer? _pollTimer;
  bool _pollInFlight = false;
  bool _loggedIn = false;

  // Speed history for the graph, newest last.
  static const speedHistoryLength = 120;
  final List<int> dlHistory = [];
  final List<int> upHistory = [];

  // View state
  TorrentFilter filter = TorrentFilter.all;
  String? filterCategory;
  String? filterTag;
  String? filterTracker;
  String searchQuery = '';
  TorrentSort sort = TorrentSort.priority;
  bool sortDescending = false;
  final Set<String> selected = {};
  String? detailHash;

  // Detail cache
  final Map<String, TorrentProperties> detailProperties = {};
  final Map<String, List<TorrentFile>> detailFiles = {};
  final Map<String, List<TorrentTracker>> detailTrackers = {};
  final Map<String, List<Peer>> detailPeers = {};
  int _peersRid = 0;

  // RSS
  RssFeedNode? rssRoot;
  bool rssLoading = false;

  QbApi? get api => _api;
  bool get isConnected => phase == ConnectionPhase.connected;
  bool get modernVerbs => _modernVerbs;

  List<ServerProfile> get servers => store.servers;

  void applySettings() {
    _restartTimer();
    notifyListeners();
  }

  // -- connection --------------------------------------------------------------

  Future<void> connect(ServerProfile profile) async {
    await disconnect();
    activeProfile = profile;
    phase = ConnectionPhase.connecting;
    lastError = null;
    _resetSyncData();
    _api = _apiFactory(profile);
    notifyListeners();
    try {
      final ok = await _api!.login();
      if (!ok) {
        throw const QbApiException('Wrong username or password');
      }
      _loggedIn = true;
      final info = await _api!.versionInfo();
      serverVersion = info.version;
      webApiVersion = info.api;
      _modernVerbs = QbApi.supportsStopStart(info.api);
      phase = ConnectionPhase.connected;
      await store.setLastServer(profile.id);
      await refreshOnce();
      _restartTimer();
    } on QbApiException catch (e) {
      phase = ConnectionPhase.failed;
      lastError = e.message;
    } catch (e) {
      phase = ConnectionPhase.failed;
      lastError = '$e';
    }
    notifyListeners();
  }

  Future<void> disconnect() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    _loggedIn = false;
    final api = _api;
    _api = null;
    if (api != null && api.hasSession) {
      unawaited(api.logout().catchError((_) {}));
    }
    activeProfile = null;
    phase = ConnectionPhase.disconnected;
    _resetSyncData();
    notifyListeners();
  }

  void _resetSyncData() {
    _rid = 0;
    _peersRid = 0;
    torrents.clear();
    categories.clear();
    tags.clear();
    trackerToHashes.clear();
    dlHistory.clear();
    upHistory.clear();
    selected.clear();
    detailHash = null;
    detailProperties.clear();
    detailFiles.clear();
    detailTrackers.clear();
    detailPeers.clear();
    rssRoot = null;
    filterCategory = null;
    filterTag = null;
    filterTracker = null;
  }

  void _restartTimer() {
    _pollTimer?.cancel();
    if (!autoPoll || !isConnected) return;
    _pollTimer = Timer.periodic(settings.pollInterval, (_) => refreshOnce());
  }

  /// One sync round-trip. Drives itself via the poll timer; tests call it
  /// directly.
  Future<void> refreshOnce() async {
    final api = _api;
    if (api == null || _pollInFlight || !_loggedIn) return;
    _pollInFlight = true;
    try {
      final update = await api.mainData(_rid);
      _rid = update.rid;
      _applyUpdate(update);
      if (phase != ConnectionPhase.connected) {
        phase = ConnectionPhase.connected;
      }
      lastError = null;
      if (detailHash != null) unawaited(_refreshPeers(detailHash!));
      if (rssRoot != null) unawaited(refreshRss());
    } on QbApiException catch (e) {
      if (e.authFailure) {
        _loggedIn = false;
        await _relogin();
      } else {
        lastError = e.message;
      }
    } catch (e) {
      lastError = '$e';
    } finally {
      _pollInFlight = false;
      notifyListeners();
    }
  }

  Future<void> _relogin() async {
    final api = _api;
    if (api == null) return;
    try {
      _loggedIn = await api.login();
      if (_loggedIn) _rid = 0;
    } catch (_) {
      _loggedIn = false;
      lastError = 'Re-authentication failed';
    }
  }

  void _applyUpdate(MainDataUpdate u) {
    if (u.fullUpdate) {
      torrents.clear();
      categories.clear();
      tags.clear();
      trackerToHashes.clear();
    }
    for (final entry in u.torrents.entries) {
      final existing = torrents[entry.key];
      if (existing != null) {
        existing.applyJson(entry.value);
      } else {
        torrents[entry.key] = Torrent.fromJson(entry.key, entry.value);
      }
    }
    for (final hash in u.torrentsRemoved) {
      torrents.remove(hash);
      selected.remove(hash);
      if (detailHash == hash) detailHash = null;
      detailProperties.remove(hash);
      detailFiles.remove(hash);
      detailTrackers.remove(hash);
      detailPeers.remove(hash);
    }
    for (final entry in u.categories.entries) {
      categories[entry.key] = Category.fromJson(entry.key, entry.value);
    }
    for (final name in u.categoriesRemoved) {
      categories.remove(name);
    }
    tags.addAll(u.tags);
    tags.removeAll(u.tagsRemoved);
    trackerToHashes.addAll(u.trackers);
    for (final t in u.trackersRemoved) {
      trackerToHashes.remove(t);
    }
    if (u.serverState != null) {
      serverState.applyJson(u.serverState!);
      _recordSpeeds();
    }
  }

  void _recordSpeeds() {
    dlHistory.add(serverState.dlInfoSpeed);
    upHistory.add(serverState.upInfoSpeed);
    if (dlHistory.length > speedHistoryLength) {
      dlHistory.removeRange(0, dlHistory.length - speedHistoryLength);
      upHistory.removeRange(0, upHistory.length - speedHistoryLength);
    }
  }

  // -- view state ----------------------------------------------------------------

  void setFilter(TorrentFilter f) {
    filter = f;
    notifyListeners();
  }

  void setCategory(String? c) {
    filterCategory = c;
    notifyListeners();
  }

  void setTag(String? t) {
    filterTag = t;
    notifyListeners();
  }

  void setTracker(String? t) {
    filterTracker = t;
    notifyListeners();
  }

  void setSearch(String q) {
    searchQuery = q;
    notifyListeners();
  }

  void setSort(TorrentSort s, {bool? descending}) {
    if (sort == s && descending == null) {
      sortDescending = !sortDescending;
    } else {
      sort = s;
      sortDescending = descending ?? sortDescending;
    }
    notifyListeners();
  }

  void select(String hash, {bool toggle = true}) {
    if (toggle && selected.contains(hash)) {
      selected.remove(hash);
    } else {
      selected.add(hash);
    }
    notifyListeners();
  }

  void selectOnly(String hash) {
    selected
      ..clear()
      ..add(hash);
    notifyListeners();
  }

  void clearSelection() {
    selected.clear();
    notifyListeners();
  }

  void openDetail(String hash) {
    detailHash = hash;
    _peersRid = 0;
    notifyListeners();
    unawaited(loadDetail(hash));
  }

  void closeDetail() {
    detailHash = null;
    notifyListeners();
  }

  // -- filtered view ---------------------------------------------------------------

  List<Torrent> get visibleTorrents {
    var list = torrents.values.where((t) {
      switch (filter) {
        case TorrentFilter.all:
          break;
        case TorrentFilter.downloading:
          if (!t.state.isDownloading) return false;
        case TorrentFilter.seeding:
          if (!t.state.isSeeding) return false;
        case TorrentFilter.completed:
          if (t.progress < 1.0) return false;
        case TorrentFilter.paused:
          if (!t.isPaused) return false;
        case TorrentFilter.active:
          if (t.dlspeed <= 0 && t.upspeed <= 0) return false;
        case TorrentFilter.inactive:
          if (t.dlspeed > 0 || t.upspeed > 0) return false;
        case TorrentFilter.errored:
          if (!t.state.isErrored) return false;
      }
      if (filterCategory != null && t.category != filterCategory) return false;
      if (filterTag != null && !t.tags.contains(filterTag)) return false;
      if (filterTracker != null &&
          !(trackerToHashes[filterTracker]?.contains(t.hash) ?? false)) {
        return false;
      }
      if (searchQuery.isNotEmpty &&
          !t.name.toLowerCase().contains(searchQuery.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();
    list.sort(_compare);
    return list;
  }

  int _compare(Torrent a, Torrent b) {
    final result = switch (sort) {
      TorrentSort.name => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      TorrentSort.size => a.size.compareTo(b.size),
      TorrentSort.progress => a.progress.compareTo(b.progress),
      TorrentSort.dlspeed => a.dlspeed.compareTo(b.dlspeed),
      TorrentSort.upspeed => a.upspeed.compareTo(b.upspeed),
      TorrentSort.eta => a.eta.compareTo(b.eta),
      TorrentSort.ratio => a.ratio.compareTo(b.ratio),
      TorrentSort.addedOn => a.addedOn.compareTo(b.addedOn),
      TorrentSort.priority => a.priority.compareTo(b.priority),
      TorrentSort.state => a.state.index.compareTo(b.state.index),
    };
    return sortDescending ? -result : result;
  }

  // -- detail loading ------------------------------------------------------------------

  Future<void> loadDetail(String hash) async {
    final api = _api;
    if (api == null || !_loggedIn) return;
    try {
      final results = await Future.wait([
        api.torrentProperties(hash),
        api.torrentContents(hash),
        api.torrentTrackers(hash),
      ]);
      detailProperties[hash] = results[0] as TorrentProperties;
      detailFiles[hash] = results[1] as List<TorrentFile>;
      detailTrackers[hash] = results[2] as List<TorrentTracker>;
      await _refreshPeers(hash, full: true);
    } catch (e) {
      lastError = '$e';
    }
    notifyListeners();
  }

  Future<void> _refreshPeers(String hash, {bool full = false}) async {
    final api = _api;
    if (api == null || detailHash != hash) return;
    try {
      final update = await api.torrentData(hash, full ? 0 : _peersRid);
      _peersRid = update.rid;
      final existing = detailPeers[hash] ?? [];
      if (update.fullUpdate || full) {
        detailPeers[hash] = update.peers;
      } else {
        existing.removeWhere((p) => update.peersRemoved.contains(p.address));
        final byAddress = {for (final p in existing) p.address: p};
        for (final p in update.peers) {
          byAddress[p.address] = p;
        }
        detailPeers[hash] = byAddress.values.toList();
      }
    } catch (_) {
      // Peer polling is best-effort.
    }
  }

  // -- actions ------------------------------------------------------------------------

  /// Runs an api call then forces a resync so the UI reflects it.
  Future<void> _act(Future<void> Function(QbApi api) call) async {
    final api = _api;
    if (api == null) return;
    try {
      await call(api);
      _rid = 0;
      await refreshOnce();
    } on QbApiException catch (e) {
      lastError = e.message;
      notifyListeners();
      rethrow;
    }
  }

  List<String> get _targetHashes =>
      selected.isNotEmpty ? selected.toList() : const [];

  Future<void> pauseSelected() =>
      _act((a) => a.pauseTorrents(_targetHashes, modern: _modernVerbs));

  Future<void> resumeSelected() =>
      _act((a) => a.resumeTorrents(_targetHashes, modern: _modernVerbs));

  Future<void> deleteSelected({bool deleteFiles = false}) =>
      _act((a) => a.deleteTorrents(_targetHashes, deleteFiles: deleteFiles));

  Future<void> recheckSelected() => _act((a) => a.recheckTorrents(_targetHashes));

  Future<void> reannounceSelected() =>
      _act((a) => a.reannounceTorrents(_targetHashes));

  Future<void> setCategoryFor(List<String> hashes, String category) =>
      _act((a) => a.setCategory(hashes, category));

  Future<void> addTagsFor(List<String> hashes, List<String> t) =>
      _act((a) => a.addTags(hashes, t));

  Future<void> removeTagsFor(List<String> hashes, List<String> t) =>
      _act((a) => a.removeTags(hashes, t));

  Future<void> createCategory(String name, String savePath) =>
      _act((a) => a.createCategory(name, savePath: savePath));

  Future<void> editCategory(String name, String savePath) =>
      _act((a) => a.editCategory(name, savePath));

  Future<void> removeCategories(List<String> names) =>
      _act((a) => a.removeCategories(names));

  Future<void> createTags(List<String> t) => _act((a) => a.createTags(t));

  Future<void> deleteTags(List<String> t) => _act((a) => a.deleteTags(t));

  Future<void> setLocationFor(List<String> hashes, String location) =>
      _act((a) => a.setLocation(hashes, location));

  Future<void> renameTorrent(String hash, String name) =>
      _act((a) => a.rename(hash, name));

  Future<void> setDownloadLimitFor(List<String> hashes, int limit) =>
      _act((a) => a.setDownloadLimit(hashes, limit));

  Future<void> setUploadLimitFor(List<String> hashes, int limit) =>
      _act((a) => a.setUploadLimit(hashes, limit));

  Future<void> setShareLimitsFor(List<String> hashes,
          {double ratio = -2, int seedingTime = -2}) =>
      _act((a) => a.setShareLimits(hashes,
          ratio: ratio, seedingTime: seedingTime));

  Future<void> toggleSequentialFor(List<String> hashes) =>
      _act((a) => a.toggleSequential(hashes));

  Future<void> toggleFirstLastFor(List<String> hashes) =>
      _act((a) => a.toggleFirstLastPiece(hashes));

  Future<void> setForceStartFor(List<String> hashes, bool value) =>
      _act((a) => a.setForceStart(hashes, value));

  Future<void> setAutoTmmFor(List<String> hashes, bool value) =>
      _act((a) => a.setAutoManagement(hashes, value));

  Future<void> topPrioFor(List<String> hashes) => _act((a) => a.topPrio(hashes));
  Future<void> bottomPrioFor(List<String> hashes) =>
      _act((a) => a.bottomPrio(hashes));
  Future<void> increasePrioFor(List<String> hashes) =>
      _act((a) => a.increasePrio(hashes));
  Future<void> decreasePrioFor(List<String> hashes) =>
      _act((a) => a.decreasePrio(hashes));

  Future<void> setFilePriority(String hash, List<int> ids, int priority) async {
    final api = _api;
    if (api == null) return;
    await api.setFilePriority(hash, ids, priority);
    await loadDetail(hash);
  }

  Future<void> addTrackers(String hash, List<String> urls) async {
    await _act((a) => a.addTrackers(hash, urls));
    await loadDetail(hash);
  }

  Future<void> removeTrackers(String hash, List<String> urls) async {
    await _act((a) => a.removeTrackers(hash, urls));
    await loadDetail(hash);
  }

  Future<void> addTorrentUrls(String urls,
          {String? savePath, String? category, bool? paused}) =>
      _act((a) =>
          a.addTorrentUrls(urls, savePath: savePath, category: category, paused: paused));

  Future<void> addTorrentFile(List<int> bytes, String fileName,
          {String? savePath, String? category, bool? paused}) =>
      _act((a) => a.addTorrentFile(
            Uint8List.fromList(bytes),
            fileName,
            savePath: savePath,
            category: category,
            paused: paused,
          ));

  Future<void> toggleAltSpeed() => _act((a) => a.toggleSpeedLimitsMode());

  Future<void> setGlobalDlLimit(int bytes) =>
      _act((a) => a.setGlobalDownloadLimit(bytes));

  Future<void> setGlobalUlLimit(int bytes) =>
      _act((a) => a.setGlobalUploadLimit(bytes));

  Future<void> setPreference(String key, Object? value) =>
      _act((a) => a.setPreferences({key: value}));

  // -- rss ------------------------------------------------------------------------------

  Future<void> refreshRss() async {
    final api = _api;
    if (api == null || rssLoading) return;
    rssLoading = true;
    try {
      rssRoot = await api.rssFeeds();
    } catch (_) {
      // RSS may be disabled on the server.
    } finally {
      rssLoading = false;
      notifyListeners();
    }
  }

  Future<void> rssAdd(String url, String path) async {
    final api = _api;
    if (api == null) return;
    await api.rssAddFeed(url, path);
    await refreshRss();
  }

  Future<void> rssRemove(String path) async {
    final api = _api;
    if (api == null) return;
    await api.rssRemoveFeed(path);
    await refreshRss();
  }

  Future<void> rssRefresh(String path) async {
    final api = _api;
    if (api == null) return;
    await api.rssRefreshItem(path);
    await refreshRss();
  }

  Future<void> rssMarkRead(String path, [String? articleId]) async {
    final api = _api;
    if (api == null) return;
    await api.rssMarkAsRead(path, articleId);
    await refreshRss();
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _pollTimer?.cancel();
    _api?.close();
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }
}
