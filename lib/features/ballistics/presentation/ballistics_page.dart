import 'package:flutter/material.dart';

import '../../../core/ballistics/ballistics_engine.dart';
import '../../../core/ballistics/ballistics_export.dart';
import '../../../core/ballistics/bc_g7_estimate.dart';
import '../../../core/ballistics/bc_kind.dart';
import '../../../core/ballistics/bc_mach_segment.dart';
import '../../../core/ballistics/click_units.dart';
import '../../../core/ballistics/custom_drag_table.dart';
import '../../../core/ballistics/powder_temperature.dart';
import '../../../core/ballistics/wind_geometry.dart';
import '../../../core/bluetooth/ballistics_env_bridge.dart';
import '../../../core/catalog/catalog_data.dart';
import '../../../core/catalog/catalog_loader.dart';
import '../../../core/catalog/user_catalog_store.dart';
import '../../../core/catalog/weapon_ballistic_presets.dart';
import '../../../core/geo/saved_targets_store.dart';
import '../../../core/geo/target_solution_store.dart';
import '../../../core/profile/weapon_profile_store.dart';
import '../../../core/reticles/reticle_catalog_loader.dart';
import '../../../core/reticles/reticle_definition.dart';
import '../../../core/reticles/reticle_user_prefs.dart';
import 'reticle_hold_view.dart';
import 'reticle_photo_section.dart';

class BallisticsPage extends StatefulWidget {
  const BallisticsPage({super.key});

  @override
  State<BallisticsPage> createState() => _BallisticsPageState();
}

class _BallisticsPageState extends State<BallisticsPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final _distanceCtrl = TextEditingController(text: '500');
  final _weaponNameCtrl = TextEditingController(text: 'Rifle-1');
  final _mvCtrl = TextEditingController(text: '800');
  final _bcCtrl = TextEditingController(text: '0.45');
  final _tempCtrl = TextEditingController(text: '15');
  final _pressureCtrl = TextEditingController(text: '1013');
  final _rhCtrl = TextEditingController(text: '40');
  final _daCtrl = TextEditingController();
  final _elevDeltaCtrl = TextEditingController(text: '0');
  final _slopeCtrl = TextEditingController(text: '0');
  final _sightHcmCtrl = TextEditingController(text: '3.8');
  final _zeroRangeCtrl = TextEditingController(text: '100');
  final _crossWindCtrl = TextEditingController(text: '0');
  final _windSpeedVecCtrl = TextEditingController(text: '0');
  final _windFromCtrl = TextEditingController(text: '270');
  final _shotAzCtrl = TextEditingController(text: '0');
  final _latCtrl = TextEditingController(text: '39.0');
  final _grainCtrl = TextEditingController(text: '175');
  final _calInCtrl = TextEditingController(text: '0.308');
  final _twistInCtrl = TextEditingController(text: '10');
  final _powderT1Ctrl = TextEditingController();
  final _powderV1Ctrl = TextEditingController();
  final _powderT2Ctrl = TextEditingController();
  final _powderV2Ctrl = TextEditingController();
  final _powderCurTCtrl = TextEditingController();
  final _scopeMagCtrl = TextEditingController(text: '10');
  final _refMagCtrl = TextEditingController(text: '10');
  final _tableStartCtrl = TextEditingController(text: '100');
  final _tableEndCtrl = TextEditingController(text: '800');
  final _tableStepCtrl = TextEditingController(text: '50');
  final _reticleSearchCtrl = TextEditingController();
  final _bcSegCtrl = TextEditingController();
  final _customDragCtrl = TextEditingController();
  final _targetCrossCtrl = TextEditingController(text: '0');

  final _clickValueCtrl = TextEditingController(text: '0.1');

  ClickUnit _clickUnit = ClickUnit.mil;
  BcKind _bcKind = BcKind.g1;
  bool _coriolisOn = false;
  bool _spinOn = false;
  bool _jumpOn = false;
  bool _twistRightHanded = true;
  bool _useMetWindVector = false;
  bool _reticleFfp = true;

  WeaponType? _selectedWeapon;
  ScopeType? _selectedScope;
  AmmoType? _selectedAmmo;
  String? _selectedAmmoVariantId;
  List<WeaponType> _weapons = CatalogData.weapons;
  List<ScopeType> _scopes = CatalogData.scopes;
  List<AmmoType> _ammos = CatalogData.ammos;

  List<ReticleDefinition> _reticles = [];
  ReticleDefinition? _selectedReticle;
  String _reticleFilter = '';
  List<String> _recentReticleIds = [];
  List<String> _favoriteReticleIds = [];

  BallisticsSolveOutput? _result;

  List<SavedTargetPreset> _savedTargets = [];

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {});
    });
    WeaponProfileStore.current.addListener(_onWeaponProfileChanged);
    BallisticsEnvBridge.pending.addListener(_applyBleEnvToForm);
    _loadUserCatalog();
    _loadReticleCatalog();
    SavedTargetsStore.load().then((list) {
      if (mounted) setState(() => _savedTargets = list);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyBleEnvToForm());
  }

  /// BLE’den gelen sıcaklık / basınç / nem alanlarını doldurur (Kestrel vb.).
  void _applyBleEnvToForm() {
    if (!mounted) return;
    final r = BallisticsEnvBridge.pending.value;
    if (r == null || r.isEmpty) return;
    setState(() {
      if (r.temperatureC != null) {
        _tempCtrl.text = r.temperatureC!.toStringAsFixed(1);
      }
      if (r.pressureHpa != null) {
        _pressureCtrl.text = r.pressureHpa!.toStringAsFixed(0);
      }
      if (r.humidityPercent != null) {
        _rhCtrl.text = r.humidityPercent!.toStringAsFixed(0);
      }
    });
    BallisticsEnvBridge.pending.value = null;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('BLE ortam değerleri forma yazıldı (sıcaklık / basınç / nem).'),
      ),
    );
  }

  void _onWeaponProfileChanged() {
    if (!mounted) return;
    _applyPersistedProfileToForm();
  }

  void _applyPersistedProfileToForm() {
    final p = WeaponProfileStore.current.value;
    if (p == null) return;
    setState(() {
      _weaponNameCtrl.text = p.name;
      _mvCtrl.text = p.muzzleVelocityMps.toStringAsFixed(0);
      _bcCtrl.text = p.displayBallisticCoefficient.toString();
      _bcKind = p.bcKind;
      _sightHcmCtrl.text = (p.sightHeightM * 100).toStringAsFixed(1);
      _zeroRangeCtrl.text = p.zeroRangeM.toStringAsFixed(0);
      _clickUnit = p.clickUnit;
      _clickValueCtrl.text = p.clickValue.toString();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    BallisticsEnvBridge.pending.removeListener(_applyBleEnvToForm);
    WeaponProfileStore.current.removeListener(_onWeaponProfileChanged);
    for (final c in [
      _distanceCtrl,
      _weaponNameCtrl,
      _mvCtrl,
      _bcCtrl,
      _tempCtrl,
      _pressureCtrl,
      _rhCtrl,
      _daCtrl,
      _elevDeltaCtrl,
      _slopeCtrl,
      _sightHcmCtrl,
      _zeroRangeCtrl,
      _crossWindCtrl,
      _windSpeedVecCtrl,
      _windFromCtrl,
      _shotAzCtrl,
      _latCtrl,
      _grainCtrl,
      _calInCtrl,
      _twistInCtrl,
      _powderT1Ctrl,
      _powderV1Ctrl,
      _powderT2Ctrl,
      _powderV2Ctrl,
      _powderCurTCtrl,
      _scopeMagCtrl,
      _refMagCtrl,
      _tableStartCtrl,
      _tableEndCtrl,
      _tableStepCtrl,
      _reticleSearchCtrl,
      _bcSegCtrl,
      _customDragCtrl,
      _targetCrossCtrl,
      _clickValueCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadUserCatalog() async {
    final bundled = await CatalogLoader.loadTurkeyNato();
    final uw = await UserCatalogStore.loadWeapons();
    final us = await UserCatalogStore.loadScopes();
    final ua = await UserCatalogStore.loadAmmos();
    if (!mounted) return;
    setState(() {
      _weapons = CatalogLoader.mergeWeapons(CatalogData.weapons, bundled.weapons, uw);
      _scopes = CatalogLoader.mergeScopes(CatalogData.scopes, bundled.scopes, us);
      _ammos = CatalogLoader.mergeAmmos(CatalogData.ammos, bundled.ammos, ua);
      final persisted = WeaponProfileStore.current.value;
      if (persisted != null) {
        _weaponNameCtrl.text = persisted.name;
        _mvCtrl.text = persisted.muzzleVelocityMps.toStringAsFixed(0);
        _bcCtrl.text = persisted.displayBallisticCoefficient.toString();
        _bcKind = persisted.bcKind;
        _sightHcmCtrl.text = (persisted.sightHeightM * 100).toStringAsFixed(1);
        _zeroRangeCtrl.text = persisted.zeroRangeM.toStringAsFixed(0);
        _clickUnit = persisted.clickUnit;
        _clickValueCtrl.text = persisted.clickValue.toString();
      } else if (_selectedWeapon != null) {
        _applyWeaponBallisticPreset(_selectedWeapon!);
      }
    });
  }

  Future<void> _loadReticleCatalog() async {
    final list = await ReticleCatalogLoader.load();
    if (!mounted) return;
    setState(() {
      _reticles = list;
      if (_selectedReticle == null && list.isNotEmpty) {
        final idx = list.indexWhere((e) => e.id.startsWith('ret_generic_extra_'));
        _selectedReticle = idx >= 0 ? list[idx] : list.first;
      }
    });
    await _reloadReticleQuickPrefs();
  }

  Future<void> _reloadReticleQuickPrefs() async {
    final recent = await ReticleUserPrefs.recentIds();
    final fav = await ReticleUserPrefs.favoriteIds();
    if (!mounted) return;
    setState(() {
      _recentReticleIds = recent;
      _favoriteReticleIds = fav;
    });
  }

  List<ReticleDefinition> _reticlesForQuickIds(List<String> ids) {
    if (ids.isEmpty || _reticles.isEmpty) return const [];
    final map = {for (final r in _reticles) r.id: r};
    return [for (final id in ids) if (map.containsKey(id)) map[id]!];
  }

  Future<void> _selectReticle(ReticleDefinition r) async {
    setState(() => _selectedReticle = r);
    await ReticleUserPrefs.recordUsed(r.id);
    await _reloadReticleQuickPrefs();
  }

  Future<void> _toggleReticleFavorite() async {
    final r = _selectedReticle;
    if (r == null) return;
    await ReticleUserPrefs.toggleFavorite(r.id);
    await _reloadReticleQuickPrefs();
  }

  List<ReticleDefinition> get _filteredReticles {
    final q = _reticleFilter.trim().toLowerCase();
    final List<ReticleDefinition> base;
    if (q.isEmpty) {
      base = _reticles.take(120).toList();
    } else {
      base = _reticles
          .where(
            (e) =>
                e.name.toLowerCase().contains(q) ||
                e.manufacturer.toLowerCase().contains(q) ||
                e.id.toLowerCase().contains(q),
          )
          .take(200)
          .toList();
    }
    final sel = _selectedReticle;
    if (sel != null && !base.any((e) => e.id == sel.id)) {
      final idx = _reticles.indexWhere((e) => e.id == sel.id);
      if (idx >= 0) return [_reticles[idx], ...base];
    }
    return base;
  }

  Widget _reticleQuickRow({
    required String title,
    required IconData icon,
    required List<ReticleDefinition> items,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
        const SizedBox(height: 6),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(width: 6),
            itemBuilder: (context, i) {
              final r = items[i];
              return ActionChip(
                avatar: Icon(icon, size: 16),
                label: Text(
                  r.manufacturer.isNotEmpty ? '${r.manufacturer} — ${r.name}' : r.name,
                  overflow: TextOverflow.ellipsis,
                ),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onPressed: () => _selectReticle(r),
              );
            },
          ),
        ),
      ],
    );
  }

  double _parse(String s) => double.parse(s.replaceAll(',', '.'));

  List<TempVelocityPair> _powderPairs() {
    final t1 = double.tryParse(_powderT1Ctrl.text.replaceAll(',', '.'));
    final v1 = double.tryParse(_powderV1Ctrl.text.replaceAll(',', '.'));
    final t2 = double.tryParse(_powderT2Ctrl.text.replaceAll(',', '.'));
    final v2 = double.tryParse(_powderV2Ctrl.text.replaceAll(',', '.'));
    if (t1 == null || v1 == null || t2 == null || v2 == null) return const [];
    if ((t2 - t1).abs() < 5.0) return const [];
    return [
      TempVelocityPair(tempC: t1, velocityMps: v1),
      TempVelocityPair(tempC: t2, velocityMps: v2),
    ];
  }

  double _crossWindMpsResolved() {
    if (_useMetWindVector) {
      final ws = double.tryParse(_windSpeedVecCtrl.text.replaceAll(',', '.')) ?? 0;
      final wf = double.tryParse(_windFromCtrl.text.replaceAll(',', '.')) ?? 0;
      final shot = double.tryParse(_shotAzCtrl.text.replaceAll(',', '.')) ?? 0;
      return crossWindMpsFromMetWind(
        windSpeedMps: ws,
        windFromNorthDeg: wf,
        shotAzimuthFromNorthDeg: shot,
      );
    }
    return double.tryParse(_crossWindCtrl.text.replaceAll(',', '.')) ?? 0;
  }

  BallisticsSolveInput _collectInput() {
    final daRaw = double.tryParse(_daCtrl.text.replaceAll(',', '.'));
    final bcSeg = parseBcMachSegments(_bcSegCtrl.text);
    final customDrag = parseCustomDragTable(_customDragCtrl.text);
    final customINodes = customDrag?.iNodes;
    return BallisticsSolveInput(
      distanceMeters: _parse(_distanceCtrl.text),
      muzzleVelocityMps: _parse(_mvCtrl.text),
      bcKind: _bcKind,
      ballisticCoefficient: _parse(_bcCtrl.text),
      temperatureC: _parse(_tempCtrl.text),
      pressureHpa: _parse(_pressureCtrl.text),
      relativeHumidityPercent: double.tryParse(_rhCtrl.text.replaceAll(',', '.')) ?? 0,
      densityAltitudeMeters: (daRaw != null && daRaw.abs() > 1e-6) ? daRaw : null,
      targetElevationDeltaMeters: _parse(_elevDeltaCtrl.text),
      slopeAngleDegrees: _parse(_slopeCtrl.text),
      sightHeightMeters: (double.tryParse(_sightHcmCtrl.text.replaceAll(',', '.')) ?? 3.8) / 100.0,
      zeroRangeMeters: double.tryParse(_zeroRangeCtrl.text.replaceAll(',', '.')) ?? 100,
      crossWindMps: _crossWindMpsResolved(),
      enableCoriolis: _coriolisOn,
      latitudeDegrees: double.tryParse(_latCtrl.text.replaceAll(',', '.')) ?? 0,
      azimuthFromNorthDegrees: double.tryParse(_shotAzCtrl.text.replaceAll(',', '.')) ?? 0,
      enableSpinDrift: _spinOn,
      riflingTwistSign: _twistRightHanded ? 1 : -1,
      bulletMassGrains: _spinOn ? double.tryParse(_grainCtrl.text.replaceAll(',', '.')) : null,
      bulletCaliberInches: _spinOn ? double.tryParse(_calInCtrl.text.replaceAll(',', '.')) : null,
      twistInchesPerTurn: _spinOn ? double.tryParse(_twistInCtrl.text.replaceAll(',', '.')) : null,
      enableAerodynamicJump: _jumpOn,
      clickUnit: _clickUnit,
      clickValue: _parse(_clickValueCtrl.text),
      powderTempVelocityPairs: _powderPairs(),
      powderTemperatureC: double.tryParse(_powderCurTCtrl.text.replaceAll(',', '.')),
      bcMachSegments: bcSeg,
      customDragMachNodes: customDrag?.machs,
      customDragI: customINodes,
      targetCrossTrackMps: double.tryParse(_targetCrossCtrl.text.replaceAll(',', '.')) ?? 0,
    );
  }

  void _solve() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _result = BallisticsEngine.solve(_collectInput()));
  }

  /// Üstteki forma göre atmosfer/mühimmat sabit; her kayıtlı menzil + Δh için bir çözüm.
  Future<void> _solveAllSavedTargetsDialog() async {
    if (_savedTargets.isEmpty) return;
    if (!_formKey.currentState!.validate()) return;
    final template = _collectInput();
    final rows = <(SavedTargetPreset, BallisticsSolveOutput)>[];
    for (final t in _savedTargets) {
      final input = template.withTargetGeometry(
        distanceMeters: t.distanceMeters,
        targetElevationDeltaMeters: t.elevationDeltaMeters,
      );
      rows.add((t, BallisticsEngine.solve(input)));
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kayıtlı hedefler — özet'),
        content: SizedBox(
          width: double.maxFinite,
          height: 380,
          child: Scrollbar(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  columnSpacing: 16,
                  columns: const [
                    DataColumn(label: Text('Hedef')),
                    DataColumn(label: Text('m')),
                    DataColumn(label: Text('Δh m')),
                    DataColumn(label: Text('Elev mil')),
                    DataColumn(label: Text('Wind mil')),
                    DataColumn(label: Text('LatΣ mil')),
                    DataColumn(label: Text('TOF ms')),
                  ],
                  rows: [
                    for (final (t, o) in rows)
                      DataRow(
                        cells: [
                          DataCell(Text(t.name)),
                          DataCell(Text(t.distanceMeters.toStringAsFixed(0))),
                          DataCell(Text(t.elevationDeltaMeters.toStringAsFixed(1))),
                          DataCell(Text(o.dropMil.toStringAsFixed(2))),
                          DataCell(Text(o.windMil.toStringAsFixed(2))),
                          DataCell(Text(o.combinedLateralMil.toStringAsFixed(2))),
                          DataCell(Text(o.timeOfFlightMs.toStringAsFixed(0))),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Kapat')),
        ],
      ),
    );
  }

  Future<void> _saveWeaponProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final prev = WeaponProfileStore.current.value;
    final bc = _parse(_bcCtrl.text);
    final profile = WeaponProfile(
      name: _weaponNameCtrl.text.trim().isEmpty ? 'Rifle-1' : _weaponNameCtrl.text.trim(),
      muzzleVelocityMps: _parse(_mvCtrl.text),
      ballisticCoefficientG1: _bcKind == BcKind.g1
          ? bc
          : (prev?.ballisticCoefficientG1 ?? estimateG1FromG7Rough(bc)),
      ballisticCoefficientG7: _bcKind == BcKind.g7 ? bc : prev?.ballisticCoefficientG7,
      bcKind: _bcKind,
      sightHeightM: (double.tryParse(_sightHcmCtrl.text.replaceAll(',', '.')) ?? 3.8) / 100.0,
      zeroRangeM: double.tryParse(_zeroRangeCtrl.text.replaceAll(',', '.')) ?? 100,
      clickUnit: _clickUnit,
      clickValue: _parse(_clickValueCtrl.text),
    );
    await WeaponProfileStore.save(profile);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Profil kaydedildi: ${profile.name}')),
    );
  }

  void _importFromMap() {
    final solution = TargetSolutionStore.current.value;
    if (solution == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maps sekmesinde «Balistiğe aktar» ile önce saha çözümünü kaydedin.'),
        ),
      );
      return;
    }
    setState(() {
      _distanceCtrl.text = solution.distanceMeters.toStringAsFixed(1);
      _elevDeltaCtrl.text = solution.elevationDeltaMeters.toStringAsFixed(1);
      _slopeCtrl.text = solution.slopeDegrees.toStringAsFixed(1);
      if (solution.shotAzimuthFromNorthDeg != null) {
        _shotAzCtrl.text = solution.shotAzimuthFromNorthDeg!.toStringAsFixed(1);
      }
      final ws = solution.windSpeedMps;
      if (ws != null && ws > 0) {
        _useMetWindVector = solution.windFromNorthDeg != null;
        if (_useMetWindVector) {
          _windSpeedVecCtrl.text = ws.toStringAsFixed(1);
          _windFromCtrl.text = solution.windFromNorthDeg!.toStringAsFixed(0);
        } else {
          final sign = solution.windCrossSignFromRight ?? 1;
          _crossWindCtrl.text = (sign * ws).toStringAsFixed(1);
        }
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_formKey.currentState?.validate() ?? false) {
        _solve();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Harita verisi işlendi; entegre motor ile hesaplandı.')),
        );
      }
    });
  }

  Future<void> _saveTargetPresetDialog() async {
    final nameCtrl = TextEditingController(text: 'Hedef ${_savedTargets.length + 1}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kayıtlı hedef'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Ad',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Kaydet')),
        ],
      ),
    );
    if (ok != true) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;
    final dm = double.tryParse(_distanceCtrl.text.replaceAll(',', '.'));
    final el = double.tryParse(_elevDeltaCtrl.text.replaceAll(',', '.'));
    if (dm == null) return;
    final preset = SavedTargetPreset(
      id: 'st_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      distanceMeters: dm,
      elevationDeltaMeters: el ?? 0,
    );
    final next = [..._savedTargets, preset];
    await SavedTargetsStore.save(next);
    if (!mounted) return;
    setState(() => _savedTargets = next);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kaydedildi: $name')));
  }

  double _reticleMagScale() {
    if (_reticleFfp) return 1.0;
    final r = double.tryParse(_refMagCtrl.text.replaceAll(',', '.')) ?? 10.0;
    final m = double.tryParse(_scopeMagCtrl.text.replaceAll(',', '.')) ?? 10.0;
    return r / (m <= 0 ? 10.0 : m);
  }

  Future<void> _truingDialog() async {
    final obsCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('BC doğrulama (truing)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Gözlemlediğiniz yükseliş düzeltmesini (mil) girin. Menzil, Vo ve atmosfer üstteki forma göre alınır.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: obsCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Gözlenen düşüş düzeltmesi (mil)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hesapla')),
        ],
      ),
    );
    if (ok != true) return;
    final obs = double.tryParse(obsCtrl.text.replaceAll(',', '.'));
    if (obs == null) return;
    if (!_formKey.currentState!.validate()) return;
    final bcNew = BallisticsEngine.trueBallisticCoefficientForObservedDrop(
      template: _collectInput(),
      observedDropMil: obs,
    );
    if (bcNew == null || !mounted) return;
    setState(() => _bcCtrl.text = bcNew.toStringAsFixed(4));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Önerilen ${_bcKind.label} BC: ${bcNew.toStringAsFixed(4)} (forma uygulandı)')),
    );
  }

  Future<void> _rangeTableDialog() async {
    if (!_formKey.currentState!.validate()) return;
    final start = int.tryParse(_tableStartCtrl.text) ?? 100;
    final end = int.tryParse(_tableEndCtrl.text) ?? 800;
    final step = int.tryParse(_tableStepCtrl.text) ?? 50;
    if (end < start || step <= 0) return;
    final rows = buildBallisticsRangeTable(
      template: _collectInput(),
      startMeters: start,
      endMeters: end,
      stepMeters: step,
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Menzil tablosu'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('m')),
                      DataColumn(label: Text('Elev')),
                      DataColumn(label: Text('Wind')),
                      DataColumn(label: Text('Lead')),
                      DataColumn(label: Text('LatΣ')),
                      DataColumn(label: Text('TOF')),
                    ],
                    rows: [
                      for (final r in rows)
                        DataRow(cells: [
                          DataCell(Text('${r.rangeMeters}')),
                          DataCell(Text(r.dropMil.toStringAsFixed(2))),
                          DataCell(Text(r.windMil.toStringAsFixed(2))),
                          DataCell(Text(r.leadMil.toStringAsFixed(2))),
                          DataCell(Text(r.combinedLateralMil.toStringAsFixed(2))),
                          DataCell(Text(r.tofMs.toStringAsFixed(0))),
                        ]),
                    ],
                  ),
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: () async {
                      final csv = rangeTableToCsv(rows);
                      await shareCsvText(csv, filename: 'blue_viper_range.csv');
                    },
                    child: const Text('CSV paylaş'),
                  ),
                  TextButton(
                    onPressed: () async {
                      await shareRangeTablePdf(
                        rows: rows,
                        title: 'Blue Viper Pro — Range table',
                        filename: 'blue_viper_range.pdf',
                      );
                    },
                    child: const Text('PDF paylaş'),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Kapat')),
        ],
      ),
    );
  }

  void _applyWeaponBallisticPreset(WeaponType w) {
    final p = ballisticPresetForWeapon(w);
    if (p == null) return;
    if (p.scopeCatalogId != null) {
      for (final s in _scopes) {
        if (s.id == p.scopeCatalogId) {
          _selectedScope = s;
          _clickUnit = s.clickUnit;
          _clickValueCtrl.text = s.clickValue.toString();
          break;
        }
      }
    }
    if (p.ammoCatalogId != null) {
      for (final a in _ammos) {
        if (a.id == p.ammoCatalogId) {
          _selectedAmmo = a;
          final v = p.ammoVariantId != null
              ? a.variantById(p.ammoVariantId!)
              : a.variants.first;
          _selectedAmmoVariantId = v.id;
          _applyBarrelVariant(v);
          return;
        }
      }
    }
    _mvCtrl.text = p.muzzleVelocityMps.toStringAsFixed(0);
    final bcText = _bcKind == BcKind.g7
        ? (p.ballisticCoefficientG7 ?? estimateG7FromG1(p.ballisticCoefficientG1))
        : p.ballisticCoefficientG1;
    _bcCtrl.text = bcText.toString();
  }

  void _onWeaponChanged(WeaponType? w) {
    setState(() {
      _selectedWeapon = w;
      if (w != null) {
        _weaponNameCtrl.text = '${w.name} (${w.caliber})';
        _applyWeaponBallisticPreset(w);
      }
    });
  }

  void _onScopeChanged(ScopeType? s) {
    setState(() {
      _selectedScope = s;
      if (s != null) {
        _clickUnit = s.clickUnit;
        _clickValueCtrl.text = s.clickValue.toString();
      }
    });
  }

  void _applyBarrelVariant(AmmoBarrelVariant v) {
    _mvCtrl.text = v.muzzleVelocityMps.toStringAsFixed(0);
    if (_bcKind == BcKind.g7) {
      final g7 = v.bcG7 ?? (v.bcG1 != null ? estimateG7FromG1(v.bcG1!) : null);
      _bcCtrl.text = g7 != null ? g7.toString() : '';
    } else {
      final bc = v.bcG1;
      _bcCtrl.text = bc != null ? bc.toString() : '';
    }
  }

  void _onAmmoChanged(AmmoType? a) {
    setState(() {
      _selectedAmmo = a;
      if (a != null) {
        final v = a.variants.first;
        _selectedAmmoVariantId = v.id;
        _applyBarrelVariant(v);
      } else {
        _selectedAmmoVariantId = null;
      }
    });
  }

  AmmoBarrelVariant? get _activeAmmoVariant {
    final a = _selectedAmmo;
    if (a == null) return null;
    final id = _selectedAmmoVariantId;
    if (id != null && a.variants.any((e) => e.id == id)) {
      return a.variantById(id);
    }
    return a.variants.first;
  }

  void _selectNearestBarrelInches(double inches) {
    final ammo = _selectedAmmo;
    if (ammo == null || ammo.variants.isEmpty) return;
    AmmoBarrelVariant best = ammo.variants.first;
    var bestDiff = ((best.barrelInches ?? inches) - inches).abs();
    for (final v in ammo.variants.skip(1)) {
      final diff = ((v.barrelInches ?? inches) - inches).abs();
      if (diff < bestDiff) {
        best = v;
        bestDiff = diff;
      }
    }
    _selectedAmmoVariantId = best.id;
    _applyBarrelVariant(best);
  }

  Future<void> _addWeaponDialog() async {
    final nameCtrl = TextEditingController();
    final calCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yeni silah ekle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Silah adı')),
            TextField(controller: calCtrl, decoration: const InputDecoration(labelText: 'Kalibre')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ekle')),
        ],
      ),
    );
    if (ok != true) return;
    final name = nameCtrl.text.trim();
    final cal = calCtrl.text.trim();
    if (name.isEmpty || cal.isEmpty) return;
    final item = WeaponType(
      id: 'user_weapon_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      caliber: cal,
    );
    final custom = _weapons.where((e) => e.id.startsWith('user_weapon_')).toList()..add(item);
    await UserCatalogStore.saveWeapons(custom);
    await _loadUserCatalog();
  }

  Future<void> _addScopeDialog() async {
    final nameCtrl = TextEditingController();
    final valueCtrl = TextEditingController(text: '0.1');
    ClickUnit unit = ClickUnit.mil;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Yeni dürbün ekle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Dürbün adı')),
              const SizedBox(height: 8),
              DropdownButtonFormField<ClickUnit>(
                key: ValueKey(unit),
                initialValue: unit,
                items: [for (final u in ClickUnit.values) DropdownMenuItem(value: u, child: Text(u.label))],
                onChanged: (v) => setLocal(() => unit = v ?? unit),
                decoration: const InputDecoration(labelText: 'Klik birimi', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: valueCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Klik değeri'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ekle')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final name = nameCtrl.text.trim();
    final val = double.tryParse(valueCtrl.text.replaceAll(',', '.'));
    if (name.isEmpty || val == null || val <= 0) return;
    final item = ScopeType(
      id: 'user_scope_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      clickUnit: unit,
      clickValue: val,
    );
    final custom = _scopes.where((e) => e.id.startsWith('user_scope_')).toList()..add(item);
    await UserCatalogStore.saveScopes(custom);
    await _loadUserCatalog();
  }

  Future<void> _addAmmoDialog() async {
    final nameCtrl = TextEditingController();
    final calCtrl = TextEditingController();
    final mv16Ctrl = TextEditingController(text: '750');
    final bc16Ctrl = TextEditingController(text: '0.45');
    final mv20Ctrl = TextEditingController(text: '790');
    final bc20Ctrl = TextEditingController(text: '0.45');
    final mv24Ctrl = TextEditingController(text: '825');
    final bc24Ctrl = TextEditingController(text: '0.45');
    final bc16g7Ctrl = TextEditingController();
    final bc20g7Ctrl = TextEditingController();
    final bc24g7Ctrl = TextEditingController();
    double? p(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.'));
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yeni mühimmat ekle'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Mühimmat adı')),
              TextField(controller: calCtrl, decoration: const InputDecoration(labelText: 'Kalibre')),
              const SizedBox(height: 8),
              const Text('3 namlu bandı (Vo m/s, G1 BC)'),
              TextField(
                controller: mv16Ctrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Kısa ~16" Vo (m/s)'),
              ),
              TextField(
                controller: bc16Ctrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Kısa G1 BC'),
              ),
              TextField(
                controller: mv20Ctrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Orta ~20" Vo (m/s)'),
              ),
              TextField(
                controller: bc20Ctrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Orta G1 BC'),
              ),
              TextField(
                controller: mv24Ctrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Uzun ~24" Vo (m/s)'),
              ),
              TextField(
                controller: bc24Ctrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Uzun G1 BC'),
              ),
              const SizedBox(height: 12),
              const Text('İsteğe bağlı G7 BC (lb/in²), boş bırakılabilir'),
              TextField(
                controller: bc16g7Ctrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Kısa G7 BC'),
              ),
              TextField(
                controller: bc20g7Ctrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Orta G7 BC'),
              ),
              TextField(
                controller: bc24g7Ctrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Uzun G7 BC'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ekle')),
        ],
      ),
    );
    if (ok != true) return;
    final name = nameCtrl.text.trim();
    final cal = calCtrl.text.trim();
    final mv16 = p(mv16Ctrl);
    final bc16 = p(bc16Ctrl);
    final mv20 = p(mv20Ctrl);
    final bc20 = p(bc20Ctrl);
    final mv24 = p(mv24Ctrl);
    final bc24 = p(bc24Ctrl);
    final g16 = p(bc16g7Ctrl);
    final g20 = p(bc20g7Ctrl);
    final g24 = p(bc24g7Ctrl);
    if (name.isEmpty ||
        cal.isEmpty ||
        mv16 == null ||
        mv16 <= 0 ||
        bc16 == null ||
        bc16 <= 0 ||
        mv20 == null ||
        mv20 <= 0 ||
        bc20 == null ||
        bc20 <= 0 ||
        mv24 == null ||
        mv24 <= 0 ||
        bc24 == null ||
        bc24 <= 0) {
      return;
    }
    final item = AmmoType(
      id: 'user_ammo_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      caliber: cal,
      variants: ammoVariantsThreeBarrels(
        mv16: mv16,
        bc16: bc16,
        mv20: mv20,
        bc20: bc20,
        mv24: mv24,
        bc24: bc24,
        bc16g7: g16,
        bc20g7: g20,
        bc24g7: g24,
      ),
    );
    final custom = _ammos.where((e) => e.id.startsWith('user_ammo_')).toList()..add(item);
    await UserCatalogStore.saveAmmos(custom);
    await _loadUserCatalog();
  }

  /// Strelok-benzeri saha balistik düzeni: gruplu kartlar, aynı motor ve formlar.
  Widget _strelokSection(BuildContext context, String title, List<Widget> children) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.85,
                          color: cs.primary,
                          fontSize: 12,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  List<Widget> _tabSolution(BuildContext context, SizedBox spacing) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return [
      Row(
        children: [
          Expanded(
            child: Text(
              'Atış çözümü',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 0.2),
            ),
          ),
          PopupMenuButton<void>(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (ctx) => [
              PopupMenuItem<void>(
                child: const Text('Harita çözümünü içe aktar'),
                onTap: () => Future<void>.delayed(
                  Duration.zero,
                  () {
                    if (context.mounted) _importFromMap();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
      const SizedBox(height: 6),
      Text(
        '${_weaponNameCtrl.text} · ${_selectedAmmo?.name ?? "—"} · Vo ${_mvCtrl.text} m/s · '
        'BC ${_bcCtrl.text} · ${_bcKind.label}',
        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant, height: 1.35),
      ),
      TextButton.icon(
        onPressed: () => setState(() => _tabController.index = 1),
        icon: const Icon(Icons.tune_rounded, size: 18),
        label: const Text('Silah / dürbün / mühimmat'),
      ),
      _strelokSection(context, 'MENZİL', [
        _numField(
          _distanceCtrl,
          'Menzil',
          suffix: 'm',
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800, fontSize: 22),
          textAlign: TextAlign.center,
        ),
        if (_savedTargets.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Kayıtlı', style: tt.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
              for (final t in _savedTargets)
                ActionChip(
                  label: Text('${t.name} ${t.distanceMeters.toStringAsFixed(0)} m'),
                  onPressed: () => setState(() {
                    _distanceCtrl.text = t.distanceMeters.toStringAsFixed(1);
                    _elevDeltaCtrl.text = t.elevationDeltaMeters.toStringAsFixed(1);
                  }),
                ),
              OutlinedButton.icon(
                onPressed: _solveAllSavedTargetsDialog,
                icon: const Icon(Icons.table_rows, size: 18),
                label: const Text('Tümünü hesapla'),
              ),
            ],
          ),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _saveTargetPresetDialog,
            icon: const Icon(Icons.bookmark_add_outlined, size: 18),
            label: const Text('Hedefi kaydet'),
          ),
        ),
      ]),
      _strelokSection(context, 'ORTAM', [
        _numField(_tempCtrl, 'Sıcaklık (ISA)', suffix: '°C'),
        const SizedBox(height: 8),
        _numField(_pressureCtrl, 'Basınç', suffix: 'hPa'),
        const SizedBox(height: 8),
        _numField(_rhCtrl, 'Göreli nem', suffix: '%'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _daCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Yoğunluk irtifa (opsiyonel, m)',
            helperText: 'Boş: P/T/nem; dolu: basınç ISA’dan türetilir',
          ),
        ),
        const SizedBox(height: 8),
        _numField(
          _elevDeltaCtrl,
          'Hedef rakım farkı (hedef−atıcı, +yukarı)',
          suffix: 'm',
        ),
        const SizedBox(height: 8),
        _numField(_slopeCtrl, 'Eğim açısı (Δh yoksa)', suffix: '°'),
      ]),
      _strelokSection(context, 'RÜZGÂR', [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Met rüzgâr vektörü'),
          subtitle: const Text('Hız + yön (kuzeyden °) + atış azimutu'),
          value: _useMetWindVector,
          onChanged: (v) => setState(() => _useMetWindVector = v),
        ),
        if (_useMetWindVector) ...[
          _numField(_windSpeedVecCtrl, 'Rüzgâr hızı', suffix: 'm/s'),
          const SizedBox(height: 8),
          _numField(_windFromCtrl, 'Rüzgâr (nereden, kuzey=0°)', suffix: '°'),
          const SizedBox(height: 8),
          _numField(_shotAzCtrl, 'Atış azimutu (kuzeyden)', suffix: '°'),
        ] else
          _numField(_crossWindCtrl, 'Yan rüzgâr (+ sağa iter)', suffix: 'm/s'),
      ]),
      _strelokSection(context, 'NİŞAN / KLİK', [
        Text(
          '${_sightHcmCtrl.text} cm · ${_zeroRangeCtrl.text} m · ${_clickUnit.label} ${_clickValueCtrl.text}',
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        TextButton(
          onPressed: () => setState(() => _tabController.index = 1),
          child: const Text('Nişan ve klik değerlerini düzenle'),
        ),
      ]),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: _solve,
            icon: const Icon(Icons.calculate_rounded),
            label: const Text('HESAPLA'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              textStyle: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.8),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _truingDialog,
                  icon: const Icon(Icons.auto_fix_high, size: 20),
                  label: const Text('Truing BC'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _rangeTableDialog,
                  icon: const Icon(Icons.table_rows, size: 20),
                  label: const Text('Tablo'),
                ),
              ),
            ],
          ),
        ],
      ),
      const SizedBox(height: 14),
      if (_result != null) ...[
        _StrelokHeroResult(
          result: _result!,
          clickUnit: _clickUnit,
          clickValue: _parse(_clickValueCtrl.text),
        ),
        spacing,
        ReticleHoldView(
          reticle: _selectedReticle,
          holdUpMil: _result!.dropMil,
          holdLeftMil: _result!.combinedLateralMil,
          holdUpMoa: _result!.dropMoa,
          holdLeftMoa: _result!.combinedLateralMoa,
          firstFocalPlane: _reticleFfp,
          scopeMagnification: double.tryParse(_scopeMagCtrl.text.replaceAll(',', '.')) ?? 10,
          referenceMag: double.tryParse(_refMagCtrl.text.replaceAll(',', '.')) ?? 10,
        ),
        spacing,
        Text('Retikül + foto hizalama', style: Theme.of(context).textTheme.titleSmall),
        spacing,
        ReticlePhotoSection(
          reticle: _selectedReticle,
          holdUpUnits: (_selectedReticle?.unit ?? 'mil') == 'moa'
              ? _result!.dropMoa * _reticleMagScale()
              : _result!.dropMil * _reticleMagScale(),
          holdLeftUnits: (_selectedReticle?.unit ?? 'mil') == 'moa'
              ? _result!.combinedLateralMoa * _reticleMagScale()
              : _result!.combinedLateralMil * _reticleMagScale(),
          unitIsMoa: (_selectedReticle?.unit ?? 'mil') == 'moa',
        ),
      ],
    ];
  }

  List<Widget> _tabProfile(BuildContext context, SizedBox spacing) {
    final tt = Theme.of(context).textTheme;
    return [
      Text(
        'Silah ve mühimmat',
        style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 6),
      Text(
        'Silah, dürbün ve kartuş seçimi; çıkış hızı, BC, nişan yüksekliği ve sıfır bu sekmede.',
        style: tt.bodySmall?.copyWith(height: 1.4),
      ),
      spacing,
      _strelokSection(context, 'SEÇİM', [
        DropdownButtonFormField<WeaponType>(
        key: ValueKey(_selectedWeapon?.id ?? 'weapon_null'),
        initialValue: _selectedWeapon,
        decoration: const InputDecoration(
          labelText: 'Silah çeşidi',
          border: OutlineInputBorder(),
        ),
        items: [
          for (final w in _weapons)
            DropdownMenuItem(
              value: w,
              child: Text('${w.name} - ${w.caliber}${w.role != null ? ' (${w.role})' : ''}'),
            ),
        ],
        onChanged: _onWeaponChanged,
      ),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerRight,
        child: OutlinedButton.icon(
          onPressed: _addWeaponDialog,
          icon: const Icon(Icons.add),
          label: const Text('Silah ekle'),
        ),
      ),
      const SizedBox(height: 10),
      DropdownButtonFormField<ScopeType>(
        key: ValueKey(_selectedScope?.id ?? 'scope_null'),
        initialValue: _selectedScope,
        decoration: const InputDecoration(labelText: 'Dürbün çeşidi', border: OutlineInputBorder()),
        items: [for (final s in _scopes) DropdownMenuItem(value: s, child: Text(s.name))],
        onChanged: _onScopeChanged,
      ),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerRight,
        child: OutlinedButton.icon(
          onPressed: _addScopeDialog,
          icon: const Icon(Icons.add),
          label: const Text('Dürbün ekle'),
        ),
      ),
      const SizedBox(height: 10),
      DropdownButtonFormField<AmmoType>(
        key: ValueKey(_selectedAmmo?.id ?? 'ammo_null'),
        initialValue: _selectedAmmo,
        decoration: const InputDecoration(labelText: 'Mühimmat çeşidi', border: OutlineInputBorder()),
        items: [
          for (final a in _ammos)
            DropdownMenuItem(value: a, child: Text('${a.name} (${a.caliber})')),
        ],
        onChanged: _onAmmoChanged,
      ),
      const SizedBox(height: 8),
      if (_selectedAmmo != null && _selectedAmmo!.variants.length > 1)
        DropdownButtonFormField<String>(
          key: ValueKey(
            '${_selectedAmmo!.id}_'
            '${_selectedAmmoVariantId != null && _selectedAmmo!.variants.any((e) => e.id == _selectedAmmoVariantId) ? _selectedAmmoVariantId! : _selectedAmmo!.variants.first.id}',
          ),
          initialValue: _selectedAmmoVariantId != null &&
                  _selectedAmmo!.variants.any((e) => e.id == _selectedAmmoVariantId)
              ? _selectedAmmoVariantId
              : _selectedAmmo!.variants.first.id,
          decoration: const InputDecoration(labelText: 'Namlu / Vo bandı', border: OutlineInputBorder()),
          items: [
            for (final v in _selectedAmmo!.variants)
              DropdownMenuItem(value: v.id, child: Text(v.label)),
          ],
          onChanged: (id) {
            if (id == null || _selectedAmmo == null) return;
            setState(() {
              _selectedAmmoVariantId = id;
              _applyBarrelVariant(_selectedAmmo!.variantById(id));
            });
          },
        ),
      if (_selectedAmmo != null && _selectedAmmo!.variants.length > 1) const SizedBox(height: 8),
      if (_selectedAmmo != null) ...[
        SegmentedButton<int>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment<int>(value: 16, label: Text('16"')),
            ButtonSegment<int>(value: 22, label: Text('22"')),
            ButtonSegment<int>(value: 24, label: Text('24"')),
          ],
          selected: {
            () {
              final b = _activeAmmoVariant?.barrelInches;
              if (b == null) return 22;
              if (b < 19) return 16;
              if (b < 23) return 22;
              return 24;
            }(),
          },
          onSelectionChanged: (s) {
            final targetInches = s.first.toDouble();
            setState(() => _selectNearestBarrelInches(targetInches));
          },
        ),
        const SizedBox(height: 4),
        Text(
          'Önerilen namlu bandı otomatik dolabilir; bu seçim her zaman elle değiştirilebilir.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
      ],
      Align(
        alignment: Alignment.centerRight,
        child: OutlinedButton.icon(
          onPressed: _addAmmoDialog,
          icon: const Icon(Icons.add),
          label: const Text('Mühimmat ekle'),
        ),
      ),
      ]),
      _strelokSection(context, 'MÜHİMMAT', [
      _numField(_weaponNameCtrl, 'Silah adı', numeric: false),
      const SizedBox(height: 8),
      DropdownButtonFormField<BcKind>(
        key: ValueKey(_bcKind),
        initialValue: _bcKind,
        decoration: const InputDecoration(labelText: 'BC modeli', border: OutlineInputBorder()),
        items: [for (final b in BcKind.values) DropdownMenuItem(value: b, child: Text(b.label))],
        onChanged: (v) {
          setState(() {
            _bcKind = v ?? _bcKind;
            final v0 = _activeAmmoVariant;
            if (v0 != null) _applyBarrelVariant(v0);
          });
        },
      ),
      const SizedBox(height: 8),
      _numField(_mvCtrl, 'Çıkış hızı (m/s - tablo öncesi)', suffix: 'm/s'),
      const SizedBox(height: 8),
      _bcFormField(),
      ]),
      _strelokSection(context, 'NİŞAN HATTI', [
      _numField(_sightHcmCtrl, 'Dürbün ekseni yüksekliği (sight height)', suffix: 'cm'),
      const SizedBox(height: 8),
      _numField(_zeroRangeCtrl, 'Sıfırlama menzili', suffix: 'm'),
      ]),
      _strelokSection(context, 'BARUT SICAKLIĞI → Vo', [
      Row(
        children: [
          Expanded(child: _looseField(_powderT1Ctrl, 'T₁ °C')),
          const SizedBox(width: 8),
          Expanded(child: _looseField(_powderV1Ctrl, 'V₁ m/s')),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(child: _looseField(_powderT2Ctrl, 'T₂ °C')),
          const SizedBox(width: 8),
          Expanded(child: _looseField(_powderV2Ctrl, 'V₂ m/s')),
        ],
      ),
      const SizedBox(height: 8),
      _looseField(_powderCurTCtrl, 'Şu an barut sıcaklığı °C (boş: hava sıcaklığı)'),
      ]),
      _strelokSection(context, 'OPTİK / KLİK', [
      DropdownButtonFormField<ClickUnit>(
        key: ValueKey(_clickUnit),
        initialValue: _clickUnit,
        items: [for (final u in ClickUnit.values) DropdownMenuItem(value: u, child: Text(u.label))],
        onChanged: (v) => setState(() => _clickUnit = v ?? _clickUnit),
        decoration: const InputDecoration(labelText: 'Klik birimi', border: OutlineInputBorder()),
      ),
      const SizedBox(height: 8),
      _numField(_clickValueCtrl, 'Klik değeri'),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: _saveWeaponProfile,
        icon: const Icon(Icons.save_outlined),
        label: const Text('Profili kaydet'),
      ),
      ]),
    ];
  }

  List<Widget> _tabAdvanced(BuildContext context, SizedBox spacing) {
    final tt = Theme.of(context).textTheme;
    return [
      Text(
        'Ek fizik ve sürüklenme',
        style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 6),
      Text(
        'Coriolis, spin, jump ve parçalı BC — aynı hesap motoru.',
        style: tt.bodySmall?.copyWith(height: 1.4),
      ),
      spacing,
      _strelokSection(context, 'BALİSTİK EKLER', [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Coriolis'),
        value: _coriolisOn,
        onChanged: (v) => setState(() => _coriolisOn = v),
      ),
      if (_coriolisOn) _numField(_latCtrl, 'Enlem (+ kuzey)', suffix: '°'),
      if (_coriolisOn) spacing,
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Spin drift (Miller kabaca)'),
        value: _spinOn,
        onChanged: (v) => setState(() => _spinOn = v),
      ),
      if (_spinOn) ...[
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Sağ el twist'),
          value: _twistRightHanded,
          onChanged: (v) => setState(() => _twistRightHanded = v),
        ),
        _numField(_grainCtrl, 'Mermi ağırlığı', suffix: 'gr'),
        spacing,
        _numField(_calInCtrl, 'Kalibre', suffix: 'in'),
        spacing,
        _numField(_twistInCtrl, 'Bir tur (namlu)', suffix: 'in'),
      ],
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Aerodynamic jump (yan rüzgârla dikey)'),
        value: _jumpOn,
        onChanged: (v) => setState(() => _jumpOn = v),
      ),
      ExpansionTile(
        title: const Text('Gelişmiş sürüklenme ve hareketli hedef'),
        subtitle: const Text('Parçalı BC, özel i(Mach), hedef çapraz hız'),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextFormField(
              controller: _bcSegCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Parçalı BC (Mach, BC — satır başına)',
                helperText: 'Örn: 3.0,0.28 / 1.2,0.25 / 0.0,0.22 — en az 2 satır',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          TextFormField(
            controller: _customDragCtrl,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Özel i(Mach) tablosu (Mach, i — G1 biçimi)',
              helperText: 'Doluysa G1/G7 standart eğrisi yerine kullanılır; BC alanı ölçek içindir',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _targetCrossCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Hedef çapraz hız (+ sağa, m/s)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      ]),
    ];
  }

  List<Widget> _tabReticle(BuildContext context, SizedBox spacing) {
    final tt = Theme.of(context).textTheme;
    return [
      Text('Retikül kütüphanesi', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      Text(
        'Düzen seçin; FFP/SFP ve büyütme değerleri tutmayı etkiler.',
        style: tt.bodySmall?.copyWith(height: 1.4),
      ),
      spacing,
      _strelokSection(context, 'RETİKÜL', [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              'Kütüphane (${_reticles.length} düzen)',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            tooltip: _selectedReticle != null && _favoriteReticleIds.contains(_selectedReticle!.id)
                ? 'Favorilerden çıkar'
                : 'Favorilere ekle',
            onPressed: _reticles.isEmpty || _selectedReticle == null ? null : _toggleReticleFavorite,
            icon: Icon(
              _selectedReticle != null && _favoriteReticleIds.contains(_selectedReticle!.id)
                  ? Icons.star
                  : Icons.star_border,
            ),
          ),
        ],
      ),
      spacing,
      TextField(
        controller: _reticleSearchCtrl,
        decoration: const InputDecoration(
          labelText: 'Retikül ara (ad, üretici, id)',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.search),
        ),
        onChanged: (v) => setState(() => _reticleFilter = v),
      ),
      if (_reticles.isNotEmpty) ...[
        spacing,
        _reticleQuickRow(
          title: 'Favoriler',
          icon: Icons.star,
          items: _reticlesForQuickIds(_favoriteReticleIds),
        ),
        spacing,
        _reticleQuickRow(
          title: 'Son kullanılan',
          icon: Icons.history,
          items: _reticlesForQuickIds(_recentReticleIds),
        ),
      ],
      spacing,
      if (_reticles.isEmpty)
        const Text('Katalog yüklenemedi veya boş (assets/reticles/reticle_catalog.json).')
      else if (_filteredReticles.isEmpty)
        const Text('Arama sonucu yok; filtreyi temizleyin.')
      else
        DropdownButtonFormField<ReticleDefinition>(
          key: ValueKey(
            _selectedReticle != null && _filteredReticles.any((e) => e.id == _selectedReticle!.id)
                ? _selectedReticle!.id
                : _filteredReticles.first.id,
          ),
          initialValue: _selectedReticle != null && _filteredReticles.any((e) => e.id == _selectedReticle!.id)
              ? _filteredReticles.firstWhere((e) => e.id == _selectedReticle!.id)
              : _filteredReticles.first,
          decoration: const InputDecoration(
            labelText: 'Retikül düzeni',
            border: OutlineInputBorder(),
          ),
          isExpanded: true,
          items: [
            for (final r in _filteredReticles)
              DropdownMenuItem(
                value: r,
                child: Text(
                  '${r.manufacturer.isNotEmpty ? '${r.manufacturer} — ' : ''}${r.name}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (v) async {
            if (v == null) return;
            await _selectReticle(v);
          },
        ),
      spacing,
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('İlk odak düzlemi (FFP)'),
        subtitle: Text(
          _selectedReticle?.defaultFfp == false
              ? 'Bu düzen için SFP yaygın; büyütmeyi girin.'
              : 'FFP: subtension her büyütmede aynı.',
        ),
        value: _reticleFfp,
        onChanged: (v) => setState(() => _reticleFfp = v),
      ),
      if (!_reticleFfp) ...[
        _numField(_scopeMagCtrl, 'Güncel büyütme', suffix: '×'),
        spacing,
        _numField(_refMagCtrl, 'Referans büyütme (subtension)', suffix: '×'),
      ],
      const Divider(height: 24),
      const Text('Menzil tablosu aralığı', style: TextStyle(fontWeight: FontWeight.bold)),
      spacing,
      Row(
        children: [
          Expanded(child: _numField(_tableStartCtrl, 'Başlangıç', suffix: 'm')),
          const SizedBox(width: 8),
          Expanded(child: _numField(_tableEndCtrl, 'Bitiş', suffix: 'm')),
          const SizedBox(width: 8),
          Expanded(child: _numField(_tableStepCtrl, 'Adım', suffix: 'm')),
        ],
      ),
      spacing,
      Text(
        'Tutma önizlemesi ve hesap «Çözüm» sekmesinde, «HESAPLA» ile güncellenir.',
        style: tt.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      ]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    const spacing = SizedBox(height: 12);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final localTheme = theme.copyWith(
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: cs.surfaceContainerHigh.withValues(alpha: 0.72),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
      ),
    );
    return Theme(
      data: localTheme,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              elevation: 2,
              shadowColor: Colors.black45,
              color: cs.surfaceContainerHighest.withValues(alpha: 0.75),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: cs.primary,
                indicatorWeight: 3,
                labelColor: cs.primary,
                unselectedLabelColor: cs.onSurfaceVariant,
                labelStyle: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 0.15,
                ),
                unselectedLabelStyle: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                tabs: const [
                  Tab(icon: Icon(Icons.center_focus_strong, size: 20), text: 'Çözüm'),
                  Tab(icon: Icon(Icons.shield_outlined, size: 20), text: 'Silah'),
                  Tab(icon: Icon(Icons.tune, size: 20), text: 'Ek'),
                  Tab(icon: Icon(Icons.grid_4x4_outlined, size: 20), text: 'Retikül'),
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _tabController.index,
                children: [
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: _tabSolution(context, spacing),
                  ),
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: _tabProfile(context, spacing),
                  ),
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: _tabAdvanced(context, spacing),
                  ),
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: _tabReticle(context, spacing),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _looseField(TextEditingController c, String label) {
    return TextFormField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      validator: (_) => null,
    );
  }

  Widget _numField(
    TextEditingController c,
    String label, {
    String? suffix,
    bool numeric = true,
    TextStyle? style,
    TextAlign textAlign = TextAlign.start,
  }) {
    return TextFormField(
      controller: c,
      style: style,
      textAlign: textAlign,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return 'Boş olamaz';
        if (numeric) {
          final v = double.tryParse(value.replaceAll(',', '.'));
          if (v == null) return 'Sayı gir';
        }
        return null;
      },
    );
  }

  Widget _bcFormField() {
    final v = _activeAmmoVariant;
    final needsUserBc = v != null &&
        (_bcKind == BcKind.g7 ? (v.bcG7 == null && v.bcG1 == null) : v.bcG1 == null);
    return TextFormField(
      controller: _bcCtrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: 'Balistik katsayı (${_bcKind == BcKind.g7 ? 'G7' : 'G1'} BC, lb/in²)',
        helperText: needsUserBc ? 'Katalogda BC yoksa datasheet girin (G7 için bcG7 alanı).' : null,
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return needsUserBc ? 'BC girin' : 'Boş olamaz';
        }
        final parsed = double.tryParse(value.replaceAll(',', '.'));
        if (parsed == null) return 'Sayı gir';
        if (parsed <= 0) return 'Pozitif BC girin';
        return null;
      },
    );
  }
}

/// Saha balistik uygulamalarına benzer büyük rakamlı özet + ayrıntı ızgarası.
class _StrelokHeroResult extends StatelessWidget {
  final BallisticsSolveOutput result;
  final ClickUnit clickUnit;
  final double clickValue;

  const _StrelokHeroResult({
    required this.result,
    required this.clickUnit,
    required this.clickValue,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    Widget heroCol(String title, String primary, String unitLine) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              title,
              style: tt.labelSmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 0.9,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              primary,
              textAlign: TextAlign.center,
              style: tt.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                fontSize: 26,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              unitLine,
              textAlign: TextAlign.center,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    Widget detailRow(String k, String v) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Text(k, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            ),
            Expanded(
              flex: 4,
              child: Text(
                v,
                textAlign: TextAlign.end,
                style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.surfaceContainerHighest.withValues(alpha: 0.95),
            const Color(0xFF121814),
          ],
        ),
        border: Border.all(color: cs.primary.withValues(alpha: 0.42)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'SONUÇ',
              style: tt.labelMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                heroCol(
                  'DÜŞÜŞ',
                  result.dropMil.toStringAsFixed(2),
                  '${result.dropMoa.toStringAsFixed(2)} MOA',
                ),
                Container(
                  width: 1,
                  height: 72,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  color: cs.outlineVariant.withValues(alpha: 0.6),
                ),
                heroCol(
                  'YANAL',
                  result.windMil.toStringAsFixed(2),
                  '${result.windMoa.toStringAsFixed(2)} MOA',
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Öncü ${result.leadMil.toStringAsFixed(2)} mil · Toplam yatay ${result.combinedLateralMil.toStringAsFixed(2)} mil',
              textAlign: TextAlign.center,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const Divider(height: 20),
            detailRow('Klik (düşüş)', '${result.clicks.toStringAsFixed(1)} ($clickValue ${clickUnit.label})'),
            detailRow('Klik (yan saf)', '${result.windClicks.toStringAsFixed(1)} ($clickValue ${clickUnit.label})'),
            detailRow('Klik (öncü)', '${result.leadClicks.toStringAsFixed(1)} ($clickValue ${clickUnit.label})'),
            detailRow('Klik (yatay top.)', '${result.combinedLateralClicks.toStringAsFixed(1)} ($clickValue ${clickUnit.label})'),
            detailRow('Vo (kullanılan)', '${result.adjustedMuzzleVelocityMps.toStringAsFixed(1)} m/s'),
            detailRow('TOF', '${result.timeOfFlightMs.toStringAsFixed(0)} ms'),
          ],
        ),
      ),
    );
  }
}
