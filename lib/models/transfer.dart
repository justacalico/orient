/// Global server state from `sync/maindata -> server_state`.
class ServerState {
  ServerState({
    this.connectionStatus = 'disconnected',
    this.dhtNodes = 0,
    this.dlInfoSpeed = 0,
    this.dlInfoData = 0,
    this.upInfoSpeed = 0,
    this.upInfoData = 0,
    this.dlRateLimit = 0,
    this.upRateLimit = 0,
    this.alltimeDl = 0,
    this.alltimeUl = 0,
    this.totalWastedSession = 0,
    this.freeSpaceOnDisk = 0,
    this.globalRatio = '',
    this.queuedIoJobs = 0,
    this.queueing = false,
    this.useAltSpeedLimits = false,
    this.refreshInterval = 1500,
    this.totalPeerConnections = 0,
  });

  String connectionStatus;
  int dhtNodes;
  int dlInfoSpeed;
  int dlInfoData;
  int upInfoSpeed;
  int upInfoData;
  int dlRateLimit;
  int upRateLimit;
  int alltimeDl;
  int alltimeUl;
  int totalWastedSession;
  int freeSpaceOnDisk;
  String globalRatio;
  int queuedIoJobs;
  bool queueing;
  bool useAltSpeedLimits;
  int refreshInterval;
  int totalPeerConnections;

  bool get connected => connectionStatus == 'connected';
  bool get firewalled => connectionStatus == 'firewalled';

  String get connectionLabel => switch (connectionStatus) {
        'connected' => 'Connected',
        'firewalled' => 'Firewalled',
        _ => 'Disconnected',
      };

  void applyJson(Map<String, dynamic> json) {
    if (json['connection_status'] != null) {
      connectionStatus = json['connection_status'] as String;
    }
    if (json['dht_nodes'] != null) dhtNodes = (json['dht_nodes'] as num).toInt();
    if (json['dl_info_speed'] != null) dlInfoSpeed = (json['dl_info_speed'] as num).toInt();
    if (json['dl_info_data'] != null) dlInfoData = (json['dl_info_data'] as num).toInt();
    if (json['up_info_speed'] != null) upInfoSpeed = (json['up_info_speed'] as num).toInt();
    if (json['up_info_data'] != null) upInfoData = (json['up_info_data'] as num).toInt();
    if (json['dl_rate_limit'] != null) dlRateLimit = (json['dl_rate_limit'] as num).toInt();
    if (json['up_rate_limit'] != null) upRateLimit = (json['up_rate_limit'] as num).toInt();
    if (json['alltime_dl'] != null) alltimeDl = (json['alltime_dl'] as num).toInt();
    if (json['alltime_ul'] != null) alltimeUl = (json['alltime_ul'] as num).toInt();
    if (json['total_wasted_session'] != null) totalWastedSession = (json['total_wasted_session'] as num).toInt();
    if (json['free_space_on_disk'] != null) freeSpaceOnDisk = (json['free_space_on_disk'] as num).toInt();
    if (json['global_ratio'] != null) globalRatio = json['global_ratio'] as String;
    if (json['queued_io_jobs'] != null) queuedIoJobs = (json['queued_io_jobs'] as num).toInt();
    if (json['queueing'] != null) queueing = json['queueing'] as bool;
    if (json['use_alt_speed_limits'] != null) useAltSpeedLimits = json['use_alt_speed_limits'] as bool;
    if (json['refresh_interval'] != null) refreshInterval = (json['refresh_interval'] as num).toInt();
    if (json['total_peer_connections'] != null) totalPeerConnections = (json['total_peer_connections'] as num).toInt();
  }
}

/// One incremental response from `/api/v2/sync/maindata`.
class MainDataUpdate {
  MainDataUpdate({
    required this.rid,
    this.fullUpdate = false,
    this.torrents = const {},
    this.torrentsRemoved = const [],
    this.categories = const {},
    this.categoriesRemoved = const [],
    this.tags = const [],
    this.tagsRemoved = const [],
    this.trackers = const {},
    this.trackersRemoved = const [],
    this.serverState,
  });

  final int rid;
  final bool fullUpdate;
  final Map<String, Map<String, dynamic>> torrents;
  final List<String> torrentsRemoved;
  final Map<String, Map<String, dynamic>> categories;
  final List<String> categoriesRemoved;
  final List<String> tags;
  final List<String> tagsRemoved;
  final Map<String, List<String>> trackers;
  final List<String> trackersRemoved;
  final Map<String, dynamic>? serverState;

  static Map<String, Map<String, dynamic>> _mapOfMaps(Object? raw) {
    if (raw is! Map) return const {};
    return raw.map((k, v) => MapEntry(
        k.toString(), v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{}));
  }

  static Map<String, List<String>> _mapOfLists(Object? raw) {
    if (raw is! Map) return const {};
    return raw.map((k, v) => MapEntry(
        k.toString(), v is List ? v.map((e) => e.toString()).toList() : const <String>[]));
  }

  static List<String> _stringList(Object? raw) {
    if (raw is! List) return const [];
    return raw.map((e) => e.toString()).toList();
  }

  factory MainDataUpdate.fromJson(Map<String, dynamic> json) {
    return MainDataUpdate(
      rid: (json['rid'] as num?)?.toInt() ?? 0,
      fullUpdate: json['full_update'] == true,
      torrents: _mapOfMaps(json['torrents']),
      torrentsRemoved: _stringList(json['torrents_removed']),
      categories: _mapOfMaps(json['categories']),
      categoriesRemoved: _stringList(json['categories_removed']),
      tags: _stringList(json['tags']),
      tagsRemoved: _stringList(json['tags_removed']),
      trackers: _mapOfLists(json['trackers']),
      trackersRemoved: _stringList(json['trackers_removed']),
      serverState: json['server_state'] is Map
          ? Map<String, dynamic>.from(json['server_state'] as Map)
          : null,
    );
  }
}

/// A saved category.
class Category {
  const Category({required this.name, this.savePath = ''});

  final String name;
  final String savePath;

  factory Category.fromJson(String name, Map<String, dynamic> json) =>
      Category(name: name, savePath: json['savePath'] as String? ?? '');
}
