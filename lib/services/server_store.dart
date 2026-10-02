import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/server_profile.dart';

/// Persists saved server profiles in shared_preferences.
class ServerStore {
  ServerStore(this._prefs);

  final SharedPreferences _prefs;

  static const _key = 'servers';
  static const _keyLast = 'lastServerId';

  List<ServerProfile> get servers {
    final raw = _prefs.getStringList(_key) ?? const [];
    return raw
        .map((s) =>
            ServerProfile.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  String? get lastServerId => _prefs.getString(_keyLast);

  Future<void> saveAll(List<ServerProfile> servers) {
    return _prefs.setStringList(
        _key, servers.map((s) => jsonEncode(s.toJson())).toList());
  }

  Future<void> upsert(ServerProfile profile) async {
    final list = servers;
    final idx = list.indexWhere((s) => s.id == profile.id);
    if (idx >= 0) {
      list[idx] = profile;
    } else {
      list.add(profile);
    }
    await saveAll(list);
  }

  Future<void> remove(String id) async {
    final list = servers..removeWhere((s) => s.id == id);
    await saveAll(list);
    if (lastServerId == id) await _prefs.remove(_keyLast);
  }

  Future<void> setLastServer(String? id) async {
    if (id == null) {
      await _prefs.remove(_keyLast);
    } else {
      await _prefs.setString(_keyLast, id);
    }
  }

  static Future<ServerStore> load() async {
    return ServerStore(await SharedPreferences.getInstance());
  }
}
