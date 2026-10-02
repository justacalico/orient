import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';
import 'connect_page.dart';
import 'rss_page.dart';
import 'settings_page.dart';
import 'torrents_page.dart';
import 'transfer_page.dart';

/// Compact (phone) and wide (desktop/tablet) shells over one AppState.
class OrientApp extends StatelessWidget {
  const OrientApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return MaterialApp(
      title: 'Orient',
      debugShowCheckedModeBanner: false,
      theme: OrientTheme.light(state.settings.accentColor),
      darkTheme: OrientTheme.dark(state.settings.accentColor),
      themeMode: state.settings.themeMode,
      home: switch (state.phase) {
        ConnectionPhase.disconnected ||
        ConnectionPhase.failed =>
          const ConnectPage(),
        _ => const AdaptiveShell(),
      },
    );
  }
}

class AdaptiveShell extends StatefulWidget {
  const AdaptiveShell({super.key});

  @override
  State<AdaptiveShell> createState() => _AdaptiveShellState();
}

class _AdaptiveShellState extends State<AdaptiveShell> {
  int _tab = 0;

  static const _destinations = [
    (icon: Icons.download_rounded, label: 'Torrents'),
    (icon: Icons.speed_rounded, label: 'Speed'),
    (icon: Icons.rss_feed_rounded, label: 'RSS'),
    (icon: Icons.tune_rounded, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final body = switch (_tab) {
      1 => const TransferPage(),
      2 => const RssPage(),
      3 => const SettingsPage(),
      _ => const TorrentsPage(),
    };

    if (!wide) {
      return Scaffold(
        body: SafeArea(child: body),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: [
            for (final d in _destinations)
              NavigationDestination(icon: Icon(d.icon), label: d.label),
          ],
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            labelType: NavigationRailLabelType.all,
            destinations: [
              for (final d in _destinations)
                NavigationRailDestination(icon: Icon(d.icon), label: Text(d.label)),
            ],
          ),
          const VerticalDivider(width: 0.5),
          Expanded(child: body),
        ],
      ),
    );
  }
}
