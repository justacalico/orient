import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'services/server_store.dart';
import 'services/settings.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await Settings.load();
  final store = await ServerStore.load();
  final state = AppState(settings: settings, store: store);
  runApp(
    ChangeNotifierProvider<AppState>.value(
      value: state,
      child: const OrientApp(),
    ),
  );
}
