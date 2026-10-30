import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The README's release badge is a committed SVG (docs/badges/release.svg) so it
// loads even when shields.io doesn't. Regenerate it on every version bump:
//   curl -o docs/badges/release.svg \
//     "https://img.shields.io/badge/Release-v<version>-1A8C45?style=flat-square"
void main() {
  test('README release badge matches the pubspec version', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(r'^version:\s*([0-9.]+)', multiLine: true)
        .firstMatch(pubspec)!
        .group(1);
    final badge = File('docs/badges/release.svg').readAsStringSync();
    expect(badge, contains('Release: v$version'));
  });
}
