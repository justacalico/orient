import 'package:flutter_test/flutter_test.dart';
import 'package:orient/util/format.dart';
import 'package:orient/ui/app.dart';

void main() {
  test('app widget constructs', () {
    // ignore: prefer_const_constructors
    expect(OrientApp(), isNotNull);
  });
  group('formatBytes', () {
    test('formats units', () {
      expect(formatBytes(0), '0 B');
      expect(formatBytes(512), '512 B');
      expect(formatBytes(1024), '1.00 KiB');
      expect(formatBytes(1536), '1.50 KiB');
      expect(formatBytes(1024 * 1024 * 5), '5.00 MiB');
      expect(formatBytes(1024 * 1024 * 1024 * 20), '20.0 GiB');
      expect(formatBytes(1024.0 * 1024 * 1024 * 1024 * 3), '3.00 TiB');
      expect(formatBytes(1024.0 * 1024 * 1024 * 1024 * 1024 * 8), '8.00 PiB');
      expect(formatBytes(-5), '?');
    });
  });

  group('formatSpeed', () {
    test('formats rates', () {
      expect(formatSpeed(0), '0 B/s');
      expect(formatSpeed(-2), '0 B/s');
      expect(formatSpeed(2048), '2.00 KiB/s');
    });
  });

  group('formatEta', () {
    test('handles infinite and finite', () {
      expect(formatEta(8640000), '∞');
      expect(formatEta(-1), '∞');
      expect(formatEta(30), '30s');
      expect(formatEta(90), '1m 30s');
      expect(formatEta(3700), '1h 1m');
      expect(formatEta(90000), '1d 1h');
      expect(formatEta(8640000 - 1), '99d 23h');
    });
  });

  group('formatDuration', () {
    test('formats spans', () {
      expect(formatDuration(-1), '—');
      expect(formatDuration(45), '45s');
      expect(formatDuration(600), '10m 0s');
      expect(formatDuration(7200), '2h 0m');
      expect(formatDuration(200000), '2d 7h 33m');
    });
  });

  group('formatRatio', () {
    test('formats ratios', () {
      expect(formatRatio(-1), '—');
      expect(formatRatio(1.234), '1.23');
      expect(formatRatio(0), '0.00');
    });
  });

  group('formatTimestamp', () {
    test('formats and handles unset', () {
      expect(formatTimestamp(0), '—');
      expect(formatTimestamp(-5), '—');
      expect(formatTimestamp(1700000000), contains('2023'));
      expect(formatTimestamp(1700000000, withTime: true), contains(':'));
    });
  });

  group('formatLimit', () {
    test('formats limits', () {
      expect(formatLimit(0), '∞');
      expect(formatLimit(-100), '∞');
      expect(formatLimit(2048), '2.00 KiB/s');
    });
  });

  group('formatAvailability', () {
    test('formats availability', () {
      expect(formatAvailability(-1), '—');
      expect(formatAvailability(1.5), '1.500');
    });
  });
}


