import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

import '../../../core/sync/app_backup_service.dart';
import '../../../core/sync/remote_backup_service.dart';

/// Yedek dışa / içe aktarma (dosya + isteğe bağlı uzak URL).
///
/// [remoteHttpClient] verilirse uzak PUT/GET bu istemciyle yapılır (ör. test / özel TLS).
class BackupPage extends StatefulWidget {
  const BackupPage({super.key, this.remoteHttpClient});

  final http.Client? remoteHttpClient;

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  String _status = '';
  final _urlCtrl = TextEditingController();
  final _authCtrl = TextEditingController();
  /// [true]: mevcut prefs ile birleştir; [false]: önce temizle, yalnızca yedek.
  bool _mergeRestore = true;

  @override
  void initState() {
    super.initState();
    _loadRemotePrefs();
  }

  Future<void> _loadRemotePrefs() async {
    final u = await RemoteBackupPrefs.getUrl();
    final raw = await RemoteBackupPrefs.getAuthRaw();
    if (!mounted) return;
    setState(() {
      if (u != null) _urlCtrl.text = u;
      if (raw != null) _authCtrl.text = raw;
    });
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _authCtrl.dispose();
    super.dispose();
  }

  Future<bool> _confirmReplaceBeforeRestore() async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yerel ayarları silmek'),
        content: const Text(
          'Birleştirme kapalı: önce tüm yerel ayarlar silinir, ardından yalnızca yedekteki değerler yazılır. '
          'Geri dönüş olmadan önce bu cihazdan dışa aktarın.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Devam et')),
        ],
      ),
    );
    return r == true;
  }

  Future<void> _export() async {
    setState(() => _status = 'Toplanıyor…');
    try {
      final payload = await AppBackupService.collectPayload();
      final json = AppBackupService.payloadToJson(payload);
      final bytes = Uint8List.fromList(utf8.encode(json));
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(bytes, mimeType: 'application/json', name: 'blue_viper_backup.json'),
          ],
          subject: 'Blue Viper yedek',
        ),
      );
      setState(() => _status = kIsWeb ? 'Paylaşıldı.' : 'Dosya hazır ve paylaşıldı.');
    } catch (e) {
      setState(() => _status = 'Hata: $e');
    }
  }

  Future<void> _import() async {
    setState(() => _status = 'Dosya seçin…');
    try {
      final r = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
        withData: true,
      );
      if (r == null || r.files.isEmpty) {
        setState(() => _status = 'İptal.');
        return;
      }
      final f = r.files.single;
      String? text;
      if (f.bytes != null) {
        text = utf8.decode(f.bytes!);
      } else if (f.path != null && !kIsWeb) {
        text = await XFile(f.path!).readAsString();
      }
      if (text == null || text.isEmpty) {
        setState(() => _status = 'Okunamadı.');
        return;
      }
      if (!_mergeRestore && !await _confirmReplaceBeforeRestore()) {
        setState(() => _status = 'İptal.');
        return;
      }
      await AppBackupService.restoreFromJson(text, merge: _mergeRestore);
      if (!mounted) return;
      setState(
        () => _status = _mergeRestore
            ? 'Geri yüklendi (birleştirildi); balistik sayfasına dönün.'
            : 'Geri yüklendi (yerel ayarlar değiştirildi); balistik sayfasına dönün.',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _mergeRestore
                ? 'Yedek uygulandı (birleştirildi).'
                : 'Yedek uygulandı (önceki yerel ayarlar silindi).',
          ),
        ),
      );
    } catch (e) {
      setState(() => _status = 'Hata: $e');
    }
  }

  Future<void> _saveRemotePrefs() async {
    await RemoteBackupPrefs.save(url: _urlCtrl.text, auth: _authCtrl.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Uzak yedek ayarları kaydedildi.')),
    );
  }

  Future<void> _pushRemote() async {
    setState(() => _status = 'Uzak sunucuya gönderiliyor…');
    try {
      final payload = await AppBackupService.collectPayload();
      final json = AppBackupService.payloadToJson(payload);
      await RemoteBackupService.push(json, httpClient: widget.remoteHttpClient);
      if (!mounted) return;
      setState(() => _status = 'Uzak yedek tamam (PUT).');
    } catch (e) {
      setState(() => _status = 'Uzak hata: $e');
    }
  }

  Future<void> _pullRemote() async {
    setState(() => _status = 'Uzak yedek indiriliyor…');
    try {
      if (!_mergeRestore && !await _confirmReplaceBeforeRestore()) {
        setState(() => _status = 'İptal.');
        return;
      }
      final text = await RemoteBackupService.pull(httpClient: widget.remoteHttpClient);
      await AppBackupService.restoreFromJson(text, merge: _mergeRestore);
      if (!mounted) return;
      setState(() => _status = 'Uzak yedek uygulandı.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _mergeRestore
                ? 'Uzak JSON birleştirildi.'
                : 'Uzak yedek uygulandı (yerel ayarlar değiştirildi).',
          ),
        ),
      );
    } catch (e) {
      setState(() => _status = 'Uzak hata: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Cihazlar arası yedek',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Tüm yerel ayarlar (silah profili, kullanıcı silah/dürbün/mühimmat listeleri) tek JSON dosyasında toplanır. '
            'Dosyayı bulut sürücü veya mesajla taşıyın; veya kendi HTTPS uç noktanıza PUT/GET ile senk edin.',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Yedek ile birleştir'),
            subtitle: const Text(
              'Açık: mevcut ayarlar korunur, yedek üstüne yazar. '
              'Kapalı: önce tüm yerel ayarlar silinir (dikkat).',
            ),
            value: _mergeRestore,
            onChanged: (v) => setState(() => _mergeRestore = v),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _export,
            icon: const Icon(Icons.upload_file),
            label: const Text('Dışa aktar (paylaş)'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _import,
            icon: const Icon(Icons.download),
            label: const Text('İçe aktar (JSON seç)'),
          ),
          const SizedBox(height: 24),
          Text('Uzak yedek (HTTPS)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text(
            'Örnek: kendi sunucunuzda aynı URL’ye GET (indir) ve PUT (yükle, gövde = tam yedek JSON). '
            'Kimlik: «Bearer …» veya «Basic …» veya ham token (otomatik Bearer eklenir).',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _urlCtrl,
            decoration: const InputDecoration(
              labelText: 'Yedek URL',
              hintText: 'https://api.example.com/blue-viper-backup',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _authCtrl,
            decoration: const InputDecoration(
              labelText: 'Authorization (isteğe bağlı)',
              hintText: 'Bearer xxx veya Basic xxx',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilledButton.tonal(
                  key: const Key('backup_save_remote'),
                  onPressed: _saveRemotePrefs,
                  child: const Text('Ayarları kaydet'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  key: const Key('backup_put_remote'),
                  onPressed: _pushRemote,
                  child: const Text('PUT gönder'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  key: const Key('backup_get_remote'),
                  onPressed: _pullRemote,
                  child: const Text('GET çek'),
                ),
              ],
            ),
          ),
          if (_status.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(_status, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          ],
        ],
      ),
    );
  }
}
