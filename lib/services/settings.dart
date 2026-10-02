import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide preferences persisted with shared_preferences.
class Settings {
  Settings({
    this.themeMode = ThemeMode.system,
    this.accentColor = OrientAccents.blue,
    this.pollInterval = const Duration(seconds: 2),
    this.confirmDeletes = true,
    this.showSpeedInTitle = false,
    this.defaultTorrentFilter = TorrentFilter.all,
  });

  ThemeMode themeMode;
  Color accentColor;
  Duration pollInterval;
  bool confirmDeletes;
  bool showSpeedInTitle;
  TorrentFilter defaultTorrentFilter;

  static const _keyTheme = 'themeMode';
  static const _keyAccent = 'accentColor';
  static const _keyPollMs = 'pollIntervalMs';
  static const _keyConfirmDeletes = 'confirmDeletes';
  static const _keySpeedTitle = 'showSpeedInTitle';
  static const _keyFilter = 'defaultTorrentFilter';

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTheme, themeMode.name);
    await prefs.setInt(_keyAccent, accentColor.toARGB32());
    await prefs.setInt(_keyPollMs, pollInterval.inMilliseconds);
    await prefs.setBool(_keyConfirmDeletes, confirmDeletes);
    await prefs.setBool(_keySpeedTitle, showSpeedInTitle);
    await prefs.setString(_keyFilter, defaultTorrentFilter.name);
  }

  static Future<Settings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final settings = Settings();
    settings.themeMode = ThemeMode.values.asNameMap()[prefs.getString(_keyTheme)] ??
        ThemeMode.system;
    final accent = prefs.getInt(_keyAccent);
    if (accent != null) settings.accentColor = Color(accent);
    final poll = prefs.getInt(_keyPollMs);
    if (poll != null && poll >= 500) {
      settings.pollInterval = Duration(milliseconds: poll);
    }
    settings.confirmDeletes = prefs.getBool(_keyConfirmDeletes) ?? true;
    settings.showSpeedInTitle = prefs.getBool(_keySpeedTitle) ?? false;
    settings.defaultTorrentFilter = TorrentFilter.values
            .asNameMap()[prefs.getString(_keyFilter)] ??
        TorrentFilter.all;
    return settings;
  }
}

enum TorrentFilter {
  all,
  downloading,
  seeding,
  completed,
  paused,
  active,
  inactive,
  errored;

  String get label => switch (this) {
        TorrentFilter.all => 'All',
        TorrentFilter.downloading => 'Downloading',
        TorrentFilter.seeding => 'Seeding',
        TorrentFilter.completed => 'Completed',
        TorrentFilter.paused => 'Paused',
        TorrentFilter.active => 'Active',
        TorrentFilter.inactive => 'Inactive',
        TorrentFilter.errored => 'Errored',
      };
}

/// Accent choices surfaced in settings.
class OrientAccents {
  static const blue = Color(0xFF2C6ECE);
  static const teal = Color(0xFF0E8A8A);
  static const green = Color(0xFF2E7D4F);
  static const orange = Color(0xFFB85C1A);
  static const violet = Color(0xFF6B4FA8);
  static const rose = Color(0xFFB53A5E);
  static const slate = Color(0xFF54607A);

  static const all = [blue, teal, green, orange, violet, rose, slate];
}
