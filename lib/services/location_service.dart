import 'dart:async';
import 'dart:io';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import 'backend.dart';

/// Holt laufend den Standort (auch im Hintergrund) und lädt ihn hoch.
class LocationService {
  LocationService._();
  static final instance = LocationService._();

  /// Letzte bekannte eigene Position (auch wenn Teilen aus ist).
  final position = ValueNotifier<Position?>(null);

  /// Läuft die Hintergrund-Ortung gerade?
  final running = ValueNotifier<bool>(false);

  /// Letzter Fehler (z. B. fehlende Berechtigung).
  final error = ValueNotifier<String?>(null);

  StreamSubscription<Position>? _sub;
  Timer? _heartbeat;
  DateTime _lastUpload = DateTime.fromMillisecondsSinceEpoch(0);
  final _battery = Battery();

  static const _minUploadInterval = Duration(seconds: 15);
  static const _heartbeatInterval = Duration(minutes: 3);

  /// Fragt die nötigen Berechtigungen ab. true = Ortung möglich.
  Future<bool> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      error.value = 'Ortungsdienste sind ausgeschaltet.';
      return false;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      error.value = 'Kein Zugriff auf den Standort. Bitte in den '
          'Einstellungen erlauben ("Immer" für Hintergrund-Ortung).';
      return false;
    }
    if (Platform.isAndroid) {
      // Benachrichtigung für den Vordergrund-Dienst (Android 13+).
      await Permission.notification.request();
      // "Immer erlauben" – damit die Ortung zuverlässig im Hintergrund läuft.
      if (perm == LocationPermission.whileInUse) {
        await Permission.locationAlways.request();
      }
    } else if (perm == LocationPermission.whileInUse) {
      // iOS: zweite Abfrage hebt auf "Immer" an (sofern möglich).
      await Geolocator.requestPermission();
    }
    error.value = null;
    return true;
  }

  LocationSettings get _settings {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 20,
        intervalDuration: const Duration(seconds: 30),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Wo ist? teilt deinen Standort',
          notificationText: 'Deine Freunde sehen, wo du bist.',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.other,
        distanceFilter: 20,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: false,
      );
    }
    return const LocationSettings(
        accuracy: LocationAccuracy.high, distanceFilter: 20);
  }

  /// Startet das Teilen (Hintergrund-Ortung + Upload).
  Future<void> start() async {
    if (_sub != null) return;
    if (!await ensurePermission()) return;

    _sub = Geolocator.getPositionStream(locationSettings: _settings).listen(
      (pos) {
        position.value = pos;
        if (DateTime.now().difference(_lastUpload) >= _minUploadInterval) {
          _upload(pos);
        }
      },
      onError: (Object e) => error.value = 'Ortungsfehler: $e',
    );
    // Auch ohne Bewegung regelmäßig "lebt noch" + Akkustand senden.
    _heartbeat = Timer.periodic(_heartbeatInterval, (_) {
      final p = position.value;
      if (p != null) _upload(p);
    });
    running.value = true;

    // Sofort einen ersten Punkt holen, statt auf Bewegung zu warten.
    try {
      final p = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high));
      position.value = p;
      await _upload(p);
    } catch (_) {/* Stream liefert später */}
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _heartbeat?.cancel();
    _heartbeat = null;
    running.value = false;
  }

  /// Nur die eigene Position für die Karte holen (ohne Upload).
  Future<void> refreshOwnPosition() async {
    if (!await ensurePermission()) return;
    try {
      position.value = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high));
    } catch (_) {}
  }

  Future<void> _upload(Position pos) async {
    _lastUpload = DateTime.now();
    int? level;
    var charging = false;
    try {
      level = await _battery.batteryLevel;
      final state = await _battery.batteryState;
      charging = state == BatteryState.charging || state == BatteryState.full;
    } catch (_) {}
    try {
      await Backend.instance.uploadLocation(
        lat: pos.latitude,
        lng: pos.longitude,
        accuracy: pos.accuracy,
        battery: level,
        charging: charging,
      );
    } catch (e) {
      debugPrint('Upload fehlgeschlagen: $e');
    }
  }
}
