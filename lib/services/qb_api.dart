import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/rss.dart';
import '../models/server_profile.dart';
import '../models/torrent_detail.dart';
import '../models/transfer.dart';

class QbApiException implements Exception {
  const QbApiException(this.message, {this.statusCode, this.authFailure = false});

  final String message;
  final int? statusCode;
  final bool authFailure;

  @override
  String toString() => message;
}

/// Thin client over the qBittorrent WebUI API v2. Keeps the SID cookie and
/// re-sends it on every request.
class QbApi {
  QbApi({required this.profile, http.Client? client})
      : _client = client ?? http.Client();

  final ServerProfile profile;
  final http.Client _client;
  String? _sid;

  bool get hasSession => _sid != null;

  /// Drops the session cookie without telling the server.
  void clearSession() => _sid = null;

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('${profile.baseUrl}/api/v2$path')
        .replace(queryParameters: query);
  }

  void _storeCookie(http.BaseResponse res) {
    final setCookie = res.headers['set-cookie'];
    if (setCookie == null) return;
    for (final part in setCookie.split(',')) {
      final trimmed = part.trim();
      if (trimmed.startsWith('SID=')) {
        _sid = trimmed.split(';').first;
      }
    }
  }

  Map<String, String> get _headers => {
        'Cookie': ?_sid,
        'Referer': profile.baseUrl,
      };

  void _checkStatus(http.Response res, {List<int> ok = const [200]}) {
    if (ok.contains(res.statusCode)) return;
    if (res.statusCode == 403) {
      _sid = null;
      throw const QbApiException('Session expired or banned',
          statusCode: 403, authFailure: true);
    }
    throw QbApiException('HTTP ${res.statusCode}: ${res.body}',
        statusCode: res.statusCode);
  }

  Future<http.Response> _get(String path, [Map<String, String>? query]) async {
    try {
      final res = await _client.get(_uri(path, query), headers: _headers);
      _storeCookie(res);
      _checkStatus(res);
      return res;
    } on QbApiException {
      rethrow;
    } catch (e) {
      throw QbApiException('Connection failed: $e');
    }
  }

  Future<http.Response> _post(String path, Map<String, String> fields) async {
    try {
      final res =
          await _client.post(_uri(path), headers: _headers, body: fields);
      _storeCookie(res);
      _checkStatus(res);
      return res;
    } on QbApiException {
      rethrow;
    } catch (e) {
      throw QbApiException('Connection failed: $e');
    }
  }

  Future<http.StreamedResponse> _postMultipart(
      String path,
      Map<String, String> fields,
      List<http.MultipartFile> files) async {
    final req = http.MultipartRequest('POST', _uri(path))
      ..headers.addAll(_headers)
      ..fields.addAll(fields)
      ..files.addAll(files);
    try {
      final streamed = await _client.send(req);
      _storeCookie(streamed);
      final res = await http.Response.fromStream(streamed);
      _checkStatus(res);
      return streamed;
    } on QbApiException {
      rethrow;
    } catch (e) {
      throw QbApiException('Connection failed: $e');
    }
  }

  Map<String, dynamic> _decodeMap(http.Response res) {
    final body = jsonDecode(res.body);
    if (body is Map) return Map<String, dynamic>.from(body);
    return {};
  }

  List<dynamic> _decodeList(http.Response res) {
    final body = jsonDecode(res.body);
    if (body is List) return body;
    return const [];
  }

  // -- auth -----------------------------------------------------------------

  /// Returns true when the login succeeded. Throws on unreachable servers,
  /// returns false on wrong credentials.
  Future<bool> login() async {
    final res = await _client.post(
      _uri('/auth/login'),
      headers: {'Referer': profile.baseUrl},
      body: {'username': profile.username, 'password': profile.password},
    );
    _storeCookie(res);
    _checkStatus(res);
    if (res.body.trim() == 'Ok.') return true;
    if (res.body.contains('banned')) {
      throw const QbApiException('IP banned - too many failed logins');
    }
    return false;
  }

  Future<void> logout() async {
    try {
      await _get('/auth/logout');
    } finally {
      _sid = null;
    }
  }

  // -- app ------------------------------------------------------------------

  Future<String> appVersion() async => (await _get('/app/version')).body;

  Future<String> webApiVersion() async =>
      (await _get('/app/webapiVersion')).body;

  /// Build info needed to detect API support for features like stop/pause.
  Future<({String version, String api})> versionInfo() async {
    return (version: await appVersion(), api: await webApiVersion());
  }

  /// `true` when the server uses the newer stop/start verbs (qBit >= 5.0).
  static bool supportsStopStart(String apiVersion) {
    final major = int.tryParse(apiVersion.split('.').first) ?? 0;
    return apiVersion.startsWith('2.11') || major >= 3;
  }

  Future<Map<String, dynamic>> appPreferences() async =>
      _decodeMap(await _get('/app/preferences'));

  Future<void> setPreferences(Map<String, dynamic> prefs) =>
      _post('/app/setPreferences', {'json': jsonEncode(prefs)});

  // -- sync -----------------------------------------------------------------

  Future<MainDataUpdate> mainData(int rid) async {
    final res = await _get('/sync/maindata', {'rid': '$rid'});
    return MainDataUpdate.fromJson(_decodeMap(res));
  }

  Future<TorrentDataUpdate> torrentData(String hash, int rid) async {
    final res = await _get('/sync/torrentdata', {'hash': hash, 'rid': '$rid'});
    return TorrentDataUpdate.fromJson(_decodeMap(res));
  }

  // -- torrents -------------------------------------------------------------

  Future<TorrentProperties> torrentProperties(String hash) async {
    final res = await _get('/torrents/properties', {'hash': hash});
    return TorrentProperties.fromJson(_decodeMap(res));
  }

  Future<List<TorrentTracker>> torrentTrackers(String hash) async {
    final res = await _get('/torrents/trackers', {'hash': hash});
    return _decodeList(res)
        .map((e) => TorrentTracker.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<TorrentFile>> torrentContents(String hash) async {
    final res = await _get('/torrents/contents', {'hash': hash});
    return _decodeList(res)
        .map((e) => TorrentFile.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> addTorrentUrls(
    String urls, {
    String? savePath,
    String? category,
    List<String>? tags,
    bool? paused,
    bool? sequential,
    bool? firstLastPiece,
    String? contentLayout,
  }) {
    return _post('/torrents/add', {
      'urls': urls,
      if (savePath != null && savePath.isNotEmpty) 'savepath': savePath,
      if (category != null && category.isNotEmpty) 'category': category,
      if (tags != null && tags.isNotEmpty) 'tags': tags.join(','),
      if (paused != null) 'paused': '$paused',
      if (sequential != null) 'sequentialDownload': '$sequential',
      if (firstLastPiece != null) 'firstLastPiecePrio': '$firstLastPiece',
      if (contentLayout != null && contentLayout.isNotEmpty)
        'contentLayout': contentLayout,
    });
  }

  Future<void> addTorrentFile(
    Uint8List bytes,
    String fileName, {
    String? savePath,
    String? category,
    List<String>? tags,
    bool? paused,
  }) {
    return _postMultipart('/torrents/add', {
      if (savePath != null && savePath.isNotEmpty) 'savepath': savePath,
      if (category != null && category.isNotEmpty) 'category': category,
      if (tags != null && tags.isNotEmpty) 'tags': tags.join(','),
      if (paused != null) 'paused': '$paused',
    }, [
      http.MultipartFile.fromBytes('torrents', bytes, filename: fileName),
    ]);
  }

  String _hashesParam(List<String> hashes) => hashes.join('|');

  Future<void> pauseTorrents(List<String> h, {bool modern = false}) =>
      _post('/torrents/${modern ? 'stop' : 'pause'}', {'hashes': _hashesParam(h)});

  Future<void> resumeTorrents(List<String> h, {bool modern = false}) =>
      _post('/torrents/${modern ? 'start' : 'resume'}', {'hashes': _hashesParam(h)});

  Future<void> deleteTorrents(List<String> h, {bool deleteFiles = false}) =>
      _post('/torrents/delete',
          {'hashes': _hashesParam(h), 'deleteFiles': '$deleteFiles'});

  Future<void> recheckTorrents(List<String> h) =>
      _post('/torrents/recheck', {'hashes': _hashesParam(h)});

  Future<void> reannounceTorrents(List<String> h) =>
      _post('/torrents/reannounce', {'hashes': _hashesParam(h)});

  Future<void> setCategory(List<String> h, String category) =>
      _post('/torrents/setCategory', {'hashes': _hashesParam(h), 'category': category});

  Future<void> addTags(List<String> h, List<String> tags) =>
      _post('/torrents/addTags', {'hashes': _hashesParam(h), 'tags': tags.join(',')});

  Future<void> removeTags(List<String> h, List<String> tags) =>
      _post('/torrents/removeTags', {'hashes': _hashesParam(h), 'tags': tags.join(',')});

  Future<void> setLocation(List<String> h, String location) =>
      _post('/torrents/setLocation', {'hashes': _hashesParam(h), 'location': location});

  Future<void> rename(String hash, String name) =>
      _post('/torrents/rename', {'hash': hash, 'name': name});

  Future<void> topPrio(List<String> h) =>
      _post('/torrents/topPrio', {'hashes': _hashesParam(h)});

  Future<void> bottomPrio(List<String> h) =>
      _post('/torrents/bottomPrio', {'hashes': _hashesParam(h)});

  Future<void> increasePrio(List<String> h) =>
      _post('/torrents/increasePrio', {'hashes': _hashesParam(h)});

  Future<void> decreasePrio(List<String> h) =>
      _post('/torrents/decreasePrio', {'hashes': _hashesParam(h)});

  Future<void> setDownloadLimit(List<String> h, int limit) =>
      _post('/torrents/setDownloadLimit',
          {'hashes': _hashesParam(h), 'limit': '$limit'});

  Future<void> setUploadLimit(List<String> h, int limit) =>
      _post('/torrents/setUploadLimit',
          {'hashes': _hashesParam(h), 'limit': '$limit'});

  Future<void> setShareLimits(List<String> h,
          {double ratio = -2, int seedingTime = -2, int inactiveSeedingTime = -2}) =>
      _post('/torrents/setShareLimits', {
        'hashes': _hashesParam(h),
        'ratioLimit': '$ratio',
        'seedingTimeLimit': '$seedingTime',
        'inactiveSeedingTimeLimit': '$inactiveSeedingTime',
      });

  Future<void> toggleSequential(List<String> h) =>
      _post('/torrents/toggleSequentialDownload', {'hashes': _hashesParam(h)});

  Future<void> toggleFirstLastPiece(List<String> h) =>
      _post('/torrents/toggleFirstLastPiecePrio', {'hashes': _hashesParam(h)});

  Future<void> setForceStart(List<String> h, bool value) =>
      _post('/torrents/setForceStart',
          {'hashes': _hashesParam(h), 'value': '$value'});

  Future<void> setSuperSeeding(List<String> h, bool value) =>
      _post('/torrents/setSuperSeeding',
          {'hashes': _hashesParam(h), 'value': '$value'});

  Future<void> setAutoManagement(List<String> h, bool enable) =>
      _post('/torrents/setAutoManagement',
          {'hashes': _hashesParam(h), 'enable': '$enable'});

  Future<void> setFilePriority(String hash, List<int> fileIds, int priority) =>
      _post('/torrents/filePrio', {
        'hash': hash,
        'id': fileIds.join('|'),
        'priority': '$priority',
      });

  Future<void> addTrackers(String hash, List<String> urls) =>
      _post('/torrents/addTrackers', {'hash': hash, 'urls': urls.join('\n')});

  Future<void> removeTrackers(String hash, List<String> urls) =>
      _post('/torrents/removeTrackers', {'hash': hash, 'urls': urls.join('|')});

  Future<void> editTracker(String hash, String origUrl, String newUrl) =>
      _post('/torrents/editTracker',
          {'hash': hash, 'origUrl': origUrl, 'newUrl': newUrl});

  // -- categories & tags ------------------------------------------------------

  Future<void> createCategory(String name, {String savePath = ''}) =>
      _post('/app/createCategory', {'category': name, 'savePath': savePath});

  Future<void> editCategory(String name, String savePath) =>
      _post('/app/editCategory', {'category': name, 'savePath': savePath});

  Future<void> removeCategories(List<String> names) =>
      _post('/app/removeCategories', {'categories': names.join('\n')});

  Future<void> createTags(List<String> tags) =>
      _post('/app/createTags', {'tags': tags.join(',')});

  Future<void> deleteTags(List<String> tags) =>
      _post('/app/deleteTags', {'tags': tags.join(',')});

  // -- transfer ---------------------------------------------------------------

  /// Alternative speed limits: 1 = enabled, 0 = disabled.
  Future<int> speedLimitsMode() async {
    final res = await _get('/transfer/speedLimitsMode');
    return int.tryParse(res.body.trim()) ?? 0;
  }

  Future<void> toggleSpeedLimitsMode() =>
      _post('/transfer/toggleSpeedLimitsMode', {});

  Future<void> setGlobalDownloadLimit(int bytes) =>
      _post('/transfer/setDownloadLimit', {'limit': '$bytes'});

  Future<void> setGlobalUploadLimit(int bytes) =>
      _post('/transfer/setUploadLimit', {'limit': '$bytes'});

  // -- rss --------------------------------------------------------------------

  Future<RssFeedNode> rssFeeds({bool withData = true}) async {
    final res =
        await _get('/rss/items', {'withData': '$withData'});
    return RssFeedNode.fromFeedsJson(_decodeMap(res));
  }

  Future<void> rssAddFeed(String url, String path) =>
      _post('/rss/addFeed', {'url': url, 'path': path});

  Future<void> rssRemoveFeed(String path) =>
      _post('/rss/removeItem', {'path': path});

  Future<void> rssRefreshItem(String path) =>
      _post('/rss/refreshItem', {'itemPath': path});

  Future<void> rssMarkAsRead(String path, [String? articleId]) =>
      _post('/rss/markAsRead', {
        'itemPath': path,
        'articleId': ?articleId,
      });

  void close() => _client.close();
}
