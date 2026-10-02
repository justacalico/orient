/// RSS data from `/api/v2/rss/*`.
class RssItem {
  const RssItem({
    required this.id,
    this.title = '',
    this.torrentUrl = '',
    this.articleUrl = '',
    this.date = '',
    this.author = '',
    this.isRead = false,
    this.torrentSize = -1,
  });

  final String id;
  final String title;
  final String torrentUrl;
  final String articleUrl;
  final String date;
  final String author;
  final bool isRead;
  final int torrentSize;

  factory RssItem.fromJson(Map<String, dynamic> json) => RssItem(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        torrentUrl: json['torrentURL'] as String? ?? '',
        articleUrl: json['articleURL'] as String? ?? '',
        date: json['date'] as String? ?? '',
        author: json['author'] as String? ?? '',
        isRead: json['isRead'] as bool? ?? false,
        torrentSize: (json['torrentSize'] as num?)?.toInt() ?? -1,
      );
}

class RssFeed {
  const RssFeed({
    required this.name,
    this.url = '',
    this.isLoading = false,
    this.hasError = false,
    this.lastBuildDate = '',
    this.items = const [],
  });

  final String name;
  final String url;
  final bool isLoading;
  final bool hasError;
  final String lastBuildDate;
  final List<RssItem> items;

  int get unreadCount => items.where((i) => !i.isRead).length;

  factory RssFeed.fromJson(
      String name, Map<String, dynamic> json, List<RssItem> items) {
    return RssFeed(
      name: name,
      url: json['url'] as String? ?? '',
      isLoading: json['isLoading'] as bool? ?? false,
      hasError: json['hasError'] as bool? ?? false,
      lastBuildDate: json['lastBuildDate'] as String? ?? '',
      items: items,
    );
  }
}

/// The feeds endpoint returns a tree: feeds and folders of feeds.
class RssFeedNode {
  const RssFeedNode({
    this.feed,
    this.children = const {},
  });

  final RssFeed? feed;
  final Map<String, RssFeedNode> children;

  bool get isFolder => feed == null;

  /// Flattens the tree into (path, feed) pairs, depth-first.
  List<({String path, RssFeed feed})> flatten([String prefix = '']) {
    final out = <({String path, RssFeed feed})>[];
    if (feed != null) {
      out.add((path: prefix, feed: feed!));
    }
    for (final entry in children.entries) {
      final path = prefix.isEmpty ? entry.key : '$prefix\\${entry.key}';
      out.addAll(entry.value.flatten(path));
    }
    return out;
  }

  factory RssFeedNode.fromJson(Map<String, dynamic> json) {
    // A leaf has "url"; everything else is a folder of children or a feed
    // with article items.
    if (json.containsKey('url')) {
      final items = <RssItem>[];
      final rawItems = json['articles'];
      if (rawItems is List) {
        for (final raw in rawItems) {
          if (raw is Map) {
            items.add(RssItem.fromJson(Map<String, dynamic>.from(raw)));
          }
        }
      }
      return RssFeedNode(
        feed: RssFeed.fromJson('', json, items),
      );
    }
    final children = <String, RssFeedNode>{};
    for (final entry in json.entries) {
      if (entry.value is Map) {
        children[entry.key] =
            RssFeedNode.fromJson(Map<String, dynamic>.from(entry.value as Map));
      }
    }
    return RssFeedNode(children: children);
  }

  /// The API wraps each feed's metadata + items in one object; folders are
  /// plain nested maps keyed by path segment.
  factory RssFeedNode.fromFeedsJson(Map<String, dynamic> json) {
    final children = <String, RssFeedNode>{};
    for (final entry in json.entries) {
      if (entry.value is! Map) continue;
      final child = Map<String, dynamic>.from(entry.value as Map);
      if (child.containsKey('url')) {
        final items = <RssItem>[];
        final rawItems = child['articles'];
        if (rawItems is List) {
          for (final raw in rawItems) {
            if (raw is Map) {
              items.add(RssItem.fromJson(Map<String, dynamic>.from(raw)));
            }
          }
        }
        children[entry.key] = RssFeedNode(feed: RssFeed.fromJson(entry.key, child, items));
      } else {
        children[entry.key] = RssFeedNode.fromFeedsJson(child);
      }
    }
    return RssFeedNode(children: children);
  }
}
