# Orient

A remote client for [qBittorrent](https://www.qbittorrent.org/) WebUI, built with Flutter. Runs on Android, iOS, Linux, Windows, macOS and the web.

[![Pipeline](https://gitlab.com/HttpAnimations/orient/badges/main/pipeline.svg)](https://gitlab.com/HttpAnimations/orient/-/pipelines)
[![Latest release](https://gitlab.com/HttpAnimations/orient/-/badges/release.svg)](https://gitlab.com/HttpAnimations/orient/-/releases)
[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](LICENSE)

## Features

- Multiple saved WebUI servers with session handling
- Live torrent list with incremental sync - states, progress, speeds, ETA, ratio, seeds/peers
- Filter by status, category, tag and tracker; full-text search; sortable columns
- Multi-select batch actions: pause/resume/delete, recheck, reannounce, queue priority, location, rename, categories, tags, per-torrent speed and share limits, sequential download, first/last piece priority, force start, auto-TMM
- Torrent detail: general info, file list with per-file priority, trackers (add/remove/edit), live peer list
- Add torrents by magnet link, URL or .torrent file, with save path, category and paused options
- Transfer dashboard: download/upload graphs, session and all-time stats, DHT status, global speed limits, alternative speed limit toggle
- RSS feed management: subscribe, refresh, mark read, open articles
- Category and tag management
- Adaptive layout - bottom navigation on phones, navigation rail with a master-detail view on desktop and tablets

## Requirements

qBittorrent with the WebUI enabled (`Tools -> Options -> Web UI -> User Interface`). The WebUI API v2 is required, which means qBittorrent 4.1 or newer. Features like stop/start verbs are used automatically on qBittorrent 5.0+.

## Install

### Android

Download the APK from [the latest release](https://gitlab.com/HttpAnimations/orient/-/releases).

### iOS (AltStore)

Add the Orient source to AltStore, then install from inside the app:

```
https://httpanimations.gitlab.io/orient/altstore/apps.json
```

AltStore -> Sources -> `+` -> paste the URL -> Add.

### Linux

Release builds ship as `.tar.gz`, `.zip`, `.deb`, `.rpm` and AppImage for x86_64 and arm64.

### Windows / macOS / Web

Grab the platform archive from releases. The web build is also hosted at
`https://httpanimations.gitlab.io/orient/`.

## Development

```sh
flutter pub get
flutter run
flutter test --coverage
```

## License

[GNU AGPL v3](LICENSE)
