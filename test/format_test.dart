import 'package:flutter_test/flutter_test.dart';
import 'package:woist/format.dart';

void main() {
  test('timeAgo', () {
    final now = DateTime(2026, 1, 1, 12);
    expect(timeAgo(now.subtract(const Duration(seconds: 10)), now: now), 'Jetzt');
    expect(timeAgo(now.subtract(const Duration(minutes: 5)), now: now), 'vor 5 Min.');
    expect(timeAgo(now.subtract(const Duration(hours: 3)), now: now), 'vor 3 Std.');
    expect(timeAgo(now.subtract(const Duration(days: 1)), now: now), 'vor 1 Tag');
    expect(timeAgo(null), 'unbekannt');
  });

  test('formatDistance', () {
    expect(formatDistance(420), '420 m');
    expect(formatDistance(2500), '2,5 km');
    expect(formatDistance(42000), '42 km');
  });

  test('initials', () {
    expect(initials('Anna'), 'A');
    expect(initials('Anna Maria Schmidt'), 'AS');
    expect(initials('  '), '?');
  });

  test('normalizeCode', () {
    expect(normalizeCode(' ab3-k9x '), 'AB3K9X');
  });
}
