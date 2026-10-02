import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';

/// Add-by-magnet/URL or .torrent file sheet.
Future<void> showAddTorrentSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const _AddTorrentSheet(),
  );
}

class _AddTorrentSheet extends StatefulWidget {
  const _AddTorrentSheet();

  @override
  State<_AddTorrentSheet> createState() => _AddTorrentSheetState();
}

class _AddTorrentSheetState extends State<_AddTorrentSheet> {
  final _urls = TextEditingController();
  final _savePath = TextEditingController();
  String? _category;
  bool _paused = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _urls.dispose();
    _savePath.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final urls = _urls.text.trim();
    if (urls.isEmpty) {
      setState(() => _error = 'Paste at least one magnet link or URL');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final state = context.read<AppState>();
    try {
      await state.addTorrentUrls(
        urls,
        savePath: _savePath.text.trim(),
        category: _category,
        paused: _paused,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _busy = false;
        _error = '$e';
      });
    }
  }

  Future<void> _pickFile() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['torrent'],
    );
    final file = files.firstOrNull;
    if (file == null || !mounted) return;
    setState(() => _busy = true);
    final state = context.read<AppState>();
    try {
      final bytes = await file.readAsBytes();
      await state.addTorrentFile(
        bytes,
        file.name,
        savePath: _savePath.text.trim(),
        category: _category,
        paused: _paused,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _busy = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final categories = state.categories.keys.toList()..sort();
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Add torrent',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          TextField(
            controller: _urls,
            maxLines: 4,
            minLines: 2,
            decoration: const InputDecoration(
              hintText: 'Magnet link or torrent URL, one per line',
            ),
            autocorrect: false,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _savePath,
                  decoration:
                      const InputDecoration(hintText: 'Save path (optional)'),
                ),
              ),
              const SizedBox(width: 8),
              _CategoryPicker(
                categories: categories,
                value: _category,
                onChanged: (c) => setState(() => _category = c),
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Add paused', style: TextStyle(fontSize: 14)),
            value: _paused,
            onChanged: (v) => setState(() => _paused = v),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_error!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 13)),
            ),
          Row(
            children: [
              TextButton.icon(
                onPressed: _busy ? null : _pickFile,
                icon: const Icon(Icons.upload_file_rounded, size: 18),
                label: const Text('.torrent file'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Add'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({
    required this.categories,
    required this.value,
    required this.onChanged,
  });

  final List<String> categories;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String?>(
      tooltip: 'Category',
      onSelected: onChanged,
      itemBuilder: (context) => [
        const PopupMenuItem(value: null, child: Text('No category')),
        for (final c in categories)
          PopupMenuItem(value: c, child: Text(c)),
      ],
      child: Chip(
        avatar: const Icon(Icons.folder_outlined, size: 16),
        label: Text(value ?? 'Category'),
      ),
    );
  }
}
