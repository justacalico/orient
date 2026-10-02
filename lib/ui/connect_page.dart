import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/server_profile.dart';
import '../theme.dart';
import 'widgets/common.dart';

/// Server picker + login screen shown while disconnected.
class ConnectPage extends StatelessWidget {
  const ConnectPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final servers = state.servers;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(24),
              children: [
                const _Brand(),
                const SizedBox(height: 28),
                if (state.phase == ConnectionPhase.failed &&
                    state.lastError != null)
                  _ErrorBanner(message: state.lastError!),
                if (servers.isEmpty)
                  const _NoServers()
                else
                  for (final s in servers) _ServerTile(server: s),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => showServerEditor(context),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add server'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.explore_rounded, color: Colors.white, size: 30),
        ),
        const SizedBox(height: 14),
        Text('Orient',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: scheme.onSurface,
            )),
        const SizedBox(height: 4),
        Text('qBittorrent remote control',
            style: TextStyle(fontSize: 13, color: OrientTheme.muted(context))),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: scheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: TextStyle(fontSize: 13, color: scheme.onSurface)),
          ),
        ],
      ),
    );
  }
}

class _NoServers extends StatelessWidget {
  const _NoServers();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Text(
        'Point Orient at a qBittorrent WebUI to get started.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, color: OrientTheme.muted(context)),
      ),
    );
  }
}

class _ServerTile extends StatelessWidget {
  const _ServerTile({required this.server});

  final ServerProfile server;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final connecting = state.phase == ConnectionPhase.connecting &&
        state.activeProfile?.id == server.id;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        title: Text(server.name,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: Text(server.displayHost,
            style: TextStyle(fontSize: 12, color: OrientTheme.muted(context))),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (connecting)
              const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
            else
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: 'Edit',
                onPressed: () => showServerEditor(context, existing: server),
              ),
          ],
        ),
        onTap: connecting ? null : () => state.connect(server),
      ),
    );
  }
}

/// Add/edit sheet for a server profile.
Future<void> showServerEditor(BuildContext context,
    {ServerProfile? existing}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _ServerEditor(existing: existing),
  );
}

class _ServerEditor extends StatefulWidget {
  const _ServerEditor({this.existing});

  final ServerProfile? existing;

  @override
  State<_ServerEditor> createState() => _ServerEditorState();
}

class _ServerEditorState extends State<_ServerEditor> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _url = TextEditingController(text: widget.existing?.baseUrl ?? '');
  late final _user =
      TextEditingController(text: widget.existing?.username ?? '');
  late final _pass =
      TextEditingController(text: widget.existing?.password ?? '');
  bool _remember = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _remember = widget.existing?.rememberSession ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final url = ServerProfile.normalizeBaseUrl(_url.text);
    if (url.isEmpty) {
      setState(() => _error = 'Enter the WebUI address');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final state = context.read<AppState>();
    final profile = ServerProfile(
      id: widget.existing?.id ??
          'srv_${DateTime.now().millisecondsSinceEpoch}',
      name: _name.text.trim().isEmpty ? _url.text.trim() : _name.text.trim(),
      baseUrl: url,
      username: _user.text.trim(),
      password: _pass.text,
      rememberSession: _remember,
    );
    await state.store.upsert(profile);
    if (!mounted) return;
    Navigator.of(context).pop();
    await state.connect(profile);
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    final ok = await confirmDialog(
      context,
      title: 'Remove server',
      message: 'Remove "${existing.name}" from the list?',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await context.read<AppState>().store.remove(existing.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
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
          Text(widget.existing == null ? 'Add server' : 'Edit server',
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            decoration: const InputDecoration(
                labelText: 'Name', hintText: 'Home server'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _url,
            decoration: const InputDecoration(
                labelText: 'WebUI address', hintText: '192.168.1.10:8080'),
            keyboardType: TextInputType.url,
            autocorrect: false,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _user,
            decoration: const InputDecoration(labelText: 'Username'),
            autocorrect: false,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _pass,
            decoration: const InputDecoration(labelText: 'Password'),
            obscureText: true,
            autocorrect: false,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Stay signed in', style: TextStyle(fontSize: 14)),
            value: _remember,
            onChanged: (v) => setState(() => _remember = v),
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
              if (widget.existing != null)
                TextButton(
                  onPressed: _busy ? null : _delete,
                  child: Text('Remove',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ),
              const Spacer(),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(widget.existing == null ? 'Connect' : 'Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
