import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/torrent.dart';
import '../../theme.dart';

/// Status dot + label pairing used for connection state.
class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.color, this.size = 8});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// Centered empty/error placeholder used across pages.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final muted = OrientTheme.muted(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: muted.withValues(alpha: 0.5)),
            const SizedBox(height: 14),
            Text(title,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface)),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: muted)),
            ],
            if (action != null) ...[
              const SizedBox(height: 18),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Color + icon for a torrent lifecycle state.
({Color color, IconData icon}) torrentStateStyle(
    BuildContext context, TorrentState state) {
  final scheme = Theme.of(context).colorScheme;
  return switch (state) {
    TorrentState.error || TorrentState.missingFiles =>
      (color: scheme.error, icon: Icons.error_rounded),
    TorrentState.downloading ||
    TorrentState.forcedDl ||
    TorrentState.metaDl ||
    TorrentState.forcedMetaDl =>
      (color: scheme.primary, icon: Icons.arrow_downward_rounded),
    TorrentState.stalledDl || TorrentState.queuedDl =>
      (color: const Color(0xFF9A7B00), icon: Icons.hourglass_bottom_rounded),
    TorrentState.uploading || TorrentState.forcedUp =>
      (color: const Color(0xFF2E7D4F), icon: Icons.arrow_upward_rounded),
    TorrentState.stalledUp || TorrentState.queuedUp =>
      (color: const Color(0xFF4F7D5C), icon: Icons.cloud_done_rounded),
    TorrentState.pausedDl ||
    TorrentState.pausedUp ||
    TorrentState.stoppedDl ||
    TorrentState.stoppedUp =>
      (color: OrientTheme.muted(context), icon: Icons.pause_rounded),
    TorrentState.checkingDl ||
    TorrentState.checkingUp ||
    TorrentState.checkingResumeData =>
      (color: const Color(0xFF6B4FA8), icon: Icons.verified_rounded),
    TorrentState.moving => (
        color: const Color(0xFFB85C1A),
        icon: Icons.drive_file_move_rounded
      ),
    TorrentState.allocating =>
      (color: OrientTheme.muted(context), icon: Icons.storage_rounded),
    TorrentState.unknown =>
      (color: OrientTheme.muted(context), icon: Icons.help_outline_rounded),
  };
}

/// Tiny live-updating line chart for transfer speeds.
class SpeedGraph extends StatelessWidget {
  const SpeedGraph({
    super.key,
    required this.series,
    required this.color,
    this.height = 72,
  });

  final List<int> series;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(double.infinity, height),
      painter: _SpeedGraphPainter(
        series: series,
        color: color,
        gridColor: OrientTheme.hairline(context),
      ),
    );
  }
}

class _SpeedGraphPainter extends CustomPainter {
  _SpeedGraphPainter({
    required this.series,
    required this.color,
    required this.gridColor,
  });

  final List<int> series;
  final Color color;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    if (series.length < 2) return;

    final peak = math.max<int>(series.reduce(math.max), 1);
    final path = Path();
    final fillPath = Path();
    for (var i = 0; i < series.length; i++) {
      final x = size.width * i / (series.length - 1);
      final y = size.height - (series[i] / peak) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(
        fillPath,
        Paint()
          ..color = color.withValues(alpha: 0.12)
          ..style = PaintingStyle.fill);
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = 1.6
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(_SpeedGraphPainter old) => old.series != series;
}

/// A labelled stat used in detail and transfer pages.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final muted = OrientTheme.muted(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(label, style: TextStyle(fontSize: 13, color: muted)),
          ),
          Expanded(
            child: SelectableText(value,
                style: const TextStyle(fontSize: 13, height: 1.35)),
          ),
        ],
      ),
    );
  }
}

/// Text input modal. Returns the entered string or null.
Future<String?> promptForText(
  BuildContext context, {
  required String title,
  String? initial,
  String? hint,
  String confirmLabel = 'Save',
  bool obscure = false,
  TextInputType keyboardType = TextInputType.text,
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        obscureText: obscure,
        keyboardType: keyboardType,
        decoration: InputDecoration(hintText: hint),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}

/// Confirm dialog. Returns true on confirm.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error)
              : null,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
