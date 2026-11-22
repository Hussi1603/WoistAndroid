import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../format.dart';
import '../models/person.dart';
import '../services/backend.dart';
import '../services/location_service.dart';
import '../widgets/avatar.dart';
import 'me_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.profile});
  final Profile profile;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _map = MapController();
  final _sheet = DraggableScrollableController();
  late final StreamSubscription<List<Person>> _friendsSub;
  List<Person> _friends = const [];
  int _tab = 0;
  bool _didInitialFit = false;
  Timer? _ticker;

  LocationService get _loc => LocationService.instance;

  @override
  void initState() {
    super.initState();
    _friendsSub = Backend.instance.friendsStream().listen((list) {
      setState(() => _friends = list);
      _maybeInitialFit();
    }, onError: (Object e) => debugPrint('Freunde-Stream: $e'));
    _loc.position.addListener(_maybeInitialFit);
    _applySharing(widget.profile.sharing);
    // "vor X Min." regelmäßig neu zeichnen.
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant HomeScreen old) {
    super.didUpdateWidget(old);
    if (old.profile.sharing != widget.profile.sharing) {
      _applySharing(widget.profile.sharing);
    }
  }

  @override
  void dispose() {
    _friendsSub.cancel();
    _loc.position.removeListener(_maybeInitialFit);
    _ticker?.cancel();
    super.dispose();
  }

  void _applySharing(bool sharing) {
    if (sharing) {
      _loc.start();
    } else {
      _loc.stop();
      _loc.refreshOwnPosition();
    }
  }

  List<LatLng> get _allPoints => [
        if (_loc.position.value != null)
          LatLng(_loc.position.value!.latitude, _loc.position.value!.longitude),
        ..._friends.where((f) => f.hasLocation).map((f) => f.position!),
      ];

  void _maybeInitialFit() {
    if (_didInitialFit || !mounted) return;
    if (_allPoints.isEmpty) return;
    _didInitialFit = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitAll());
  }

  void _fitAll() {
    final pts = _allPoints;
    if (pts.isEmpty) return;
    if (pts.length == 1) {
      _map.move(pts.first, 15);
      return;
    }
    _map.fitCamera(CameraFit.coordinates(
      coordinates: pts,
      padding: EdgeInsets.fromLTRB(
          60, 120, 60, MediaQuery.of(context).size.height * 0.4),
      maxZoom: 16,
    ));
  }

  void _focus(LatLng p) {
    _map.move(p, 16);
    if (_sheet.isAttached) {
      _sheet.animateTo(0.3,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  String? _distanceTo(Person p) {
    final me = _loc.position.value;
    if (me == null || !p.hasLocation) return null;
    return formatDistance(Geolocator.distanceBetween(
        me.latitude, me.longitude, p.position!.latitude, p.position!.longitude));
  }

  Future<void> _openRoute(Person p) async {
    final pos = p.position!;
    final uri = Platform.isIOS
        ? Uri.parse('https://maps.apple.com/?daddr=${pos.latitude},${pos.longitude}')
        : Uri.parse('https://www.google.com/maps/dir/?api=1'
            '&destination=${pos.latitude},${pos.longitude}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Stack(children: [
        ValueListenableBuilder<Position?>(
          valueListenable: _loc.position,
          builder: (context, me, _) => FlutterMap(
            mapController: _map,
            options: const MapOptions(
              initialCenter: LatLng(51.1657, 10.4515), // Deutschland
              initialZoom: 5.5,
              interactionOptions: InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'de.woist.woist',
              ),
              MarkerLayer(markers: [
                if (me != null)
                  Marker(
                    point: LatLng(me.latitude, me.longitude),
                    width: 22,
                    height: 22,
                    child: const MeDot(),
                  ),
                for (final f in _friends.where((f) => f.hasLocation))
                  Marker(
                    point: f.position!,
                    width: 56,
                    height: 62,
                    alignment: Alignment.topCenter,
                    child: GestureDetector(
                      onTap: () => _showPerson(f),
                      child: MapPin(uid: f.uid, name: f.name, dimmed: f.isStale),
                    ),
                  ),
              ]),
              RichAttributionWidget(
                alignment: AttributionAlignment.bottomLeft,
                attributions: [
                  TextSourceAttribution('OpenStreetMap',
                      onTap: () => launchUrl(
                          Uri.parse('https://openstreetmap.org/copyright'))),
                ],
              ),
            ],
          ),
        ),
        // Karten-Buttons oben rechts
        SafeArea(
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Card(
                elevation: 3,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    tooltip: 'Meine Position',
                    icon: const Icon(Icons.my_location),
                    onPressed: () {
                      final me = _loc.position.value;
                      if (me != null) {
                        _focus(LatLng(me.latitude, me.longitude));
                      } else {
                        _loc.refreshOwnPosition();
                      }
                    },
                  ),
                  IconButton(
                    tooltip: 'Alle anzeigen',
                    icon: const Icon(Icons.zoom_out_map),
                    onPressed: _fitAll,
                  ),
                ]),
              ),
            ),
          ),
        ),
        DraggableScrollableSheet(
          controller: _sheet,
          initialChildSize: 0.38,
          minChildSize: 0.14,
          maxChildSize: 0.9,
          snap: true,
          snapSizes: const [0.38],
          builder: (context, scroll) => Material(
            elevation: 12,
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            clipBehavior: Clip.antiAlias,
            child: ListView(
              controller: scroll,
              padding: EdgeInsets.zero,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(
                          value: 0,
                          icon: Icon(Icons.people),
                          label: Text('Personen')),
                      ButtonSegment(
                          value: 1, icon: Icon(Icons.person), label: Text('Ich')),
                    ],
                    selected: {_tab},
                    onSelectionChanged: (s) => setState(() => _tab = s.first),
                  ),
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder<String?>(
                  valueListenable: _loc.error,
                  builder: (context, err, _) => err == null
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                          child: Card(
                            color: theme.colorScheme.errorContainer,
                            child: ListTile(
                              leading: const Icon(Icons.location_off),
                              title: Text(err),
                              trailing: TextButton(
                                onPressed: Geolocator.openAppSettings,
                                child: const Text('Einstellungen'),
                              ),
                            ),
                          ),
                        ),
                ),
                if (_tab == 0) ..._peopleList(theme) else MeTab(profile: widget.profile),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  List<Widget> _peopleList(ThemeData theme) {
    if (_friends.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            Icon(Icons.people_outline,
                size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 8),
            Text('Noch niemand teilt seinen Standort mit dir.',
                textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Gib deiner Partnerin deinen Code (Tab "Ich"). Sie trägt ihn in '
              'ihrer App unter "Standort teilen mit …" ein – und du ihren in deiner.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
                onPressed: () => setState(() => _tab = 1),
                child: const Text('Meinen Code anzeigen')),
          ]),
        ),
      ];
    }
    return [
      for (final f in _friends)
        ListTile(
          leading: Avatar(uid: f.uid, name: f.name, dimmed: !f.hasLocation || f.isStale),
          title: Text(f.name, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(_subtitle(f)),
          trailing: f.hasLocation
              ? Text(_distanceTo(f) ?? '', style: theme.textTheme.bodySmall)
              : null,
          onTap: () => _showPerson(f),
        ),
    ];
  }

  String _subtitle(Person f) {
    if (!f.sharing) return 'Teilen pausiert';
    if (f.position == null) return 'Noch kein Standort';
    final parts = <String>[timeAgo(f.updatedAt)];
    if (f.battery != null) {
      parts.add('🔋 ${f.battery}%${f.charging ? ' ⚡' : ''}');
    }
    return parts.join(' · ');
  }

  void _showPerson(Person f) {
    if (f.hasLocation) _focus(f.position!);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        final dist = _distanceTo(f);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Avatar(uid: f.uid, name: f.name, size: 64),
              const SizedBox(height: 8),
              Text(f.name, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(_subtitle(f), style: theme.textTheme.bodyMedium),
              if (dist != null) Text('$dist entfernt', style: theme.textTheme.bodySmall),
              if (f.accuracy != null && f.hasLocation)
                Text('Genauigkeit ± ${f.accuracy!.round()} m',
                    style: theme.textTheme.bodySmall),
              const SizedBox(height: 16),
              if (f.hasLocation)
                Row(children: [
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.directions),
                      label: const Text('Route'),
                      onPressed: () => _openRoute(f),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.center_focus_strong),
                      label: const Text('Auf Karte'),
                      onPressed: () {
                        Navigator.pop(context);
                        _focus(f.position!);
                      },
                    ),
                  ),
                ]),
            ]),
          ),
        );
      },
    );
  }
}
