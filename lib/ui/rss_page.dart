import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../models/rss.dart';
import '../theme.dart';
import '../util/format.dart';
import 'widgets/common.dart';

/// RSS feeds list + articles.
class RssPage extends StatefulWidget {
  const RssPage({super.key});

  @override
  State<RssPage> createState() => _RssPageState();
}

class _RssPageState extends State<RssPage> {
  String? _selectedFeed;
  bool _requested = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (!_requested) {
      _requested = true;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => state.refreshRss());
    }
    final feeds = state.rssRoot?.flatten() ?? const [];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
          child: Row(
            children: [
              const Expanded(
                child: Text('RSS',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              ),
              IconButton(
                icon: const Icon(Icons.add_rounded),
                tooltip: 'Add feed',
                onPressed: () => _addFeed(context),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Refresh all',
                onPressed: () => state.refreshRss(),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _FeedChip(
                  label: 'All feeds',
                  selected: _selectedFeed == null,
                  onTap: () => setState(() => _selectedFeed = null),
                ),
              ),
              for (final f in feeds)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _FeedChip(
                    label:
                        '${f.feed.name}${f.feed.unreadCount > 0 ? ' (${f.feed.unreadCount})' : ''}',
                    selected: _selectedFeed == f.path,
                    onTap: () => setState(() => _selectedFeed = f.path),
                    onLongPress: () => _feedMenu(context, f.path, f.feed),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 16),
        Expanded(child: _items(feeds)),
      ],
    );
  }

  Widget _items(List<({String path, RssFeed feed})> feeds) {
    final state = context.watch<AppState>();
    if (state.rssLoading && feeds.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (feeds.isEmpty) {
      return const EmptyState(
        icon: Icons.rss_feed_rounded,
        title: 'No feeds',
        message: 'Subscribe to an RSS feed on the server.',
      );
    }
    final items = <({String feedPath, RssItem item})>[];
    for (final f in feeds) {
      if (_selectedFeed != null && f.path != _selectedFeed) continue;
      for (final item in f.feed.items) {
        items.add((feedPath: f.path, item: item));
      }
    }
    if (items.isEmpty) {
      return const EmptyState(
          icon: Icons.inbox_rounded, title: 'No articles');
    }
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, i) => _ArticleTile(
        entry: items[i],
        onOpen: () => _openItem(context, items[i]),
      ),
    );
  }

  Future<void> _openItem(
      BuildContext context, ({String feedPath, RssItem item}) entry) async {
    final state = context.read<AppState>();
    if (!entry.item.isRead) {
      await state.rssMarkRead(entry.feedPath, entry.item.id);
    }
    final url = entry.item.articleUrl.isNotEmpty
        ? entry.item.articleUrl
        : entry.item.torrentUrl;
    if (url.isNotEmpty) {
      final uri = Uri.tryParse(url);
      if (uri != null) await launchUrl(uri);
    }
  }

  Future<void> _addFeed(BuildContext context) async {
    final urlController = TextEditingController();
    final pathController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add RSS feed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlController,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Feed URL'),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: pathController,
              decoration: const InputDecoration(
                  hintText: 'Name (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Subscribe'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final url = urlController.text.trim();
    if (url.isEmpty) return;
    await context
        .read<AppState>()
        .rssAdd(url, pathController.text.trim());
  }

  Future<void> _feedMenu(
      BuildContext context, String path, RssFeed feed) async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(feed.name.isEmpty ? path : feed.name),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop('refresh'),
            child: const Text('Refresh feed'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop('read'),
            child: const Text('Mark all as read'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop('remove'),
            child: Text('Unsubscribe',
                style:
                    TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
    if (action == null || !context.mounted) return;
    final state = context.read<AppState>();
    switch (action) {
      case 'refresh':
        await state.rssRefresh(path);
      case 'read':
        await state.rssMarkRead(path);
      case 'remove':
        final ok = await confirmDialog(context,
            title: 'Unsubscribe',
            message: 'Remove this feed?',
            confirmLabel: 'Remove',
            destructive: true);
        if (ok) {
          await state.rssRemove(path);
          if (_selectedFeed == path) {
            setState(() => _selectedFeed = null);
          }
        }
    }
  }
}

class _FeedChip extends StatelessWidget {
  const _FeedChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.onLongPress,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary.withValues(alpha: 0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? scheme.primary
                : OrientTheme.hairline(context),
            width: 0.8,
          ),
        ),
        child: Text(
          label,
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

class _ArticleTile extends StatelessWidget {
  const _ArticleTile({required this.entry, required this.onOpen});

  final ({String feedPath, RssItem item}) entry;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final item = entry.item;
    final muted = OrientTheme.muted(context);
    return ListTile(
      dense: false,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: item.isRead
          ? const SizedBox(width: 8)
          : const StatusDot(color: Color(0xFF2C6ECE)),
      title: Text(
        item.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 14,
          fontWeight: item.isRead ? FontWeight.w400 : FontWeight.w600,
        ),
      ),
      subtitle: Text(
        [
          item.date,
          if (item.author.isNotEmpty) item.author,
          if (item.torrentSize > 0) formatBytes(item.torrentSize),
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11.5, color: muted),
      ),
      onTap: onOpen,
    );
  }
}
