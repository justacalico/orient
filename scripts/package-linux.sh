#!/usr/bin/env bash
# Package a built Flutter Linux bundle into tar.gz, zip, .deb, .rpm and
# AppImage. Layout matches between formats: /opt/orient + /usr/bin/orient symlink.
#
# Usage: scripts/package-linux.sh <bundle-dir> <version> <arch> <outdir> [release]
#   arch: x64 or arm64 (the flutter build directory name)
set -euo pipefail

BUNDLE_DIR="${1:?usage: package-linux.sh <bundle-dir> <version> <arch> <outdir> [release]}"
VERSION="${2:?}"
FLUTTER_ARCH="${3:?}"
OUTDIR="${4:?}"
RELEASE="${5:-1}"
ICON="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/linux/orient.png"

case "$FLUTTER_ARCH" in
  x64)   OUT_ARCH=x86_64; DEB_ARCH=amd64; RPM_ARCH=x86_64; APPIMAGE_ARCH=x86_64 ;;
  arm64) OUT_ARCH=arm64;  DEB_ARCH=arm64; RPM_ARCH=aarch64; APPIMAGE_ARCH=aarch64 ;;
  *) echo "package-linux: unsupported arch $FLUTTER_ARCH" >&2; exit 1 ;;
esac

[ -d "$BUNDLE_DIR" ] || { echo "missing bundle: $BUNDLE_DIR" >&2; exit 1; }
mkdir -p "$OUTDIR"

# --- tar.gz + zip -------------------------------------------------------
tar -czf "$OUTDIR/orient-linux-$OUT_ARCH.tar.gz" -C "$BUNDLE_DIR" .
(cd "$BUNDLE_DIR" && zip -qr "$OUTDIR/orient-linux-$OUT_ARCH.zip" .)

DESKTOP_FILE='[Desktop Entry]
Type=Application
Name=Orient
Comment=Local-first encrypted notes
Exec=orient
Icon=orient
Categories=Office;Utility;
Terminal=false'

# --- .deb ---------------------------------------------------------------
PKGDIR="$(mktemp -d)"
mkdir -p "$PKGDIR/opt/orient" "$PKGDIR/usr/bin" "$PKGDIR/usr/share/applications" \
  "$PKGDIR/usr/share/icons/hicolor/1024x1024/apps" "$PKGDIR/DEBIAN"
cp -a "$BUNDLE_DIR/." "$PKGDIR/opt/orient/"
ln -sf /opt/orient/orient "$PKGDIR/usr/bin/orient"
printf '%s\n' "$DESKTOP_FILE" > "$PKGDIR/usr/share/applications/orient.desktop"
cp "$ICON" "$PKGDIR/usr/share/icons/hicolor/1024x1024/apps/orient.png"
cat > "$PKGDIR/DEBIAN/control" <<EOD
Package: orient
Version: $VERSION
Section: utils
Priority: optional
Architecture: $DEB_ARCH
Maintainer: Orient CI <ci@gitlab.com>
Description: Local-first encrypted notes with serverless LAN sync
EOD
dpkg-deb --build "$PKGDIR" "$OUTDIR/orient-linux-$OUT_ARCH.deb" >/dev/null
rm -rf "$PKGDIR"

# --- .rpm ---------------------------------------------------------------
if command -v rpmbuild >/dev/null 2>&1; then
  RPM_VERSION="$(printf '%s' "$VERSION" | tr '-' '~')"
  TOPDIR="$(mktemp -d)"
  mkdir -p "$TOPDIR"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
  cat > "$TOPDIR/SPECS/orient.spec" <<EOD
Name: orient
Version: %{pkg_version}
Release: %{pkg_release}%{?dist}
Summary: Local-first encrypted notes
License: AGPL-3.0-only
URL: https://gitlab.com/HttpAnimations/orient
%global debug_package %{nil}
%global __os_install_post %{nil}
%global __provides_exclude_from ^/opt/orient/.*

%description
Local-first encrypted notes with serverless LAN sync.

%install
mkdir -p %{buildroot}/opt/orient %{buildroot}/usr/bin %{buildroot}/usr/share/applications %{buildroot}/usr/share/icons/hicolor/1024x1024/apps
cp -a %{bundle_dir}/. %{buildroot}/opt/orient/
ln -sf /opt/orient/orient %{buildroot}/usr/bin/orient
install -m644 %{desktop_file} %{buildroot}/usr/share/applications/orient.desktop
install -m644 %{icon_file} %{buildroot}/usr/share/icons/hicolor/1024x1024/apps/orient.png

%files
/opt/orient
/usr/bin/orient
/usr/share/applications/orient.desktop
/usr/share/icons/hicolor/1024x1024/apps/orient.png
EOD
  printf '%s\n' "$DESKTOP_FILE" > "$TOPDIR/orient.desktop"
  rpmbuild -bb \
    --target "$RPM_ARCH" \
    --define "_topdir $TOPDIR" \
    --define "pkg_version $RPM_VERSION" \
    --define "pkg_release $RELEASE" \
    --define "bundle_dir $(realpath "$BUNDLE_DIR")" \
    --define "desktop_file $TOPDIR/orient.desktop" \
    --define "icon_file $ICON" \
    "$TOPDIR/SPECS/orient.spec" >/dev/null
  find "$TOPDIR/RPMS" -name '*.rpm' -exec cp {} "$OUTDIR/orient-linux-$OUT_ARCH.rpm" \;
  rm -rf "$TOPDIR"
fi

# --- AppImage -------------------------------------------------------------
APPIMAGETOOL=/tmp/appimagetool
if [ ! -x "$APPIMAGETOOL" ]; then
  curl -fsSL --retry 3 -o "$APPIMAGETOOL" \
    "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-$APPIMAGE_ARCH.AppImage"
  chmod +x "$APPIMAGETOOL"
fi
APPDIR="$(mktemp -d)/Orient.AppDir"
mkdir -p "$APPDIR/opt/orient"
cp -a "$BUNDLE_DIR/." "$APPDIR/opt/orient/"
printf '%s\n' "$DESKTOP_FILE" | sed 's|Exec=orient|Exec=opt/orient/orient|' > "$APPDIR/orient.desktop"
cp "$ICON" "$APPDIR/orient.png"
cp "$ICON" "$APPDIR/.DirIcon"
cat > "$APPDIR/AppRun" <<'EOD'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
exec "$HERE/opt/orient/orient" "$@"
EOD
chmod +x "$APPDIR/AppRun"
ARCH="$APPIMAGE_ARCH" "$APPIMAGETOOL" "$APPDIR" "$OUTDIR/orient-linux-$OUT_ARCH.AppImage" >/dev/null 2>&1 \
  || { echo "package-linux: appimagetool failed"; }

echo "package-linux: artifacts in $OUTDIR"
ls -la "$OUTDIR"
