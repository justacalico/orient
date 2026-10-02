import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/torrent.dart';
import '../models/torrent_detail.dart';
import '../theme.dart';
import '../util/format.dart';
import 'widgets/common.dart';

/// Full-screen detail used in the compact layout.
class TorrentDetailPage extends StatelessWidget {
  const TorrentDetailPage({super.key, required this.hash});

  final String hash;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Torrent'),
      ),
      body: TorrentDetailPanel(hash: hash, onClose: () {
        context.read<AppState>().closeDetail();
        Navigator.of(context).pop();
      }),
    );
  }
}

/// Tabbed detail view, also embedded as the wide-layout side pane.
class TorrentDetailPanel extends StatefulWidget {
  const TorrentDetailPanel({super.key, required this.hash, this.onClose});

  final String hash;
  final VoidCallback? onClose;

  @override
  State<TorrentDetailPanel> createState() => _TorrentDetailPanelState();
}

class _TorrentDetailPanelState extends State<TorrentDetailPanel> {
  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    if (!state.detailProperties.containsKey(widget.hash)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) state.loadDetail(widget.hash);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final torrent = state.torrents[widget.hash];
    if (torrent == null) {
      return const EmptyState(
        icon: Icons.delete_outline_rounded,
        title: 'Torrent removed',
      );
    }
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          _DetailHeader(torrent: torrent, onClose: widget.onClose),
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'General'),
              Tab(text: 'Files'),
              Tab(text: 'Trackers'),
              Tab(text: 'Peers'),
            ],
          ),
          const Divider(height: 0.5),
          Expanded(
            child: TabBarView(
              children: [
                _GeneralTab(torrent: torrent),
                _FilesTab(hash: widget.hash),
                _TrackersTab(hash: widget.hash),
                _PeersTab(hash: widget.hash),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.torrent, this.onClose});

  final Torrent torrent;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final style = torrentStateStyle(context, torrent.state);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  torrent.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600, height: 1.3),
                ),
                const SizedBox(height: 4),
                Text(
                  '${torrent.state.label} · ${formatBytes(torrent.size)} · ratio ${formatRatio(torrent.ratio)}',
                  style: TextStyle(fontSize: 12, color: style.color),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 17),
            tooltip: 'Copy hash',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: torrent.hash));
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Hash copied')));
            },
          ),
          IconButton(
            icon: Icon(
              torrent.isPaused
                  ? Icons.play_arrow_rounded
                  : Icons.pause_rounded,
              size: 20,
            ),
            tooltip: torrent.isPaused ? 'Resume' : 'Pause',
            onPressed: () {
              state.selectOnly(torrent.hash);
              if (torrent.isPaused) {
                state.resumeSelected();
              } else {
                state.pauseSelected();
              }
              state.clearSelection();
            },
          ),
          if (onClose != null)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              tooltip: 'Close',
              onPressed: onClose,
            ),
        ],
      ),
    );
  }
}

class _GeneralTab extends StatelessWidget {
  const _GeneralTab({required this.torrent});

  final Torrent torrent;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final props = state.detailProperties[torrent.hash];
    if (props == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _Section(title: 'Transfer', children: [
          StatTile(label: 'Downloaded', value: formatBytes(torrent.downloaded)),
          StatTile(label: 'Uploaded', value: formatBytes(torrent.uploaded)),
          StatTile(label: 'Ratio', value: formatRatio(torrent.ratio)),
          StatTile(
              label: 'Download speed',
              value:
                  '${formatSpeed(torrent.dlspeed)} (avg ${formatSpeed(props.dlSpeedAvg)})'),
          StatTile(
              label: 'Upload speed',
              value:
                  '${formatSpeed(torrent.upspeed)} (avg ${formatSpeed(props.upSpeedAvg)})'),
          StatTile(label: 'Wasted', value: formatBytes(props.totalWasted)),
        ]),
        _Section(title: 'Availability', children: [
          StatTile(
              label: 'Seeds',
              value: '${torrent.numSeeds} connected (${props.seedsTotal} in swarm)'),
          StatTile(
              label: 'Peers',
              value:
                  '${torrent.numLeechs} connected (${props.peersTotal} in swarm)'),
          StatTile(
              label: 'Availability',
              value: formatAvailability(torrent.availability)),
          StatTile(
              label: 'Pieces',
              value: '${props.piecesHave} / ${props.piecesNum} × ${formatBytes(props.pieceSize)}'),
        ]),
        _Section(title: 'Time', children: [
          StatTile(
              label: 'Added',
              value: formatTimestamp(torrent.addedOn, withTime: true)),
          StatTile(
              label: 'Completed',
              value: formatTimestamp(torrent.completionOn, withTime: true)),
          StatTile(
              label: 'Active for', value: formatDuration(torrent.timeActive)),
          StatTile(
              label: 'Seeding for',
              value: formatDuration(torrent.seedingTime)),
          StatTile(label: 'ETA', value: formatEta(torrent.eta)),
        ]),
        _Section(title: 'Storage', children: [
          StatTile(label: 'Save path', value: torrent.savePath),
          StatTile(label: 'Content path', value: torrent.contentPath),
          if (props.comment.isNotEmpty)
            StatTile(label: 'Comment', value: props.comment),
          if (props.createdBy.isNotEmpty)
            StatTile(label: 'Created by', value: props.createdBy),
        ]),
        _Section(title: 'Limits', children: [
          StatTile(
              label: 'Download limit', value: formatLimit(torrent.dlLimit)),
          StatTile(label: 'Upload limit', value: formatLimit(torrent.upLimit)),
          StatTile(
              label: 'Ratio limit',
              value:
                  torrent.ratioLimit < 0 ? '∞' : formatRatio(torrent.ratioLimit)),
        ]),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 4),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: OrientTheme.muted(context),
              letterSpacing: 0.3,
            ),
          ),
        ),
        ...children,
      ],
    );
  }
}

class _FilesTab extends StatelessWidget {
  const _FilesTab({required this.hash});

  final String hash;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final files = state.detailFiles[hash];
    if (files == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (files.isEmpty) {
      return const EmptyState(
          icon: Icons.folder_open_rounded, title: 'No file data');
    }
    return ListView.builder(
      itemCount: files.length,
      itemBuilder: (context, i) => _FileRow(hash: hash, file: files[i]),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({required this.hash, required this.file});

  final String hash;
  final TorrentFile file;

  @override
  Widget build(BuildContext context) {
    final muted = OrientTheme.muted(context);
    return InkWell(
      onTap: () => _pickPriority(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              file.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: file.progress.clamp(0.0, 1.0),
                minHeight: 3,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${formatBytes(file.downloaded)} / ${formatBytes(file.size)}',
                    style: TextStyle(fontSize: 11, color: muted),
                  ),
                ),
                Text(
                  '${file.priority.label} · ${(file.progress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 11, color: muted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPriority(BuildContext context) async {
    final picked = await showDialog<FilePriority>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('File priority'),
        children: [
          for (final p in FilePriority.values)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(p),
              child: Row(
                children: [
                  Expanded(child: Text(p.label)),
                  if (file.priority == p)
                    const Icon(Icons.check_rounded, size: 16),
                ],
              ),
            ),
        ],
      ),
    );
    if (picked != null && context.mounted) {
      await context
          .read<AppState>()
          .setFilePriority(hash, [file.index], picked.value);
    }
  }
}

class _TrackersTab extends StatelessWidget {
  const _TrackersTab({required this.hash});

  final String hash;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final trackers = state.detailTrackers[hash];
    if (trackers == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 8, top: 4),
            child: TextButton.icon(
              onPressed: () => _addTracker(context),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add tracker'),
            ),
          ),
        ),
        Expanded(
          child: trackers.isEmpty
              ? const EmptyState(
                  icon: Icons.public_off_rounded, title: 'No trackers')
              : ListView.builder(
                  itemCount: trackers.length,
                  itemBuilder: (context, i) =>
                      _TrackerRow(hash: hash, tracker: trackers[i]),
                ),
        ),
      ],
    );
  }

  Future<void> _addTracker(BuildContext context) async {
    final controller = TextEditingController();
    final urls = await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add trackers'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(
              hintText: 'One tracker URL per line'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(
              controller.text
                  .split('\n')
                  .map((u) => u.trim())
                  .where((u) => u.isNotEmpty)
                  .toList(),
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (urls != null && urls.isNotEmpty && context.mounted) {
      await context.read<AppState>().addTrackers(hash, urls);
    }
  }
}

class _TrackerRow extends StatelessWidget {
  const _TrackerRow({required this.hash, required this.tracker});

  final String hash;
  final TorrentTracker tracker;

  @override
  Widget build(BuildContext context) {
    final muted = OrientTheme.muted(context);
    final scheme = Theme.of(context).colorScheme;
    final statusColor = switch (tracker.status) {
      TrackerStatus.working => const Color(0xFF2E7D4F),
      TrackerStatus.error => scheme.error,
      TrackerStatus.updating => const Color(0xFF9A7B00),
      _ => muted,
    };
    return ListTile(
      title: Text(tracker.url,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13)),
      subtitle: Text(
        '${tracker.status.label} · ${tracker.numSeeds} seeds · ${tracker.numLeeches} peers'
        '${tracker.msg.isNotEmpty ? ' · ${tracker.msg}' : ''}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11.5, color: statusColor),
      ),
      trailing: tracker.isSpecial
          ? null
          : IconButton(
              icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
              tooltip: 'Remove tracker',
              onPressed: () async {
                final ok = await confirmDialog(context,
                    title: 'Remove tracker',
                    message: tracker.url,
                    confirmLabel: 'Remove',
                    destructive: true);
                if (ok && context.mounted) {
                  await context
                      .read<AppState>()
                      .removeTrackers(hash, [tracker.url]);
                }
              },
            ),
    );
  }
}

class _PeersTab extends StatelessWidget {
  const _PeersTab({required this.hash});

  final String hash;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final peers = state.detailPeers[hash];
    if (peers == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (peers.isEmpty) {
      return const EmptyState(
          icon: Icons.people_outline_rounded, title: 'No peers connected');
    }
    final sorted = [...peers]..sort((a, b) => b.dlSpeed.compareTo(a.dlSpeed));
    return ListView.builder(
      itemCount: sorted.length,
      itemBuilder: (context, i) => _PeerRow(peer: sorted[i]),
    );
  }
}

class _PeerRow extends StatelessWidget {
  const _PeerRow({required this.peer});

  final Peer peer;

  @override
  Widget build(BuildContext context) {
    final muted = OrientTheme.muted(context);
    return ListTile(
      title: Text(peer.address,
          style: const TextStyle(fontSize: 13, fontFamily: 'monospace')),
      subtitle: Text(
        [
          if (peer.client.isNotEmpty) peer.client,
          if (peer.country.isNotEmpty) peer.country,
          '${(peer.progress * 100).toStringAsFixed(0)}%',
          if (peer.connection.isNotEmpty) peer.connection,
        ].join(' · '),
        style: TextStyle(fontSize: 11.5, color: muted),
      ),
      trailing: Text(
        '↓ ${formatSpeed(peer.dlSpeed)}  ↑ ${formatSpeed(peer.upSpeed)}',
        style: TextStyle(fontSize: 11, color: muted),
      ),
    );
  }
}
