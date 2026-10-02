/// Lifecycle states reported by the qBittorrent WebUI.
enum TorrentState {
  error,
  missingFiles,
  uploading,
  pausedUp,
  stoppedUp,
  queuedUp,
  stalledUp,
  checkingUp,
  forcedUp,
  allocating,
  downloading,
  metaDl,
  forcedMetaDl,
  pausedDl,
  stoppedDl,
  queuedDl,
  stalledDl,
  checkingDl,
  forcedDl,
  checkingResumeData,
  moving,
  unknown;

  static TorrentState parse(String raw) {
    return switch (raw) {
      'error' => TorrentState.error,
      'missingFiles' => TorrentState.missingFiles,
      'uploading' => TorrentState.uploading,
      'pausedUP' => TorrentState.pausedUp,
      'stoppedUP' => TorrentState.stoppedUp,
      'queuedUP' => TorrentState.queuedUp,
      'stalledUP' => TorrentState.stalledUp,
      'checkingUP' => TorrentState.checkingUp,
      'forcedUP' => TorrentState.forcedUp,
      'allocating' => TorrentState.allocating,
      'downloading' => TorrentState.downloading,
      'metaDL' => TorrentState.metaDl,
      'forcedMetaDL' => TorrentState.forcedMetaDl,
      'pausedDL' => TorrentState.pausedDl,
      'stoppedDL' => TorrentState.stoppedDl,
      'queuedDL' => TorrentState.queuedDl,
      'stalledDL' => TorrentState.stalledDl,
      'checkingDL' => TorrentState.checkingDl,
      'forcedDL' => TorrentState.forcedDl,
      'checkingResumeData' => TorrentState.checkingResumeData,
      'moving' => TorrentState.moving,
      _ => TorrentState.unknown,
    };
  }

  bool get isDownloading => switch (this) {
        TorrentState.downloading ||
        TorrentState.metaDl ||
        TorrentState.forcedMetaDl ||
        TorrentState.stalledDl ||
        TorrentState.queuedDl ||
        TorrentState.forcedDl ||
        TorrentState.allocating ||
        TorrentState.checkingDl ||
        TorrentState.checkingResumeData =>
          true,
        _ => false,
      };

  bool get isSeeding => switch (this) {
        TorrentState.uploading ||
        TorrentState.stalledUp ||
        TorrentState.queuedUp ||
        TorrentState.forcedUp ||
        TorrentState.checkingUp =>
          true,
        _ => false,
      };

  bool get isPaused =>
      this == TorrentState.pausedDl ||
      this == TorrentState.pausedUp ||
      this == TorrentState.stoppedDl ||
      this == TorrentState.stoppedUp;

  bool get isActive =>
      isDownloading || isSeeding || this == TorrentState.moving;

  bool get isErrored =>
      this == TorrentState.error || this == TorrentState.missingFiles;

  String get label => switch (this) {
        TorrentState.error => 'Error',
        TorrentState.missingFiles => 'Missing files',
        TorrentState.uploading => 'Seeding',
        TorrentState.pausedUp => 'Completed',
        TorrentState.stoppedUp => 'Stopped',
        TorrentState.queuedUp => 'Queued to seed',
        TorrentState.stalledUp => 'Stalled (seeding)',
        TorrentState.checkingUp => 'Checking',
        TorrentState.forcedUp => 'Forced seeding',
        TorrentState.allocating => 'Allocating',
        TorrentState.downloading => 'Downloading',
        TorrentState.metaDl => 'Fetching metadata',
        TorrentState.forcedMetaDl => 'Fetching metadata',
        TorrentState.pausedDl => 'Paused',
        TorrentState.stoppedDl => 'Stopped',
        TorrentState.queuedDl => 'Queued',
        TorrentState.stalledDl => 'Stalled',
        TorrentState.checkingDl => 'Checking',
        TorrentState.forcedDl => 'Forced download',
        TorrentState.checkingResumeData => 'Checking resume data',
        TorrentState.moving => 'Moving',
        TorrentState.unknown => 'Unknown',
      };
}

/// A torrent as reported by `/api/v2/sync/maindata` or `/api/v2/torrents/info`.
/// Fields are mutable because the sync endpoint sends partial updates that
/// get merged into the existing object.
class Torrent {
  Torrent({
    required this.hash,
    this.name = '',
    this.size = 0,
    this.totalSize = 0,
    this.progress = 0,
    this.dlspeed = 0,
    this.upspeed = 0,
    this.priority = 0,
    this.numSeeds = 0,
    this.numComplete = 0,
    this.numLeechs = 0,
    this.numIncomplete = 0,
    this.ratio = 0,
    this.ratioLimit = -2,
    this.eta = 8640000,
    this.state = TorrentState.unknown,
    this.category = '',
    this.tags = const [],
    this.savePath = '',
    this.contentPath = '',
    this.addedOn = 0,
    this.completionOn = -1,
    this.uploaded = 0,
    this.uploadedSession = 0,
    this.downloaded = 0,
    this.downloadedSession = 0,
    this.amountLeft = 0,
    this.timeActive = 0,
    this.seedingTime = 0,
    this.seedingTimeLimit = -2,
    this.dlLimit = 0,
    this.upLimit = 0,
    this.availability = -1,
    this.lastActivity = 0,
    this.magnetUri = '',
    this.tracker = '',
    this.trackersCount = 0,
    this.maxRatio = -1,
    this.maxSeedingTime = -1,
    this.autoTmm = false,
    this.forceStart = false,
    this.seqDl = false,
    this.firstLastPiecePrio = false,
    this.superSeeding = false,
    this.infohashV1 = '',
    this.infohashV2 = '',
  });

  final String hash;
  String name;
  int size;
  int totalSize;
  double progress;
  int dlspeed;
  int upspeed;
  int priority;
  int numSeeds;
  int numComplete;
  int numLeechs;
  int numIncomplete;
  double ratio;
  double ratioLimit;
  int eta;
  TorrentState state;
  String category;
  List<String> tags;
  String savePath;
  String contentPath;
  int addedOn;
  int completionOn;
  int uploaded;
  int uploadedSession;
  int downloaded;
  int downloadedSession;
  int amountLeft;
  int timeActive;
  int seedingTime;
  int seedingTimeLimit;
  int dlLimit;
  int upLimit;
  double availability;
  int lastActivity;
  String magnetUri;
  String tracker;
  int trackersCount;
  double maxRatio;
  int maxSeedingTime;
  bool autoTmm;
  bool forceStart;
  bool seqDl;
  bool firstLastPiecePrio;
  bool superSeeding;
  String infohashV1;
  String infohashV2;

  bool get isPaused => state.isPaused;
  double get progressClamped => progress.clamp(0.0, 1.0);

  static List<String> _splitTags(Object? raw) {
    if (raw is! String || raw.isEmpty) return const [];
    return raw.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
  }

  /// Applies one entry of a `torrents` map (full or partial update).
  void applyJson(Map<String, dynamic> json) {
    if (json['name'] != null) name = json['name'] as String;
    if (json['size'] != null) size = (json['size'] as num).toInt();
    if (json['total_size'] != null) totalSize = (json['total_size'] as num).toInt();
    if (json['progress'] != null) progress = (json['progress'] as num).toDouble();
    if (json['dlspeed'] != null) dlspeed = (json['dlspeed'] as num).toInt();
    if (json['upspeed'] != null) upspeed = (json['upspeed'] as num).toInt();
    if (json['priority'] != null) priority = (json['priority'] as num).toInt();
    if (json['num_seeds'] != null) numSeeds = (json['num_seeds'] as num).toInt();
    if (json['num_complete'] != null) numComplete = (json['num_complete'] as num).toInt();
    if (json['num_leechs'] != null) numLeechs = (json['num_leechs'] as num).toInt();
    if (json['num_incomplete'] != null) numIncomplete = (json['num_incomplete'] as num).toInt();
    if (json['ratio'] != null) ratio = (json['ratio'] as num).toDouble();
    if (json['ratio_limit'] != null) ratioLimit = (json['ratio_limit'] as num).toDouble();
    if (json['eta'] != null) eta = (json['eta'] as num).toInt();
    if (json['state'] != null) state = TorrentState.parse(json['state'] as String);
    if (json['category'] != null) category = json['category'] as String;
    if (json['tags'] != null) tags = _splitTags(json['tags']);
    if (json['save_path'] != null) savePath = json['save_path'] as String;
    if (json['content_path'] != null) contentPath = json['content_path'] as String;
    if (json['added_on'] != null) addedOn = (json['added_on'] as num).toInt();
    if (json['completion_on'] != null) completionOn = (json['completion_on'] as num).toInt();
    if (json['uploaded'] != null) uploaded = (json['uploaded'] as num).toInt();
    if (json['uploaded_session'] != null) uploadedSession = (json['uploaded_session'] as num).toInt();
    if (json['downloaded'] != null) downloaded = (json['downloaded'] as num).toInt();
    if (json['downloaded_session'] != null) downloadedSession = (json['downloaded_session'] as num).toInt();
    if (json['amount_left'] != null) amountLeft = (json['amount_left'] as num).toInt();
    if (json['time_active'] != null) timeActive = (json['time_active'] as num).toInt();
    if (json['seeding_time'] != null) seedingTime = (json['seeding_time'] as num).toInt();
    if (json['seeding_time_limit'] != null) seedingTimeLimit = (json['seeding_time_limit'] as num).toInt();
    if (json['dl_limit'] != null) dlLimit = (json['dl_limit'] as num).toInt();
    if (json['up_limit'] != null) upLimit = (json['up_limit'] as num).toInt();
    if (json['availability'] != null) availability = (json['availability'] as num).toDouble();
    if (json['last_activity'] != null) lastActivity = (json['last_activity'] as num).toInt();
    if (json['magnet_uri'] != null) magnetUri = json['magnet_uri'] as String;
    if (json['tracker'] != null) tracker = json['tracker'] as String;
    if (json['trackers_count'] != null) trackersCount = (json['trackers_count'] as num).toInt();
    if (json['max_ratio'] != null) maxRatio = (json['max_ratio'] as num).toDouble();
    if (json['max_seeding_time'] != null) maxSeedingTime = (json['max_seeding_time'] as num).toInt();
    if (json['auto_tmm'] != null) autoTmm = json['auto_tmm'] as bool;
    if (json['force_start'] != null) forceStart = json['force_start'] as bool;
    if (json['seq_dl'] != null) seqDl = json['seq_dl'] as bool;
    if (json['f_l_piece_prio'] != null) firstLastPiecePrio = json['f_l_piece_prio'] as bool;
    if (json['super_seeding'] != null) superSeeding = json['super_seeding'] as bool;
    if (json['infohash_v1'] != null) infohashV1 = json['infohash_v1'] as String;
    if (json['infohash_v2'] != null) infohashV2 = json['infohash_v2'] as String;
  }

  factory Torrent.fromJson(String hash, Map<String, dynamic> json) {
    final torrent = Torrent(hash: hash);
    torrent.applyJson(json);
    return torrent;
  }
}
