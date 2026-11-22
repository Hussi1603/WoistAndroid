import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

/// Eine Person, die ihren Standort mit mir teilt (oder ich selbst).
class Person {
  final String uid;
  final String name;
  final LatLng? position;
  final double? accuracy;
  final int? battery;
  final bool charging;
  final DateTime? updatedAt;
  final bool sharing;

  const Person({
    required this.uid,
    required this.name,
    this.position,
    this.accuracy,
    this.battery,
    this.charging = false,
    this.updatedAt,
    this.sharing = true,
  });

  bool get hasLocation => sharing && position != null;

  /// Länger als 1 Stunde keine Aktualisierung.
  bool get isStale =>
      updatedAt == null ||
      DateTime.now().difference(updatedAt!) > const Duration(hours: 1);

  factory Person.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    final lat = (d['lat'] as num?)?.toDouble();
    final lng = (d['lng'] as num?)?.toDouble();
    final ts = d['updatedAt'];
    return Person(
      uid: doc.id,
      name: (d['name'] as String?) ?? '?',
      position: (lat != null && lng != null) ? LatLng(lat, lng) : null,
      accuracy: (d['accuracy'] as num?)?.toDouble(),
      battery: (d['battery'] as num?)?.toInt(),
      charging: d['charging'] == true,
      updatedAt: ts is Timestamp ? ts.toDate() : null,
      sharing: d['sharing'] != false,
    );
  }
}

/// Mein eigenes Profil (nur für mich lesbar).
class Profile {
  final String uid;
  final String name;
  final String code;
  final bool sharing;

  /// Personen, mit denen ICH meinen Standort teile: uid -> Name.
  final Map<String, String> sharingWith;

  const Profile({
    required this.uid,
    required this.name,
    required this.code,
    required this.sharing,
    required this.sharingWith,
  });

  factory Profile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    final raw = (d['sharingWith'] as Map?) ?? const {};
    return Profile(
      uid: doc.id,
      name: (d['name'] as String?) ?? '',
      code: (d['code'] as String?) ?? '',
      sharing: d['sharing'] != false,
      sharingWith: raw.map((k, v) => MapEntry(k.toString(), v.toString())),
    );
  }
}
