import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/torrent.dart';
import '../services/settings.dart';
import '../theme.dart';
import '../util/format.dart';
import 'add_torrent_sheet.dart';
import 'torrent_detail.dart';
import 'widgets/common.dart';

/// Torrent list with filters, sorting, multi-select actions and the detail pane.
class TorrentsPage extends StatelessWidget {
  const TorrentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final state = context.watch<AppState>();

    final list = Column(
      children: [
        const _Toolbar(),
        const _FilterBar(),
        const Divider(height: 0.5),
        Expanded(child: _TorrentList()),
        _StatusBar(state: state),
      ],
    );

    if (!wide) {
      return Scaffold(body: list);
    }

    final detail = state.detailHash != null
        ? TorrentDetailPanel(key: ValueKey(state.detailHash), hash: state.detailHash!)
        : const _NoDetail();

    return Scaffold(
      body: Row(
        children: [
          Expanded(flex: 3, child: list),
          const VerticalDivider(width: 0.5),
          Expanded(flex: 2, child: detail),
        ],
      ),
    );
  }
}

class _NoDetail extends StatelessWidget {
  const _NoDetail();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.info_outline_rounded,
      title: 'No torrent selected',
      message: 'Select a torrent to inspect it.',
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final selected = state.selected;
    final hasSelection = selected.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
      child: Row(
        children: [
          if (hasSelection) ...[
            Text('${selected.length} selected',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              tooltip: 'Clear selection',
              onPressed: state.clearSelection,
            ),
          ] else ...[
            Expanded(
              child: Text(
                state.activeProfile?.name ?? 'Torrents',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
          ],
          const Spacer(),
          if (hasSelection)
            _SelectionActions(hashes: selected.toList())
          else ...[
            IconButton(
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Add torrent',
              onPressed: () => showAddTorrentSheet(context),
            ),
            IconButton(
              icon: const Icon(Icons.sort_rounded),
              tooltip: 'Sort',
              onPressed: () => _showSortMenu(context),
            ),
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              tooltip: 'Disconnect',
              onPressed: () async {
                final ok = await confirmDialog(
                  context,
                  title: 'Disconnect',
                  message:
                      'Disconnect from ${state.activeProfile?.name ?? 'this server'}?',
                  confirmLabel: 'Disconnect',
                );
                if (ok && context.mounted) {
                  await context.read<AppState>().disconnect();
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  void _showSortMenu(BuildContext context) {
    final state = context.read<AppState>();
    final box = context.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;
    final pos = RelativeRect.fromRect(
      Rect.fromPoints(
        box.localToGlobal(Offset(box.size.width - 48, 48), ancestor: overlay),
        box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );
    showMenu<TorrentSort>(
      context: context,
      position: pos,
      items: [
        for (final s in TorrentSort.values)
          PopupMenuItem(
            value: s,
            child: Row(
              children: [
                Expanded(child: Text(s.label)),
                if (state.sort == s)
                  Icon(
                    state.sortDescending
                        ? Icons.arrow_downward_rounded
                        : Icons.arrow_upward_rounded,
                    size: 16,
                  ),
              ],
            ),
          ),
      ],
    ).then((picked) {
      if (picked != null) state.setSort(picked);
    });
  }
}

class _SelectionActions extends StatelessWidget {
  const _SelectionActions({required this.hashes});

  final List<String> hashes;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final torrents = hashes
        .map((h) => state.torrents[h])
        .whereType<Torrent>()
        .toList();
    final anyPaused = torrents.any((t) => t.isPaused);
    final anyRunning = torrents.any((t) => !t.isPaused);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (anyPaused)
          IconButton(
            icon: const Icon(Icons.play_arrow_rounded),
            tooltip: 'Resume',
            onPressed: () => state.resumeSelected(),
          ),
        if (anyRunning)
          IconButton(
            icon: const Icon(Icons.pause_rounded),
            tooltip: 'Pause',
            onPressed: () => state.pauseSelected(),
          ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Recheck',
          onPressed: () => state.recheckSelected(),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded),
          tooltip: 'Delete',
          onPressed: () => _confirmDelete(context, hashes),
        ),
        _TorrentOverflowMenu(hashes: hashes),
      ],
    );
  }
}

Future<void> _confirmDelete(BuildContext context, List<String> hashes) async {
  final state = context.read<AppState>();
  var deleteFiles = false;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setLocal) => AlertDialog(
        title: Text(
            hashes.length == 1 ? 'Delete torrent' : 'Delete ${hashes.length} torrents'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Remove the selected torrents from the list?'),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title:
                  const Text('Also delete files on disk', style: TextStyle(fontSize: 14)),
              value: deleteFiles,
              onChanged: (v) => setLocal(() => deleteFiles = v ?? false),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    ),
  );
  if (confirmed == true) {
    await state.deleteSelected(deleteFiles: deleteFiles);
    state.clearSelection();
  }
}

/// Overflow menu with the rest of the torrent actions.
class _TorrentOverflowMenu extends StatelessWidget {
  const _TorrentOverflowMenu({required this.hashes});

  final List<String> hashes;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded),
      tooltip: 'More actions',
      onSelected: (action) => _run(context, action),
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'reannounce', child: Text('Reannounce')),
        const PopupMenuItem(value: 'category', child: Text('Set category')),
        const PopupMenuItem(value: 'tags', child: Text('Edit tags')),
        const PopupMenuItem(value: 'location', child: Text('Set location')),
        if (hashes.length == 1)
          const PopupMenuItem(value: 'rename', child: Text('Rename')),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'topPrio', child: Text('Move to top of queue')),
        const PopupMenuItem(value: 'upPrio', child: Text('Move up in queue')),
        const PopupMenuItem(value: 'downPrio', child: Text('Move down in queue')),
        const PopupMenuItem(value: 'bottomPrio', child: Text('Move to bottom')),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'seq', child: Text('Sequential download')),
        const PopupMenuItem(
            value: 'firstlast', child: Text('First/last pieces first')),
        const PopupMenuItem(value: 'dlLimit', child: Text('Download limit')),
        const PopupMenuItem(value: 'ulLimit', child: Text('Upload limit')),
      ],
    );
  }

  Future<void> _run(BuildContext context, String action) async {
    final state = context.read<AppState>();
    switch (action) {
      case 'reannounce':
        await state.reannounceSelected();
      case 'category':
        await _pickCategory(context);
      case 'tags':
        await _editTags(context);
      case 'location':
        final first = state.torrents[hashes.first];
        final v = await promptForText(context,
            title: 'Set location',
            initial: first?.savePath ?? '',
            hint: 'Download directory');
        if (v != null && v.isNotEmpty) {
          await state.setLocationFor(hashes, v);
        }
      case 'rename':
        final first = state.torrents[hashes.first];
        if (first == null) return;
        final v = await promptForText(context,
            title: 'Rename torrent', initial: first.name);
        if (v != null && v.isNotEmpty) {
          await state.renameTorrent(first.hash, v);
        }
      case 'topPrio':
        await state.topPrioFor(hashes);
      case 'upPrio':
        await state.increasePrioFor(hashes);
      case 'downPrio':
        await state.decreasePrioFor(hashes);
      case 'bottomPrio':
        await state.bottomPrioFor(hashes);
      case 'seq':
        await state.toggleSequentialFor(hashes);
      case 'firstlast':
        await state.toggleFirstLastFor(hashes);
      case 'dlLimit':
        await _setLimit(context, download: true);
      case 'ulLimit':
        await _setLimit(context, download: false);
    }
  }

  Future<void> _setLimit(BuildContext context, {required bool download}) async {
    final state = context.read<AppState>();
    final v = await promptForText(
      context,
      title: download ? 'Download limit' : 'Upload limit',
      hint: 'KiB/s, empty = unlimited',
      keyboardType: TextInputType.number,
    );
    if (v == null) return;
    final kib = int.tryParse(v.trim()) ?? 0;
    final bytes = kib <= 0 ? -1 : kib * 1024;
    if (download) {
      await state.setDownloadLimitFor(hashes, bytes);
    } else {
      await state.setUploadLimitFor(hashes, bytes);
    }
  }

  Future<void> _pickCategory(BuildContext context) async {
    final state = context.read<AppState>();
    final names = state.categories.keys.toList()..sort();
    String? newCategory;
    final chosen = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => SimpleDialog(
          title: const Text('Set category'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(''),
              child: const Text('Uncategorized'),
            ),
            for (final name in names)
              SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop(name),
                child: Text(name),
              ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      autofocus: false,
                      decoration: const InputDecoration(
                          hintText: 'New category', isDense: true),
                      onChanged: (v) => newCategory = v,
                      onSubmitted: (v) async {
                        if (v.trim().isNotEmpty) {
                          await state.createCategory(v.trim(), '');
                        }
                        if (context.mounted) Navigator.of(context).pop(v.trim());
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_rounded),
                    tooltip: 'Create and apply',
                    onPressed: () async {
                      final v = newCategory?.trim() ?? '';
                      if (v.isNotEmpty) {
                        await state.createCategory(v, '');
                        if (context.mounted) Navigator.of(context).pop(v);
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (chosen != null) {
      await state.setCategoryFor(hashes, chosen);
    }
  }

  Future<void> _editTags(BuildContext context) async {
    final state = context.read<AppState>();
    final allTags = state.tags.toList()..sort();
    final selectedTags = <String>{};
    if (hashes.length == 1) {
      selectedTags.addAll(state.torrents[hashes.first]?.tags ?? const []);
    }
    String? newTag;
    final applied = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Tags'),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final tag in allTags)
                        CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(tag, style: const TextStyle(fontSize: 14)),
                          value: selectedTags.contains(tag),
                          onChanged: (v) => setLocal(() => v == true
                              ? selectedTags.add(tag)
                              : selectedTags.remove(tag)),
                        ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                            hintText: 'New tag', isDense: true),
                        onChanged: (v) => newTag = v,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_rounded),
                      tooltip: 'Create tag',
                      onPressed: () async {
                        final v = newTag?.trim() ?? '';
                        if (v.isNotEmpty && !allTags.contains(v)) {
                          await state.createTags([v]);
                          setLocal(() {
                            allTags.add(v);
                            allTags.sort();
                            selectedTags.add(v);
                          });
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
    if (applied == true) {
      await state.addTagsFor(hashes, selectedTags.toList());
      final toRemove =
          allTags.where((t) => !selectedTags.contains(t)).toList();
      if (toRemove.isNotEmpty) {
        await state.removeTagsFor(hashes, toRemove);
      }
    }
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    onChanged: state.setSearch,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search torrents',
                      isDense: true,
                      prefixIcon:
                          const Icon(Icons.search_rounded, size: 18),
                      prefixIconConstraints:
                          const BoxConstraints(minWidth: 36),
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _CategoryFilter(),
              _TagFilter(),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final f in TorrentFilter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _FilterChip(
                      label: f.label,
                      count: _countFor(state, f),
                      selected: state.filter == f,
                      onTap: () => state.setFilter(f),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _countFor(AppState state, TorrentFilter f) {
    if (f == TorrentFilter.all) return state.torrents.length;
    return state.torrents.values.where((t) {
      return switch (f) {
        TorrentFilter.downloading => t.state.isDownloading,
        TorrentFilter.seeding => t.state.isSeeding,
        TorrentFilter.completed => t.progress >= 1.0,
        TorrentFilter.paused => t.isPaused,
        TorrentFilter.active => t.dlspeed > 0 || t.upspeed > 0,
        TorrentFilter.inactive => t.dlspeed <= 0 && t.upspeed <= 0,
        TorrentFilter.errored => t.state.isErrored,
        TorrentFilter.all => true,
      };
    }).length;
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary.withValues(alpha: 0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? scheme.primary : OrientTheme.hairline(context),
            width: 0.8,
          ),
        ),
        child: Text(
          '$label $count',
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected
                ? scheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _CategoryFilter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final names = state.categories.keys.toList()..sort();
    return PopupMenuButton<String?>(
      tooltip: 'Category',
      icon: Icon(
        Icons.folder_outlined,
        size: 20,
        color: state.filterCategory != null
            ? Theme.of(context).colorScheme.primary
            : OrientTheme.muted(context),
      ),
      onSelected: state.setCategory,
      itemBuilder: (context) => [
        const PopupMenuItem(value: null, child: Text('All categories')),
        for (final name in names)
          PopupMenuItem(
            value: name,
            child: Row(
              children: [
                Expanded(child: Text(name)),
                if (state.filterCategory == name)
                  const Icon(Icons.check_rounded, size: 16),
              ],
            ),
          ),
      ],
    );
  }
}

class _TagFilter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tags = state.tags.toList()..sort();
    return PopupMenuButton<String?>(
      tooltip: 'Tag',
      icon: Icon(
        Icons.label_outline_rounded,
        size: 20,
        color: state.filterTag != null
            ? Theme.of(context).colorScheme.primary
            : OrientTheme.muted(context),
      ),
      onSelected: state.setTag,
      itemBuilder: (context) => [
        const PopupMenuItem(value: null, child: Text('All tags')),
        for (final tag in tags)
          PopupMenuItem(
            value: tag,
            child: Row(
              children: [
                Expanded(child: Text(tag)),
                if (state.filterTag == tag)
                  const Icon(Icons.check_rounded, size: 16),
              ],
            ),
          ),
      ],
    );
  }
}

class _TorrentList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final torrents = state.visibleTorrents;
    if (torrents.isEmpty) {
      if (state.torrents.isEmpty) {
        return const EmptyState(
          icon: Icons.download_done_rounded,
          title: 'No torrents',
          message: 'Add a torrent or magnet link to get started.',
        );
      }
      return const EmptyState(
        icon: Icons.filter_alt_off_rounded,
        title: 'Nothing matches',
        message: 'No torrents match the current filters.',
      );
    }
    return ListView.builder(
      itemCount: torrents.length,
      itemExtent: 76,
      itemBuilder: (context, i) => _TorrentTile(torrent: torrents[i]),
    );
  }
}

class _TorrentTile extends StatelessWidget {
  const _TorrentTile({required this.torrent});

  final Torrent torrent;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final selected = state.selected.contains(torrent.hash);
    final style = torrentStateStyle(context, torrent.state);
    final muted = OrientTheme.muted(context);
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () {
        final wide = MediaQuery.sizeOf(context).width >= 1000;
        if (state.selected.isNotEmpty) {
          state.select(torrent.hash);
        } else if (wide) {
          state.openDetail(torrent.hash);
        } else {
          state.openDetail(torrent.hash);
          Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => TorrentDetailPage(hash: torrent.hash),
          ));
        }
      },
      onLongPress: () => state.select(torrent.hash),
      child: Container(
        color: selected ? scheme.primary.withValues(alpha: 0.08) : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(style.icon, color: style.color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          torrent.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ),
                      if (torrent.category.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        _CategoryBadge(name: torrent.category),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: torrent.progressClamped,
                      minHeight: 4,
                      color: torrent.isPaused ? muted : style.color,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _metaLine(torrent),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 64,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${(torrent.progressClamped * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    torrent.state.label,
                    style: TextStyle(fontSize: 10.5, color: muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _metaLine(Torrent t) {
    final parts = <String>[
      '${formatBytes(t.downloaded)} / ${formatBytes(t.size)}',
    ];
    if (t.dlspeed > 0) parts.add('↓ ${formatSpeed(t.dlspeed)}');
    if (t.upspeed > 0) parts.add('↑ ${formatSpeed(t.upspeed)}');
    if (t.eta < 8640000 && t.dlspeed > 0) parts.add('ETA ${formatEta(t.eta)}');
    parts.add('ratio ${formatRatio(t.ratio)}');
    if (t.numSeeds > 0 || t.numLeechs > 0) {
      parts.add('S${t.numSeeds} L${t.numLeechs}');
    }
    return parts.join(' · ');
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        name,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: scheme.primary,
        ),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final s = state.serverState;
    final muted = OrientTheme.muted(context);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border(
            top: BorderSide(color: OrientTheme.hairline(context), width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          StatusDot(
            color: s.connected
                ? const Color(0xFF2E7D4F)
                : s.firewalled
                    ? const Color(0xFF9A7B00)
                    : scheme.error,
          ),
          const SizedBox(width: 6),
          Text(s.connectionLabel,
              style: TextStyle(fontSize: 11.5, color: muted)),
          const SizedBox(width: 14),
          Icon(Icons.arrow_downward_rounded, size: 13, color: muted),
          const SizedBox(width: 3),
          Text(formatSpeed(s.dlInfoSpeed),
              style: TextStyle(fontSize: 11.5, color: muted)),
          const SizedBox(width: 10),
          Icon(Icons.arrow_upward_rounded, size: 13, color: muted),
          const SizedBox(width: 3),
          Text(formatSpeed(s.upInfoSpeed),
              style: TextStyle(fontSize: 11.5, color: muted)),
          const Spacer(),
          if (s.useAltSpeedLimits)
            Icon(Icons.slow_motion_video_rounded,
                size: 14, color: scheme.primary),
          const SizedBox(width: 8),
          Text(
            '${state.torrents.length} torrents',
            style: TextStyle(fontSize: 11.5, color: muted),
          ),
        ],
      ),
    );
  }
}
