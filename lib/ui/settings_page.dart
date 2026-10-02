import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../services/settings.dart';
import '../theme.dart';
import 'connect_page.dart';
import 'widgets/common.dart';

/// App settings + server and library management.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Settings',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        const SizedBox(height: 14),
        _Group(title: 'Appearance', children: [
          _ThemeModeTile(),
          _AccentTile(),
        ]),
        _Group(title: 'Polling', children: [
          _PollIntervalTile(),
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            title:
                const Text('Confirm before deleting', style: TextStyle(fontSize: 14)),
            value: state.settings.confirmDeletes,
            onChanged: (v) {
              state.settings.confirmDeletes = v;
              state.settings.save();
              state.applySettings();
            },
          ),
        ]),
        _Group(title: 'Servers', children: [
          for (final s in state.servers)
            ListTile(
              title: Text(s.name,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500)),
              subtitle: Text(s.displayHost,
                  style: TextStyle(
                      fontSize: 12, color: OrientTheme.muted(context))),
              trailing: const Icon(Icons.chevron_right_rounded, size: 18),
              onTap: () => showServerEditor(context, existing: s),
            ),
          ListTile(
            leading: const Icon(Icons.add_rounded, size: 18),
            title: const Text('Add server', style: TextStyle(fontSize: 14)),
            onTap: () => showServerEditor(context),
          ),
        ]),
        if (state.isConnected) ...[
          _Group(title: 'Categories', children: [_CategoryManager()]),
          _Group(title: 'Tags', children: [_TagManager()]),
        ],
        _Group(title: 'Connection', children: [
          if (state.isConnected)
            ListTile(
              leading: Icon(Icons.logout_rounded,
                  size: 18, color: Theme.of(context).colorScheme.error),
              title: Text('Disconnect',
                  style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.error)),
              subtitle: Text(
                state.activeProfile?.name ?? '',
                style:
                    TextStyle(fontSize: 12, color: OrientTheme.muted(context)),
              ),
              onTap: () => state.disconnect(),
            ),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded, size: 18),
            title: const Text('About Orient', style: TextStyle(fontSize: 14)),
            subtitle: Text(
              'qBittorrent WebUI client',
              style: TextStyle(fontSize: 12, color: OrientTheme.muted(context)),
            ),
          ),
        ]),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
                color: OrientTheme.muted(context),
              ),
            ),
          ),
          Card(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const Divider(height: 0.5, indent: 16),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeModeTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Expanded(
              child: Text('Theme', style: TextStyle(fontSize: 14))),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto_rounded, size: 16)),
              ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_rounded, size: 16)),
              ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_rounded, size: 16)),
            ],
            selected: {state.settings.themeMode},
            onSelectionChanged: (s) {
              state.settings.themeMode = s.first;
              state.settings.save();
              state.applySettings();
            },
          ),
        ],
      ),
    );
  }
}

class _AccentTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Expanded(
              child: Text('Accent', style: TextStyle(fontSize: 14))),
          for (final color in OrientAccents.all)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  state.settings.accentColor = color;
                  state.settings.save();
                  state.applySettings();
                },
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: state.settings.accentColor.toARGB32() ==
                            color.toARGB32()
                        ? Border.all(
                            color: Theme.of(context).colorScheme.onSurface,
                            width: 2,
                          )
                        : null,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PollIntervalTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    const options = [1, 2, 3, 5, 10];
    final current = state.settings.pollInterval.inSeconds;
    return ListTile(
      title: const Text('Refresh interval', style: TextStyle(fontSize: 14)),
      trailing: DropdownButton<int>(
        value: options.contains(current) ? current : 2,
        underline: const SizedBox.shrink(),
        items: [
          for (final s in options)
            DropdownMenuItem(value: s, child: Text('${s}s')),
        ],
        onChanged: (v) {
          if (v == null) return;
          state.settings.pollInterval = Duration(seconds: v);
          state.settings.save();
          state.applySettings();
        },
      ),
    );
  }
}

class _CategoryManager extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final categories = state.categories.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return Column(
      children: [
        for (final c in categories)
          ListTile(
            leading: const Icon(Icons.folder_outlined, size: 18),
            title: Text(c.name, style: const TextStyle(fontSize: 14)),
            subtitle: c.savePath.isEmpty
                ? null
                : Text(c.savePath,
                    style: TextStyle(
                        fontSize: 11.5, color: OrientTheme.muted(context))),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  tooltip: 'Edit save path',
                  onPressed: () => _edit(context, c.name, c.savePath),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline_rounded,
                      size: 16),
                  tooltip: 'Delete category',
                  onPressed: () => _remove(context, c.name),
                ),
              ],
            ),
          ),
        ListTile(
          leading: const Icon(Icons.add_rounded, size: 18),
          title:
              const Text('New category', style: TextStyle(fontSize: 14)),
          onTap: () => _edit(context, null, ''),
        ),
      ],
    );
  }

  Future<void> _edit(BuildContext context, String? name, String savePath) async {
    final nameController = TextEditingController(text: name);
    final pathController = TextEditingController(text: savePath);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(name == null ? 'New category' : 'Edit category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (name == null)
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Name'),
              ),
            const SizedBox(height: 10),
            TextField(
              controller: pathController,
              decoration:
                  const InputDecoration(hintText: 'Save path (optional)'),
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
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final state = context.read<AppState>();
    if (name == null) {
      final n = nameController.text.trim();
      if (n.isNotEmpty) {
        await state.createCategory(n, pathController.text.trim());
      }
    } else {
      await state.editCategory(name, pathController.text.trim());
    }
  }

  Future<void> _remove(BuildContext context, String name) async {
    final ok = await confirmDialog(context,
        title: 'Delete category',
        message: 'Delete "$name"? Torrents keep their files.',
        confirmLabel: 'Delete',
        destructive: true);
    if (ok && context.mounted) {
      await context.read<AppState>().removeCategories([name]);
    }
  }
}

class _TagManager extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tags = state.tags.toList()..sort();
    return Column(
      children: [
        for (final tag in tags)
          ListTile(
            leading: const Icon(Icons.label_outline_rounded, size: 18),
            title: Text(tag, style: const TextStyle(fontSize: 14)),
            trailing: IconButton(
              icon: const Icon(Icons.remove_circle_outline_rounded, size: 16),
              tooltip: 'Delete tag',
              onPressed: () => _remove(context, tag),
            ),
          ),
        ListTile(
          leading: const Icon(Icons.add_rounded, size: 18),
          title: const Text('New tag', style: TextStyle(fontSize: 14)),
          onTap: () async {
            final v = await promptForText(context, title: 'New tag', hint: 'Tag name');
            if (v != null && v.trim().isNotEmpty && context.mounted) {
              await context.read<AppState>().createTags([v.trim()]);
            }
          },
        ),
      ],
    );
  }

  Future<void> _remove(BuildContext context, String tag) async {
    final ok = await confirmDialog(context,
        title: 'Delete tag',
        message: 'Remove "$tag" from all torrents?',
        confirmLabel: 'Delete',
        destructive: true);
    if (ok && context.mounted) {
      await context.read<AppState>().deleteTags([tag]);
    }
  }
}
