import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/person.dart';
import '../services/backend.dart';
import '../services/location_service.dart';
import '../widgets/avatar.dart';

class MeTab extends StatelessWidget {
  const MeTab({super.key, required this.profile});
  final Profile profile;

  void _snack(BuildContext context, String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _addPerson(BuildContext context) async {
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Standort teilen mit …'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Gib den 6-stelligen Code der Person ein. Sie sieht dann '
              'deinen Standort.'),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            maxLength: 7,
            style: const TextStyle(
                fontSize: 24, letterSpacing: 4, fontFamily: 'monospace'),
            decoration: const InputDecoration(
                hintText: 'ABC123', border: OutlineInputBorder()),
            onSubmitted: (v) => Navigator.pop(context, v),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text),
              child: const Text('Teilen')),
        ],
      ),
    );
    if (code == null || code.trim().isEmpty) return;
    try {
      final name = await Backend.instance.shareWithCode(code);
      if (context.mounted) {
        _snack(context, 'Du teilst deinen Standort jetzt mit $name.');
      }
    } catch (e) {
      if (context.mounted) {
        _snack(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _rename(BuildContext context) async {
    final ctrl = TextEditingController(text: profile.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Name ändern'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text),
              child: const Text('Speichern')),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    await Backend.instance.rename(name.trim(), profile.code);
  }

  Future<void> _confirmStop(BuildContext context, String uid, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Nicht mehr mit $name teilen?'),
        content: Text('$name sieht deinen Standort dann nicht mehr.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Beenden')),
        ],
      ),
    );
    if (ok == true) await Backend.instance.stopSharingWith(uid);
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konto löschen?'),
        content: const Text(
            'Dein Standort, dein Code und alle Freigaben werden gelöscht.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen')),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Löschen')),
        ],
      ),
    );
    if (ok != true) return;
    await LocationService.instance.stop();
    try {
      await Backend.instance.deleteAccount(profile.code);
    } catch (e) {
      if (context.mounted) _snack(context, 'Fehler: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final code = profile.code;
    final pretty =
        code.length == 6 ? '${code.substring(0, 3)} ${code.substring(3)}' : code;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ListTile(
        leading: Avatar(uid: profile.uid, name: profile.name),
        title: Text(profile.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: const Text('Tippen zum Ändern'),
        onTap: () => _rename(context),
      ),
      Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Text('Dein Code', style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            SelectableText(pretty,
                style: theme.textTheme.displaySmall?.copyWith(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4)),
            const SizedBox(height: 4),
            Text(
              'Gib diesen Code deiner Partnerin. Trägt sie ihn in ihrer App '
              'ein, siehst du ihren Standort.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            TextButton.icon(
              icon: const Icon(Icons.copy),
              label: const Text('Kopieren'),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: code));
                if (context.mounted) _snack(context, 'Code kopiert');
              },
            ),
          ]),
        ),
      ),
      ValueListenableBuilder<bool>(
        valueListenable: LocationService.instance.running,
        builder: (context, running, _) => SwitchListTile(
          secondary: Icon(profile.sharing ? Icons.location_on : Icons.location_off),
          title: const Text('Meinen Standort teilen'),
          subtitle: Text(profile.sharing
              ? (running ? 'Aktiv – wird im Hintergrund aktualisiert' : 'Wird gestartet …')
              : 'Pausiert – niemand sieht deinen Standort'),
          value: profile.sharing,
          onChanged: (v) => Backend.instance.setSharing(v),
        ),
      ),
      const Divider(),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Text('Du teilst deinen Standort mit',
            style: theme.textTheme.titleSmall),
      ),
      if (profile.sharingWith.isEmpty)
        const ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('Noch mit niemandem'),
        ),
      for (final e in profile.sharingWith.entries)
        ListTile(
          leading: Avatar(uid: e.key, name: e.value, size: 36),
          title: Text(e.value),
          trailing: IconButton(
            tooltip: 'Teilen beenden',
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: () => _confirmStop(context, e.key, e.value),
          ),
        ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: FilledButton.icon(
          icon: const Icon(Icons.person_add),
          label: const Text('Standort teilen mit …'),
          onPressed: () => _addPerson(context),
        ),
      ),
      const Divider(),
      if (Platform.isAndroid)
        ListTile(
          leading: const Icon(Icons.battery_saver),
          title: const Text('Akku-Optimierung ausschalten'),
          subtitle: const Text(
              'Empfohlen, damit Android die Ortung im Hintergrund nicht stoppt.'),
          onTap: () => Permission.ignoreBatteryOptimizations.request(),
        ),
      ListTile(
        leading: const Icon(Icons.settings),
        title: const Text('Standort-Berechtigung'),
        subtitle: const Text('Für Hintergrund-Ortung auf "Immer" stellen'),
        onTap: openAppSettings,
      ),
      ListTile(
        leading: Icon(Icons.delete_outline, color: theme.colorScheme.error),
        title: Text('Konto löschen',
            style: TextStyle(color: theme.colorScheme.error)),
        onTap: () => _deleteAccount(context),
      ),
    ]);
  }
}
