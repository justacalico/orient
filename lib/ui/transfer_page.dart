import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';
import '../util/format.dart';
import 'widgets/common.dart';

/// Global transfer stats, speed graphs and limits.
class TransferPage extends StatelessWidget {
  const TransferPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.serverState;
    final scheme = Theme.of(context).colorScheme;
    final muted = OrientTheme.muted(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Transfer',
            style:
                const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SpeedHeader(
                  icon: Icons.arrow_downward_rounded,
                  color: scheme.primary,
                  label: 'Download',
                  speed: s.dlInfoSpeed,
                ),
                const SizedBox(height: 8),
                SpeedGraph(series: state.dlHistory, color: scheme.primary),
                const SizedBox(height: 18),
                _SpeedHeader(
                  icon: Icons.arrow_upward_rounded,
                  color: const Color(0xFF2E7D4F),
                  label: 'Upload',
                  speed: s.upInfoSpeed,
                ),
                const SizedBox(height: 8),
                SpeedGraph(
                    series: state.upHistory,
                    color: const Color(0xFF2E7D4F)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                _LimitTile(
                  label: 'Download limit',
                  value: s.dlRateLimit,
                  onEdit: () => _editLimit(context, download: true),
                ),
                const Divider(height: 0.5),
                _LimitTile(
                  label: 'Upload limit',
                  value: s.upRateLimit,
                  onEdit: () => _editLimit(context, download: false),
                ),
                const Divider(height: 0.5),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Alternative speed limits',
                      style: TextStyle(fontSize: 14)),
                  subtitle: Text(
                    s.useAltSpeedLimits ? 'Engaged' : 'Off',
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                  value: s.useAltSpeedLimits,
                  onChanged: (_) => state.toggleAltSpeed(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                StatTile(
                    label: 'Session download',
                    value: formatBytes(s.dlInfoData)),
                StatTile(
                    label: 'Session upload', value: formatBytes(s.upInfoData)),
                StatTile(
                    label: 'Session wasted',
                    value: formatBytes(s.totalWastedSession)),
                StatTile(
                    label: 'All-time download',
                    value: formatBytes(s.alltimeDl)),
                StatTile(
                    label: 'All-time upload',
                    value: formatBytes(s.alltimeUl)),
                StatTile(
                    label: 'Global ratio', value: s.globalRatio.isEmpty ? '—' : s.globalRatio),
                StatTile(
                    label: 'Free disk space',
                    value: formatBytes(s.freeSpaceOnDisk)),
                StatTile(
                    label: 'DHT nodes', value: '${s.dhtNodes}'),
                StatTile(
                    label: 'Peer connections',
                    value: '${s.totalPeerConnections}'),
                StatTile(
                    label: 'Queued I/O jobs',
                    value: '${s.queuedIoJobs}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _ConnectionCard(state: state),
      ],
    );
  }

  Future<void> _editLimit(BuildContext context,
      {required bool download}) async {
    final state = context.read<AppState>();
    final s = state.serverState;
    final current = download ? s.dlRateLimit : s.upRateLimit;
    final v = await promptForText(
      context,
      title: download ? 'Global download limit' : 'Global upload limit',
      initial: current > 0 ? '${(current / 1024).round()}' : '',
      hint: 'KiB/s, empty = unlimited',
      keyboardType: TextInputType.number,
    );
    if (v == null) return;
    final kib = int.tryParse(v.trim()) ?? 0;
    final bytes = kib <= 0 ? 0 : kib * 1024;
    if (download) {
      await state.setGlobalDlLimit(bytes);
    } else {
      await state.setGlobalUlLimit(bytes);
    }
  }
}

class _SpeedHeader extends StatelessWidget {
  const _SpeedHeader({
    required this.icon,
    required this.color,
    required this.label,
    required this.speed,
  });

  final IconData icon;
  final Color color;
  final String label;
  final int speed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: OrientTheme.muted(context))),
        const Spacer(),
        Text(formatSpeed(speed),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _LimitTile extends StatelessWidget {
  const _LimitTile({
    required this.label,
    required this.value,
    required this.onEdit,
  });

  final String label;
  final int value;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(fontSize: 14)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(formatLimit(value),
              style: TextStyle(
                  fontSize: 13, color: OrientTheme.muted(context))),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, size: 18),
        ],
      ),
      onTap: onEdit,
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final s = state.serverState;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            StatusDot(
              size: 10,
              color: s.connected
                  ? const Color(0xFF2E7D4F)
                  : s.firewalled
                      ? const Color(0xFF9A7B00)
                      : scheme.error,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.connectionLabel,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  Text(
                    [
                      if (state.serverVersion.isNotEmpty)
                        'qBittorrent ${state.serverVersion}',
                      if (state.webApiVersion.isNotEmpty)
                        'Web API ${state.webApiVersion}',
                    ].join(' · '),
                    style: TextStyle(
                        fontSize: 12, color: OrientTheme.muted(context)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
