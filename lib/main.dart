import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import 'core/profile/weapon_profile_store.dart';
import 'features/ballistics/presentation/ballistics_page.dart';
import 'features/bluetooth/presentation/bluetooth_page.dart';
import 'features/licensing/presentation/activation_gate.dart';
import 'features/maps/presentation/maps_page.dart';
import 'features/maps/presentation/startup_permissions_page.dart';
import 'core/geo/app_bootstrap_prefs.dart';
import 'core/realtime/realtime_ptt_service_factory.dart';
import 'features/shooting/presentation/shooting_hub_page.dart';
import 'features/sync/presentation/backup_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    try {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    } catch (_) {}
  }
  await WeaponProfileStore.loadPersisted();
  runApp(const BlueViperProApp());
}

class BlueViperProApp extends StatelessWidget {
  const BlueViperProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Blue Viper Pro',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B5E20),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
      ),
      home: const ActivationGate(child: _AppBootstrapShell()),
    );
  }
}

/// İlk açılışta konum / Bluetooth tanıtımı; sonra ana sekmeler.
class _AppBootstrapShell extends StatefulWidget {
  const _AppBootstrapShell();

  @override
  State<_AppBootstrapShell> createState() => _AppBootstrapShellState();
}

class _AppBootstrapShellState extends State<_AppBootstrapShell> {
  bool? _introDone;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final done = await AppBootstrapPrefs.isIntroDone();
    if (!mounted) return;
    setState(() => _introDone = done);
  }

  void _onIntroFinished() => setState(() => _introDone = true);

  @override
  Widget build(BuildContext context) {
    if (_introDone == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_introDone == false) {
      return StartupPermissionsPage(onFinished: _onIntroFinished);
    }
    return const _RootScaffold();
  }
}

enum _ShootingPanel { hub, balistik, bluetooth, yedek }

class _RootScaffold extends StatefulWidget {
  const _RootScaffold();

  @override
  State<_RootScaffold> createState() => _RootScaffoldState();
}

class _RootScaffoldState extends State<_RootScaffold> {
  static const String _pttBackendEnv = String.fromEnvironment(
    'PTT_BACKEND',
    defaultValue: 'remote',
  );
  static const String _pttWsUrl = String.fromEnvironment(
    'PTT_WS_URL',
    defaultValue: '',
  );

  RealtimePttBackend get _pttBackend {
    switch (_pttBackendEnv.toLowerCase()) {
      case 'memory':
      case 'inmemory':
        return RealtimePttBackend.inMemory;
      case 'remote':
      default:
        return RealtimePttBackend.remote;
    }
  }
  /// 0 = Atış, 1 = Harita
  int _branchIndex = 0;
  _ShootingPanel _shootingPanel = _ShootingPanel.hub;

  String get _appBarTitle {
    if (_branchIndex == 1) return 'Harita';
    return switch (_shootingPanel) {
      _ShootingPanel.hub => 'Atış',
      _ShootingPanel.balistik => 'Balistik',
      _ShootingPanel.bluetooth => 'Bluetooth',
      _ShootingPanel.yedek => 'Yedek',
    };
  }

  Future<void> _confirmExitIfNeeded() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Uygulamadan çıkılsın mı?'),
        content: const Text('Blue Viper Pro kapatılacak.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hayır')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Evet')),
        ],
      ),
    );
    if (ok == true && mounted) {
      SystemNavigator.pop();
    }
  }

  void _onBackOrPop() {
    if (_branchIndex == 1) {
      setState(() => _branchIndex = 0);
      return;
    }
    if (_shootingPanel != _ShootingPanel.hub) {
      setState(() => _shootingPanel = _ShootingPanel.hub);
      return;
    }
    unawaited(_confirmExitIfNeeded());
  }


  bool get _canPopOneLevel {
    return _branchIndex == 1 || _shootingPanel != _ShootingPanel.hub;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _onBackOrPop();
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: _branchIndex == 1
              ? Colors.black.withValues(alpha: 0.35)
              : Theme.of(context).colorScheme.surface,
          surfaceTintColor: Colors.transparent,
          foregroundColor: _branchIndex == 1 ? Colors.white : null,
          elevation: 0,
          title: _branchIndex == 1
              ? const SizedBox.shrink()
              : Text(_appBarTitle),
          leading: _canPopOneLevel
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _onBackOrPop,
                )
              : null,
          automaticallyImplyLeading: false,
        ),
        body: IndexedStack(
          index: _branchIndex,
          alignment: Alignment.topCenter,
          children: [
            _buildAtisBody(context),
            MapsPage(
              pttBackend: _pttBackend,
              pttWebsocketUrl: _pttWsUrl.isEmpty ? null : _pttWsUrl,
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _branchIndex,
          onDestinationSelected: (i) => setState(() => _branchIndex = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.gps_fixed_outlined),
              selectedIcon: Icon(Icons.gps_fixed),
              label: 'Atış',
            ),
            NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map),
              label: 'Harita',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAtisBody(BuildContext context) {
    return switch (_shootingPanel) {
      _ShootingPanel.hub => ShootingHubPage(
          onBalistik: () => setState(() => _shootingPanel = _ShootingPanel.balistik),
          onBluetooth: () => setState(() => _shootingPanel = _ShootingPanel.bluetooth),
          onYedek: () => setState(() => _shootingPanel = _ShootingPanel.yedek),
          onHarita: () => setState(() => _branchIndex = 1),
        ),
      _ShootingPanel.balistik => const BallisticsPage(),
      _ShootingPanel.bluetooth => const BluetoothPage(),
      _ShootingPanel.yedek => const BackupPage(),
    };
  }
}
