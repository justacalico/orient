import 'package:intl/intl.dart';

final _dateFmt = DateFormat.yMMMd();
final _dateTimeFmt = DateFormat.yMMMd().add_Hm();

const _units = ['B', 'KiB', 'MiB', 'GiB', 'TiB', 'PiB'];

String formatBytes(num bytes) {
  if (bytes < 0) return '?';
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < _units.length - 1) {
    value /= 1024;
    unit++;
  }
  final text = unit == 0 ? value.round().toString() : value.toStringAsFixed(value < 10 ? 2 : 1);
  return '$text ${_units[unit]}';
}

String formatSpeed(num bytesPerSecond) {
  if (bytesPerSecond <= 0) return '0 B/s';
  return '${formatBytes(bytesPerSecond)}/s';
}

/// qBittorrent uses 8640000 (100 days) as "infinite" ETA.
String formatEta(int etaSeconds) {
  if (etaSeconds >= 8640000 || etaSeconds < 0) return '∞';
  final d = Duration(seconds: etaSeconds);
  if (d.inDays >= 100) return '∞';
  if (d.inDays > 0) return '${d.inDays}d ${d.inHours % 24}h';
  if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
  if (d.inMinutes > 0) return '${d.inMinutes}m ${d.inSeconds % 60}s';
  return '${d.inSeconds}s';
}

String formatDuration(int seconds) {
  if (seconds < 0) return '—';
  final d = Duration(seconds: seconds);
  if (d.inDays > 0) return '${d.inDays}d ${d.inHours % 24}h ${d.inMinutes % 60}m';
  if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
  if (d.inMinutes > 0) return '${d.inMinutes}m ${d.inSeconds % 60}s';
  return '${d.inSeconds}s';
}

String formatRatio(num ratio) {
  if (ratio < 0) return '—';
  return ratio.toStringAsFixed(2);
}

/// Formats a unix timestamp (seconds). Negative or zero means "not set".
String formatTimestamp(int unixSeconds, {bool withTime = false}) {
  if (unixSeconds <= 0) return '—';
  final dt = DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000);
  return withTime ? _dateTimeFmt.format(dt) : _dateFmt.format(dt);
}

/// Speed limits: 0 or negative means unlimited in the WebUI.
String formatLimit(int bytesPerSecond) {
  if (bytesPerSecond <= 0) return '∞';
  return formatSpeed(bytesPerSecond);
}

String formatAvailability(double availability) {
  if (availability < 0) return '—';
  return availability.toStringAsFixed(3);
}
