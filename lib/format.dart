/// Kleine Formatierungs-Helfer (deutsch).
String timeAgo(DateTime? t, {DateTime? now}) {
  if (t == null) return 'unbekannt';
  final diff = (now ?? DateTime.now()).difference(t);
  if (diff.inSeconds < 60) return 'Jetzt';
  if (diff.inMinutes < 60) return 'vor ${diff.inMinutes} Min.';
  if (diff.inHours < 24) return 'vor ${diff.inHours} Std.';
  final days = diff.inDays;
  return days == 1 ? 'vor 1 Tag' : 'vor $days Tagen';
}

String formatDistance(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  final km = meters / 1000;
  return km < 10
      ? '${km.toStringAsFixed(1).replaceAll('.', ',')} km'
      : '${km.round()} km';
}

String initials(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

/// Normalisiert einen eingegebenen Code (Großbuchstaben, ohne Leerzeichen/Bindestriche).
String normalizeCode(String input) =>
    input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
