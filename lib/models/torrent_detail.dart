/// Static properties from `/api/v2/torrents/properties`.
class TorrentProperties {
  const TorrentProperties({
    this.savePath = '',
    this.creationDate = -1,
    this.pieceSize = 0,
    this.comment = '',
    this.totalWasted = 0,
    this.totalUploaded = 0,
    this.totalUploadedSession = 0,
    this.totalDownloaded = 0,
    this.totalDownloadedSession = 0,
    this.upLimit = 0,
    this.dlLimit = 0,
    this.timeElapsed = 0,
    this.seedingTime = 0,
    this.nbConnections = 0,
    this.nbConnectionsLimit = 0,
    this.shareRatio = 0,
    this.additionDate = -1,
    this.completionDate = -1,
    this.createdBy = '',
    this.dlSpeedAvg = 0,
    this.dlSpeed = 0,
    this.eta = 8640000,
    this.lastSeen = -1,
    this.peers = 0,
    this.peersTotal = 0,
    this.piecesHave = 0,
    this.piecesNum = 0,
    this.reannounce = 0,
    this.seeds = 0,
    this.seedsTotal = 0,
    this.totalSize = 0,
    this.upSpeedAvg = 0,
    this.upSpeed = 0,
  });

  final String savePath;
  final int creationDate;
  final int pieceSize;
  final String comment;
  final int totalWasted;
  final int totalUploaded;
  final int totalUploadedSession;
  final int totalDownloaded;
  final int totalDownloadedSession;
  final int upLimit;
  final int dlLimit;
  final int timeElapsed;
  final int seedingTime;
  final int nbConnections;
  final int nbConnectionsLimit;
  final double shareRatio;
  final int additionDate;
  final int completionDate;
  final String createdBy;
  final int dlSpeedAvg;
  final int dlSpeed;
  final int eta;
  final int lastSeen;
  final int peers;
  final int peersTotal;
  final int piecesHave;
  final int piecesNum;
  final int reannounce;
  final int seeds;
  final int seedsTotal;
  final int totalSize;
  final int upSpeedAvg;
  final int upSpeed;

  factory TorrentProperties.fromJson(Map<String, dynamic> json) {
    int i(String k, [int d = 0]) => (json[k] as num?)?.toInt() ?? d;
    return TorrentProperties(
      savePath: json['save_path'] as String? ?? '',
      creationDate: i('creation_date', -1),
      pieceSize: i('piece_size'),
      comment: json['comment'] as String? ?? '',
      totalWasted: i('total_wasted'),
      totalUploaded: i('total_uploaded'),
      totalUploadedSession: i('total_uploaded_session'),
      totalDownloaded: i('total_downloaded'),
      totalDownloadedSession: i('total_downloaded_session'),
      upLimit: i('up_limit'),
      dlLimit: i('dl_limit'),
      timeElapsed: i('time_elapsed'),
      seedingTime: i('seeding_time'),
      nbConnections: i('nb_connections'),
      nbConnectionsLimit: i('nb_connections_limit'),
      shareRatio: (json['share_ratio'] as num?)?.toDouble() ?? 0,
      additionDate: i('addition_date', -1),
      completionDate: i('completion_date', -1),
      createdBy: json['created_by'] as String? ?? '',
      dlSpeedAvg: i('dl_speed_avg'),
      dlSpeed: i('dl_speed'),
      eta: i('eta', 8640000),
      lastSeen: i('last_seen', -1),
      peers: i('peers'),
      peersTotal: i('peers_total'),
      piecesHave: i('pieces_have'),
      piecesNum: i('pieces_num'),
      reannounce: i('reannounce'),
      seeds: i('seeds'),
      seedsTotal: i('seeds_total'),
      totalSize: i('total_size'),
      upSpeedAvg: i('up_speed_avg'),
      upSpeed: i('up_speed'),
    );
  }
}

/// File priorities matching the WebUI values.
enum FilePriority {
  skip(0),
  normal(1),
  high(6),
  maximum(7);

  const FilePriority(this.value);
  final int value;

  static FilePriority fromValue(int v) => switch (v) {
        0 => FilePriority.skip,
        6 => FilePriority.high,
        7 => FilePriority.maximum,
        _ => FilePriority.normal,
      };

  String get label => switch (this) {
        FilePriority.skip => 'Skip',
        FilePriority.normal => 'Normal',
        FilePriority.high => 'High',
        FilePriority.maximum => 'Maximum',
      };
}

/// One file inside a torrent (`/api/v2/torrents/contents`).
class TorrentFile {
  const TorrentFile({
    required this.index,
    required this.name,
    required this.size,
    required this.progress,
    required this.priority,
    required this.isSeed,
    this.availability = -1,
  });

  final int index;
  final String name;
  final int size;
  final double progress;
  final FilePriority priority;
  final bool isSeed;
  final double availability;

  int get downloaded => (size * progress).round();

  String get fileName {
    final slash = name.lastIndexOf('/');
    return slash >= 0 ? name.substring(slash + 1) : name;
  }

  String get directory {
    final slash = name.lastIndexOf('/');
    return slash >= 0 ? name.substring(0, slash) : '';
  }

  factory TorrentFile.fromJson(Map<String, dynamic> json) => TorrentFile(
        index: (json['index'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? '',
        size: (json['size'] as num?)?.toInt() ?? 0,
        progress: (json['progress'] as num?)?.toDouble() ?? 0,
        priority: FilePriority.fromValue((json['priority'] as num?)?.toInt() ?? 1),
        isSeed: json['is_seed'] == true,
        availability: (json['availability'] as num?)?.toDouble() ?? -1,
      );
}

/// Tracker status codes used by the WebUI.
enum TrackerStatus {
  disabled(0),
  notContacted(1),
  working(2),
  updating(3),
  error(4);

  const TrackerStatus(this.value);
  final int value;

  static TrackerStatus fromValue(int v) => switch (v) {
        0 => TrackerStatus.disabled,
        2 => TrackerStatus.working,
        3 => TrackerStatus.updating,
        4 => TrackerStatus.error,
        _ => TrackerStatus.notContacted,
      };

  String get label => switch (this) {
        TrackerStatus.disabled => 'Disabled',
        TrackerStatus.notContacted => 'Not contacted',
        TrackerStatus.working => 'Working',
        TrackerStatus.updating => 'Updating',
        TrackerStatus.error => 'Error',
      };
}

class TorrentTracker {
  const TorrentTracker({
    required this.url,
    required this.status,
    this.tier = 0,
    this.numPeers = 0,
    this.numSeeds = 0,
    this.numLeeches = 0,
    this.numDownloaded = 0,
    this.msg = '',
  });

  final String url;
  final TrackerStatus status;
  final int tier;
  final int numPeers;
  final int numSeeds;
  final int numLeeches;
  final int numDownloaded;
  final String msg;

  /// DHT/PeX/LSD pseudo entries can't be edited or removed.
  bool get isSpecial =>
      url.startsWith('** [') || url == '** [DHT] **' || tier < 0;

  factory TorrentTracker.fromJson(Map<String, dynamic> json) => TorrentTracker(
        url: json['url'] as String? ?? '',
        status: TrackerStatus.fromValue((json['status'] as num?)?.toInt() ?? 0),
        tier: (json['tier'] as num?)?.toInt() ?? 0,
        numPeers: (json['num_peers'] as num?)?.toInt() ?? 0,
        numSeeds: (json['num_seeds'] as num?)?.toInt() ?? 0,
        numLeeches: (json['num_leeches'] as num?)?.toInt() ?? 0,
        numDownloaded: (json['num_downloaded'] as num?)?.toInt() ?? 0,
        msg: json['msg'] as String? ?? '',
      );
}

/// A connected peer (`sync/torrentdata -> peers`).
class Peer {
  const Peer({
    required this.address,
    this.client = '',
    this.progress = 0,
    this.dlSpeed = 0,
    this.upSpeed = 0,
    this.downloaded = 0,
    this.uploaded = 0,
    this.connection = '',
    this.flags = '',
    this.country = '',
    this.countryCode = '',
    this.relevance = 0,
  });

  final String address;
  final String client;
  final double progress;
  final int dlSpeed;
  final int upSpeed;
  final int downloaded;
  final int uploaded;
  final String connection;
  final String flags;
  final String country;
  final String countryCode;
  final double relevance;

  factory Peer.fromJson(Map<String, dynamic> json) {
    final ip = json['ip'] as String? ?? '';
    final port = json['port'];
    return Peer(
      address: port != null ? '$ip:$port' : ip,
      client: json['client'] as String? ?? '',
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      dlSpeed: (json['dl_speed'] as num?)?.toInt() ?? 0,
      upSpeed: (json['up_speed'] as num?)?.toInt() ?? 0,
      downloaded: (json['downloaded'] as num?)?.toInt() ?? 0,
      uploaded: (json['uploaded'] as num?)?.toInt() ?? 0,
      connection: json['connection'] as String? ?? '',
      flags: json['flags'] as String? ?? '',
      country: json['country'] as String? ?? '',
      countryCode: json['country_code'] as String? ?? '',
      relevance: (json['relevance'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Incremental response from `/api/v2/sync/torrentdata`.
class TorrentDataUpdate {
  const TorrentDataUpdate({
    required this.rid,
    this.fullUpdate = false,
    this.peers = const [],
    this.peersRemoved = const [],
  });

  final int rid;
  final bool fullUpdate;
  final List<Peer> peers;
  final List<String> peersRemoved;

  factory TorrentDataUpdate.fromJson(Map<String, dynamic> json) {
    final peers = <Peer>[];
    if (json['peers'] is Map) {
      for (final entry in (json['peers'] as Map).entries) {
        if (entry.value is Map) {
          peers.add(Peer.fromJson(Map<String, dynamic>.from(entry.value as Map)));
        }
      }
    }
    return TorrentDataUpdate(
      rid: (json['rid'] as num?)?.toInt() ?? 0,
      fullUpdate: json['full_update'] == true,
      peers: peers,
      peersRemoved: json['peers_removed'] is List
          ? (json['peers_removed'] as List).map((e) => e.toString()).toList()
          : const [],
    );
  }
}
