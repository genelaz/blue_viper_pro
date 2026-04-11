import 'dart:async' show StreamSubscription, TimeoutException, Timer, unawaited;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/ballistics/ballistic_compare_ref_store.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/ballistics/ballistics_corrections.dart';
import '../../../core/ballistics/ballistics_engine.dart';
import '../../../core/ballistics/ballistics_export.dart';
import '../../../core/ballistics/ballistics_range_prefs.dart';
import '../../../core/ballistics/ballistics_range_ui.dart';
import '../../../core/ballistics/ballistics_output_convention.dart';
import '../../../core/ballistics/click_units.dart';
import '../../../core/ballistics/bc_g7_estimate.dart';
import '../../../core/ballistics/bc_kind.dart';
import '../../../core/ballistics/bc_mach_segment.dart';
import '../../../core/ballistics/custom_drag_table.dart';
import '../../../core/ballistics/powder_temperature.dart';
import '../../../core/ballistics/wind_geometry.dart';
import '../../../core/bluetooth/ballistics_env_bridge.dart';
import '../../../core/catalog/ballistic_preset_repository.dart';
import '../../../core/catalog/ballistic_preset_updater.dart';
import '../../../core/catalog/catalog_data.dart';
import '../../../core/catalog/catalog_strelock_extra.dart';
import '../../../core/catalog/catalog_loader.dart';
import '../../../core/catalog/user_catalog_store.dart';
import '../../../core/catalog/weapon_ballistic_presets.dart';
import '../../../core/geo/open_meteo_ballistics_weather.dart';
import '../../../core/geo/saved_targets_store.dart';
import '../../../core/geo/target_solution_store.dart';
import '../../../core/profile/shot_scene_preset.dart';
import '../../../core/profile/weapon_profile_store.dart';
import '../../../core/reticles/reticle_catalog_loader.dart';
import '../../../core/reticles/reticle_definition.dart';
import '../../../core/reticles/reticle_user_prefs.dart';
import '../../../core/reticles/scope_reticle_map.dart';
import '../../../features/bluetooth/presentation/ble_hub_page.dart';
import 'ballistics_converters_page.dart';
import 'ballistics_extra_data_page.dart';
import 'ballistics_unit_converters_page.dart';
import 'manual_scope_entry_page.dart';
import 'manual_weapon_entry_page.dart';
import 'moving_target_page.dart';
import 'range_table_page.dart';
import 'reticle_hold_view.dart';
import 'reticle_photo_section.dart';
import 'strelock_ballistics_ui.dart';
import 'trajectory_validation_page.dart';

enum _TempUnit { c, f }

enum _PressureUnit { hpa, inHg, mmHg, psi }

enum _LengthUnit { m, ft }

enum _SlopeUnit { deg, percent, cos }

class BallisticsPage extends StatefulWidget {
  const BallisticsPage({super.key});

  @override
  State<BallisticsPage> createState() => _BallisticsPageState();
}

class _BallisticsPageState extends State<BallisticsPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final _distanceCtrl = TextEditingController(
    text: '${BallisticsRangeUi.defaultPrimaryDistanceM}',
  );
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
  final _barrelInchesCtrl = TextEditingController();
  final _tableStartCtrl = TextEditingController(
    text: '${BallisticsRangeUi.defaultTableStartM}',
  );
  final _tableEndCtrl = TextEditingController(
    text: '${BallisticsRangeUi.defaultTableEndM}',
  );
  final _tableStepCtrl = TextEditingController(
    text: '${BallisticsRangeUi.defaultTableStepM}',
  );
  /// Son kullanılan toplu menzil CSV (diyalog varsayılanı); [BallisticsRangePrefs] ile saklanır.
  String _lastBatchRangesCsv = BallisticsRangeUi.defaultBatchRangesCsv;
  Timer? _ballisticsRangePrefsSaveTimer;
  bool _ballisticsRangePrefsHydrated = false;
  final _reticleSearchCtrl = TextEditingController();
  final _bcSegCtrl = TextEditingController();
  final _customDragCtrl = TextEditingController();
  final _targetCrossCtrl = TextEditingController(text: '0');
  final _weaponNotesCtrl = TextEditingController();
  final _bulletLenInCtrl = TextEditingController();
  final _zeroElevCompCtrl = TextEditingController();
  final _zeroWindCompCtrl = TextEditingController();
  final _zeroAtmoTempCtrl = TextEditingController();
  final _zeroAtmoPresCtrl = TextEditingController();
  final _zeroAtmoRhCtrl = TextEditingController();
  final _zeroPowderTCtrl = TextEditingController();

  final _clickValueCtrl = TextEditingController(text: '0.1');

  ClickUnit _clickUnit = ClickUnit.mil;
  BcKind _bcKind = BcKind.g1;
  _TempUnit _tempUnit = _TempUnit.c;
  _PressureUnit _pressureUnit = _PressureUnit.hpa;
  _LengthUnit _heightUnit = _LengthUnit.m;
  _SlopeUnit _slopeUnit = _SlopeUnit.deg;
  bool _coriolisOn = false;
  bool _spinOn = false;
  bool _jumpOn = false;
  bool _twistRightHanded = true;
  bool _useMetWindVector = false;
  bool _reticleFfp = true;

  AngularMilConvention _angularMilConvention = AngularMilConvention.linear;
  MoaDisplayConvention _moaDisplayConvention = MoaDisplayConvention.legacyFromMil;
  bool _invertCrossWindSign = false;
  bool _energyFtLbf = false;
  bool _useInternalBarometer = false;
  StreamSubscription<BarometerEvent>? _barometerSub;

  WeaponType? _selectedWeapon;
  ScopeType? _selectedScope;
  AmmoType? _selectedAmmo;
  String? _selectedAmmoVariantId;

  /// Katalog namlu bandı Vo’yu ezmesin; saha kronometre değeri korunur (profilde saklanır).
  bool _chronoVoLocked = false;
  List<WeaponType> _weapons = CatalogData.weapons;
  List<ScopeType> _scopes = CatalogData.scopes;
  List<AmmoType> _ammos = CatalogData.ammos;
  bool _isUpdatingRemotePresets = false;
  String _activePresetVersion = 'builtin-v1';
  String _activePresetSource = 'bundled';
  BallisticPresetManifest? _previousPresetManifest;
  Map<String, WeaponBallisticPreset> _weaponPresetMap =
      Map<String, WeaponBallisticPreset>.from(weaponBallisticPresets);
  Map<String, WeaponBallisticPreset> _caliberFallbackPresetMap =
      Map<String, WeaponBallisticPreset>.from(caliberFallbackPresets);

  List<ReticleDefinition> _reticles = [];
  ReticleDefinition? _selectedReticle;
  String _reticleFilter = '';
  List<String> _recentReticleIds = [];
  List<String> _favoriteReticleIds = [];

  BallisticsSolveOutput? _result;

  List<SavedTargetPreset> _savedTargets = [];

  /// Aynı atış koşullarında iki balistik profili karşılaştırmak için yakalanan girdi.
  BallisticsSolveInput? _profileCompareRef;
  String _profileCompareSummary = '';

  /// Dürbün seçilince katalogdan markaya uygun parametrik retikül öner.
  bool _autoReticleFromScope = true;

  /// [WeaponProfileBookStore] satiri; bos ise «Profili kaydet» yeni wp_... id uretir.
  String? _activeBookProfileId;

  /// Aciksa defter filtresi kaldirilir (tum katalog silahlari icin kayitlar).
  bool _showAllWeaponBookEntries = false;

  /// [ShotScenePresetBookStore] — ortam / rüzgâr / barut eğrisi.
  String? _activeScenePresetId;
  bool _showAllSceneBookEntries = false;

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
    WeaponProfileBookStore.entries.addListener(_onBookEntriesChanged);
    ShotScenePresetBookStore.current.addListener(_onShotSceneChanged);
    ShotScenePresetBookStore.entries.addListener(_onSceneBookEntriesChanged);
    BallisticsEnvBridge.pending.addListener(_applyBleEnvToForm);
    _loadUserCatalog();
    _loadReticleCatalog();
    SavedTargetsStore.load().then((list) {
      if (mounted) setState(() => _savedTargets = list);
    });
    _distanceCtrl.addListener(_onBallisticsRangePrefsFieldChanged);
    _tableStartCtrl.addListener(_onBallisticsRangePrefsFieldChanged);
    _tableEndCtrl.addListener(_onBallisticsRangePrefsFieldChanged);
    _tableStepCtrl.addListener(_onBallisticsRangePrefsFieldChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyPersistedProfileToForm();
      _applyBleEnvToForm();
      unawaited(_loadPersistedCompareRef());
      unawaited(_loadBallisticsDisplayPrefs());
      unawaited(_loadBallisticsRangePrefs());
    });
  }

  void _onBallisticsRangePrefsFieldChanged() {
    if (!_ballisticsRangePrefsHydrated) return;
    _ballisticsRangePrefsSaveTimer?.cancel();
    _ballisticsRangePrefsSaveTimer = Timer(const Duration(milliseconds: 700), () {
      _ballisticsRangePrefsSaveTimer = null;
      unawaited(
        BallisticsRangePrefs.save(
          primaryText: _distanceCtrl.text,
          tableStartText: _tableStartCtrl.text,
          tableEndText: _tableEndCtrl.text,
          tableStepText: _tableStepCtrl.text,
          batchCsv: _lastBatchRangesCsv,
        ),
      );
    });
  }

  Future<void> _loadBallisticsRangePrefs() async {
    final data = await BallisticsRangePrefs.load();
    if (!mounted) return;
    setState(() {
      _distanceCtrl.text = BallisticsRangePrefs.formatPrimaryField(data.primaryDistanceM);
      _tableStartCtrl.text = '${data.tableStartM}';
      _tableEndCtrl.text = '${data.tableEndM}';
      _tableStepCtrl.text = '${data.tableStepM}';
      _lastBatchRangesCsv = data.lastBatchRangesCsv;
    });
    _ballisticsRangePrefsHydrated = true;
  }

  Future<void> _flushBallisticsRangePrefs() async {
    await BallisticsRangePrefs.save(
      primaryText: _distanceCtrl.text,
      tableStartText: _tableStartCtrl.text,
      tableEndText: _tableEndCtrl.text,
      tableStepText: _tableStepCtrl.text,
      batchCsv: _lastBatchRangesCsv,
    );
  }

  Future<void> _loadBallisticsDisplayPrefs() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    AngularMilConvention am = AngularMilConvention.linear;
    final ams = p.getString('ballistics_angular_mil_v1');
    if (ams != null) {
      try {
        am = AngularMilConvention.values.byName(ams);
      } catch (_) {}
    }
    MoaDisplayConvention mo = MoaDisplayConvention.legacyFromMil;
    final mos = p.getString('ballistics_moa_display_v1');
    if (mos != null) {
      try {
        mo = MoaDisplayConvention.values.byName(mos);
      } catch (_) {}
    }
    final inv = p.getBool('ballistics_invert_cross_wind_v1') ?? false;
    final eft = p.getBool('ballistics_energy_ft_lbf_v1') ?? false;
    final baro = p.getBool('ballistics_internal_barometer_v1') ?? false;
    setState(() {
      _angularMilConvention = am;
      _moaDisplayConvention = mo;
      _invertCrossWindSign = inv;
      _energyFtLbf = eft;
      _useInternalBarometer = baro;
    });
    if (baro) {
      unawaited(_setInternalBarometer(true));
    }
  }

  Future<void> _persistBallisticsDisplayPrefs() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('ballistics_angular_mil_v1', _angularMilConvention.name);
    await p.setString('ballistics_moa_display_v1', _moaDisplayConvention.name);
    await p.setBool('ballistics_invert_cross_wind_v1', _invertCrossWindSign);
    await p.setBool('ballistics_energy_ft_lbf_v1', _energyFtLbf);
    await p.setBool('ballistics_internal_barometer_v1', _useInternalBarometer);
  }

  Future<void> _setInternalBarometer(bool on) async {
    await _barometerSub?.cancel();
    _barometerSub = null;
    if (!on) {
      if (mounted) setState(() => _useInternalBarometer = false);
      await _persistBallisticsDisplayPrefs();
      return;
    }
    var ok = false;
    try {
      await barometerEventStream(
        samplingPeriod: SensorInterval.normalInterval,
      ).first.timeout(const Duration(seconds: 2));
      ok = true;
    } on TimeoutException {
      ok = false;
    } on Object {
      ok = false;
    }
    if (!ok) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('ballistics_internal_barometer_v1', false);
      if (!mounted) return;
      setState(() => _useInternalBarometer = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu cihazda basınç sensörü yok veya kullanılamıyor.')),
      );
      return;
    }
    if (mounted) setState(() => _useInternalBarometer = true);
    await _persistBallisticsDisplayPrefs();
    _pressureUnit = _PressureUnit.hpa;
    _barometerSub = barometerEventStream(
      samplingPeriod: SensorInterval.normalInterval,
    ).listen((e) {
      if (!mounted) return;
      setState(() {
        _pressureCtrl.text = e.pressure.toStringAsFixed(1);
      });
    });
  }

  Future<void> _applyMeteoToForm() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Konum izni gerekli (METEO).')),
      );
      return;
    }
    final pos = await Geolocator.getCurrentPosition();
    final wx = await fetchOpenMeteoCurrent(
      latitudeDeg: pos.latitude,
      longitudeDeg: pos.longitude,
    );
    if (!mounted) return;
    if (wx == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Open-Meteo yanıtı alınamadı.')),
      );
      return;
    }
    setState(() {
      _tempUnit = _TempUnit.c;
      _tempCtrl.text = wx.temperatureC.toStringAsFixed(1);
      _pressureUnit = _PressureUnit.hpa;
      _pressureCtrl.text = wx.pressureHpa.toStringAsFixed(1);
      _rhCtrl.text = wx.relativeHumidityPercent.toStringAsFixed(0);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('METEO: sıcaklık / basınç / nem forma yazıldı.')),
    );
  }

  String _formatCompareRefSummary(BallisticsSolveInput snap) {
    final bcLabel = snap.bcKind == BcKind.g7 ? 'G7' : 'G1';
    return '$bcLabel ${snap.ballisticCoefficient.toStringAsFixed(3)} · '
        '${snap.muzzleVelocityMps.toStringAsFixed(0)} m/s';
  }

  String _serializeBcMachSegments(List<BcMachSegment> segs) {
    if (segs.isEmpty) return '';
    final copy = [...segs]..sort((a, b) => b.machMin.compareTo(a.machMin));
    return copy.map((e) => '${e.machMin},${e.bc}').join('\n');
  }

  String _serializeCustomDragMachINodes(List<double> machs, List<double> iNodes) {
    if (machs.isEmpty || machs.length != iNodes.length) return '';
    final b = StringBuffer();
    for (var k = 0; k < machs.length; k++) {
      if (k > 0) b.writeln();
      b.write('${machs[k]},${iNodes[k]}');
    }
    return b.toString();
  }

  double _cToTempDisplay(double c) =>
      _tempUnit == _TempUnit.c ? c : c * 9.0 / 5.0 + 32.0;

  double _hpaToPressureDisplay(double hpa) {
    switch (_pressureUnit) {
      case _PressureUnit.hpa:
        return hpa;
      case _PressureUnit.inHg:
        return hpa / 33.8638866667;
      case _PressureUnit.mmHg:
        return hpa / 1.33322;
      case _PressureUnit.psi:
        return hpa / 68.9475729328;
    }
  }

  double _metersToLengthDisplay(double m) =>
      _heightUnit == _LengthUnit.m ? m : m / 0.3048;

  double _degreesToSlopeDisplay(double deg) {
    switch (_slopeUnit) {
      case _SlopeUnit.deg:
        return deg;
      case _SlopeUnit.percent:
        return math.tan(deg * math.pi / 180.0) * 100.0;
      case _SlopeUnit.cos:
        return math.cos(deg * math.pi / 180.0);
    }
  }

  /// Kayıtlı karşılaştırma referansındaki çözüm girdilerini forma yazar; katalog silah/dürbün/mühimmat seçimi değişmez.
  void _applySolveInputCoreToForm(BallisticsSolveInput i) {
    _distanceCtrl.text = i.distanceMeters.toStringAsFixed(0);
    _mvCtrl.text = i.muzzleVelocityMps.toStringAsFixed(0);
    _bcKind = i.bcKind;
    _bcCtrl.text = i.ballisticCoefficient.toStringAsFixed(3);
    _tempCtrl.text = _cToTempDisplay(i.temperatureC).toStringAsFixed(1);
    _pressureCtrl.text = _hpaToPressureDisplay(i.pressureHpa).toStringAsFixed(
      _pressureUnit == _PressureUnit.hpa ? 0 : 2,
    );
    _rhCtrl.text = i.relativeHumidityPercent.toStringAsFixed(0);
    final daM = i.densityAltitudeMeters;
    if (daM == null || daM.abs() < 1e-6) {
      _daCtrl.text = '';
    } else {
      _daCtrl.text = _metersToLengthDisplay(daM).toStringAsFixed(1);
    }
    _elevDeltaCtrl.text = _metersToLengthDisplay(i.targetElevationDeltaMeters).toStringAsFixed(1);
    _slopeCtrl.text = _degreesToSlopeDisplay(i.slopeAngleDegrees).toStringAsFixed(2);
    _sightHcmCtrl.text = (i.sightHeightMeters * 100).toStringAsFixed(1);
    _zeroRangeCtrl.text = i.zeroRangeMeters.toStringAsFixed(0);
    _useMetWindVector = false;
    _crossWindCtrl.text = i.crossWindMps.toStringAsFixed(2);
    _coriolisOn = i.enableCoriolis;
    _latCtrl.text = i.latitudeDegrees.toStringAsFixed(1);
    _shotAzCtrl.text = i.azimuthFromNorthDegrees.toStringAsFixed(1);
    _spinOn = i.enableSpinDrift;
    _twistRightHanded = i.riflingTwistSign >= 0;
    if (i.bulletMassGrains != null) {
      _grainCtrl.text = i.bulletMassGrains!.toStringAsFixed(0);
    }
    if (i.bulletCaliberInches != null) {
      _calInCtrl.text = i.bulletCaliberInches!.toString();
    }
    if (i.twistInchesPerTurn != null) {
      _twistInCtrl.text = i.twistInchesPerTurn!.toString();
    }
    _jumpOn = i.enableAerodynamicJump;
    _clickUnit = i.clickUnit;
    _clickValueCtrl.text = i.clickValue.toString();
    final pairs = i.powderTempVelocityPairs;
    if (pairs.length >= 2) {
      _powderT1Ctrl.text = pairs[0].tempC.toStringAsFixed(1);
      _powderV1Ctrl.text = pairs[0].velocityMps.toStringAsFixed(0);
      _powderT2Ctrl.text = pairs[1].tempC.toStringAsFixed(1);
      _powderV2Ctrl.text = pairs[1].velocityMps.toStringAsFixed(0);
    } else {
      _powderT1Ctrl.clear();
      _powderV1Ctrl.clear();
      _powderT2Ctrl.clear();
      _powderV2Ctrl.clear();
    }
    final ptc = i.powderTemperatureC;
    _powderCurTCtrl.text = ptc == null ? '' : ptc.toStringAsFixed(1);
    final segs = i.bcMachSegments;
    _bcSegCtrl.text = segs == null || segs.isEmpty ? '' : _serializeBcMachSegments(segs);
    final cm = i.customDragMachNodes;
    final ci = i.customDragI;
    _customDragCtrl.text =
        cm != null && ci != null && cm.isNotEmpty ? _serializeCustomDragMachINodes(cm, ci) : '';
    _targetCrossCtrl.text = i.targetCrossTrackMps.toStringAsFixed(2);
    _angularMilConvention = i.angularMilConvention;
    _moaDisplayConvention = i.moaDisplayConvention;
    _invertCrossWindSign = i.invertCrossWindSign;
  }

  Future<void> _applyCompareRefToForm() async {
    final ref = _profileCompareRef;
    if (ref == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Önce «Referans» ile mevcut çözümü kaydedin.')),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _applySolveInputCoreToForm(ref));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Referans girdileri forma yazıldı. Rüzgâr: çözüme giren çapraz m/s (met vektör kapalı). '
          'Silah / dürbün / mühimmat seçimi aynı kaldı.',
        ),
      ),
    );
  }

  Future<void> _loadPersistedCompareRef() async {
    final r = await BallisticCompareRefStore.load();
    if (r == null || !mounted) return;
    setState(() {
      _profileCompareRef = r;
      _profileCompareSummary = _formatCompareRefSummary(r);
    });
  }

  Future<void> _clearProfileCompareRef() async {
    await BallisticCompareRefStore.clear();
    if (!mounted) return;
    setState(() {
      _profileCompareRef = null;
      _profileCompareSummary = '';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Karşılaştırma referansı silindi.')),
    );
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
    final p = WeaponProfileStore.current.value;
    setState(() {
      if (p != null) _applyWeaponProfileFields(p);
    });
  }

  void _onBookEntriesChanged() {
    if (mounted) setState(() {});
  }

  void _onSceneBookEntriesChanged() {
    if (mounted) setState(() {});
  }

  void _onShotSceneChanged() {
    if (!mounted) return;
    final s = ShotScenePresetBookStore.current.value;
    setState(() {
      if (s != null) {
        _applyShotSceneFields(s);
        _activeScenePresetId = s.id;
      } else {
        _activeScenePresetId = null;
      }
    });
  }

  void _applyPersistedProfileToForm() {
    final p = WeaponProfileStore.current.value;
    final s = ShotScenePresetBookStore.current.value;
    setState(() {
      if (p != null) _applyWeaponProfileFields(p);
      if (s != null) _applyShotSceneFields(s);
      _activeScenePresetId = s?.id;
    });
  }

  /// [setState] disinda da cagrilabilir (or. [_loadUserCatalog] icinde).
  void _applyWeaponProfileFields(WeaponProfile p) {
    WeaponType? catalogMatch;
    final wcId = p.weaponCatalogId;
    if (wcId != null && wcId.isNotEmpty) {
      for (final w in _weapons) {
        if (w.id == wcId) {
          catalogMatch = w;
          break;
        }
      }
    }
    _activeBookProfileId = p.id.isNotEmpty ? p.id : null;
    if (catalogMatch != null) {
      _selectedWeapon = catalogMatch;
    }
    _weaponNameCtrl.text = p.name;
    _mvCtrl.text = p.muzzleVelocityMps.toStringAsFixed(0);
    _bcCtrl.text = p.displayBallisticCoefficient.toString();
    _bcKind = p.bcKind;
    _sightHcmCtrl.text = (p.sightHeightM * 100).toStringAsFixed(1);
    _zeroRangeCtrl.text = p.zeroRangeM.toStringAsFixed(0);
    _clickUnit = p.clickUnit;
    _clickValueCtrl.text = p.clickValue.toString();
    _spinOn = p.enableSpinDrift;
    _twistRightHanded = p.twistRightHanded;
    if (p.bulletMassGrains != null) {
      _grainCtrl.text = p.bulletMassGrains!.toStringAsFixed(0);
    }
    if (p.bulletCaliberInches != null) {
      _calInCtrl.text = p.bulletCaliberInches!.toString();
    }
    if (p.twistInchesPerTurn != null) {
      _twistInCtrl.text = p.twistInchesPerTurn!.toString();
    }
    _coriolisOn = p.enableCoriolis;
    _jumpOn = p.enableAerodynamicJump;
    if (p.latitudeDegrees != null) {
      _latCtrl.text = p.latitudeDegrees!.toStringAsFixed(1);
    }
    if (p.azimuthFromNorthDegrees != null) {
      _shotAzCtrl.text = p.azimuthFromNorthDegrees!.toStringAsFixed(1);
    }
    _chronoVoLocked = p.chronoMuzzleVelocityLocked;
    if (p.preferredBarrelInches != null && p.preferredBarrelInches! > 0) {
      _barrelInchesCtrl.text = p.preferredBarrelInches!.toStringAsFixed(1);
    }
    _weaponNotesCtrl.text = p.userNotes ?? '';
    if (p.bulletLengthInches != null && p.bulletLengthInches! > 0) {
      _bulletLenInCtrl.text = p.bulletLengthInches!.toStringAsFixed(3);
    } else {
      _bulletLenInCtrl.clear();
    }
    if (p.zeroElevCompensationClicks != null) {
      _zeroElevCompCtrl.text = p.zeroElevCompensationClicks!.toStringAsFixed(2);
    } else {
      _zeroElevCompCtrl.clear();
    }
    if (p.zeroWindCompensationClicks != null) {
      _zeroWindCompCtrl.text = p.zeroWindCompensationClicks!.toStringAsFixed(2);
    } else {
      _zeroWindCompCtrl.clear();
    }
    if (p.zeroAtmosphereTempC != null) {
      _zeroAtmoTempCtrl.text = p.zeroAtmosphereTempC!.toStringAsFixed(1);
    } else {
      _zeroAtmoTempCtrl.clear();
    }
    if (p.zeroAtmospherePressureHpa != null) {
      _zeroAtmoPresCtrl.text = p.zeroAtmospherePressureHpa!.toStringAsFixed(1);
    } else {
      _zeroAtmoPresCtrl.clear();
    }
    if (p.zeroAtmosphereRhPercent != null) {
      _zeroAtmoRhCtrl.text = p.zeroAtmosphereRhPercent!.toStringAsFixed(0);
    } else {
      _zeroAtmoRhCtrl.clear();
    }
    if (p.zeroPowderTempC != null) {
      _zeroPowderTCtrl.text = p.zeroPowderTempC!.toStringAsFixed(1);
    } else {
      _zeroPowderTCtrl.clear();
    }

    _selectedScope = null;
    _selectedAmmo = null;
    _selectedAmmoVariantId = null;
    final scId = p.scopeCatalogId;
    ScopeType? scopeMatch;
    if (scId != null && scId.isNotEmpty) {
      for (final s in _scopes) {
        if (s.id == scId) {
          scopeMatch = s;
          break;
        }
      }
    }
    if (scopeMatch != null) {
      _selectedScope = scopeMatch;
      if (scopeMatch.defaultFirstFocalPlane != null) {
        _reticleFfp = scopeMatch.defaultFirstFocalPlane!;
      }
      final maxZ = scopeMatch.maxMagnification;
      final minZ = scopeMatch.minMagnification;
      if (maxZ != null && maxZ > 0) {
        _scopeMagCtrl.text = maxZ.toString();
      } else if (minZ != null && minZ > 0) {
        _scopeMagCtrl.text = minZ.toString();
      }
      final refZ = scopeMatch.referenceMagnification;
      if (refZ != null && refZ > 0) {
        _refMagCtrl.text = refZ.toString();
      }
      unawaited(_syncReticleFromScope(scopeMatch));
    }
    final amId = p.ammoCatalogId;
    if (amId != null && amId.isNotEmpty) {
      for (final a in _ammos) {
        if (a.id == amId) {
          _selectedAmmo = a;
          final vid = p.ammoVariantId;
          if (vid != null && a.variants.any((e) => e.id == vid)) {
            _selectedAmmoVariantId = vid;
          } else {
            _selectedAmmoVariantId = a.variants.isNotEmpty ? a.variants.first.id : null;
          }
          if (p.preferredBarrelInches != null && p.preferredBarrelInches! > 0) {
            _selectNearestBarrelInches(p.preferredBarrelInches!);
          } else if (_selectedAmmoVariantId != null) {
            final chosen = a.variantById(_selectedAmmoVariantId!);
            _barrelInchesCtrl.text = (chosen.barrelInches ?? 0) > 0
                ? chosen.barrelInches!.toStringAsFixed(1)
                : '';
          }
          break;
        }
      }
    }
  }

  void _applyShotSceneFields(ShotScenePreset p) {
    _tempUnit = _tempUnitFromKey(p.temperatureUnitKey);
    _pressureUnit = _pressureUnitFromKey(p.pressureUnitKey);
    _heightUnit = _heightUnitFromKey(p.heightUnitKey);
    _slopeUnit = _slopeUnitFromKey(p.slopeUnitKey);
    if (p.temperatureValue != null) {
      _tempCtrl.text = p.temperatureValue!.toStringAsFixed(1);
    }
    if (p.pressureValue != null) {
      _pressureCtrl.text = p.pressureValue!.toStringAsFixed(1);
    }
    if (p.humidityPercent != null) {
      _rhCtrl.text = p.humidityPercent!.toStringAsFixed(0);
    }
    if (p.densityAltitudeValue != null) {
      _daCtrl.text = p.densityAltitudeValue!.toStringAsFixed(1);
    }
    if (p.targetElevationDeltaValue != null) {
      _elevDeltaCtrl.text = p.targetElevationDeltaValue!.toStringAsFixed(1);
    }
    if (p.slopeValue != null) {
      _slopeCtrl.text = p.slopeValue!.toStringAsFixed(2);
    }
    _useMetWindVector = p.useMetWindVector;
    if (p.crossWindValue != null) {
      _crossWindCtrl.text = p.crossWindValue!.toStringAsFixed(1);
    }
    if (p.windSpeedValue != null) {
      _windSpeedVecCtrl.text = p.windSpeedValue!.toStringAsFixed(1);
    }
    if (p.windFromValue != null) {
      _windFromCtrl.text = p.windFromValue!.toStringAsFixed(1);
    }
    if (p.powderT1 != null) {
      _powderT1Ctrl.text = p.powderT1!.toStringAsFixed(1);
    }
    if (p.powderV1 != null) {
      _powderV1Ctrl.text = p.powderV1!.toStringAsFixed(1);
    }
    if (p.powderT2 != null) {
      _powderT2Ctrl.text = p.powderT2!.toStringAsFixed(1);
    }
    if (p.powderV2 != null) {
      _powderV2Ctrl.text = p.powderV2!.toStringAsFixed(1);
    }
    if (p.powderCurrentT != null) {
      _powderCurTCtrl.text = p.powderCurrentT!.toStringAsFixed(1);
    }
  }

  void _fillFormFromWeaponProfile(WeaponProfile p) {
    setState(() => _applyWeaponProfileFields(p));
  }

  /// Varsayilan: secili [WeaponType] ile eslesen + silahtan bagimsiz (genel) satirlar.
  List<WeaponProfile> _visibleBookProfiles() {
    final all = WeaponProfileBookStore.entries.value;
    if (_showAllWeaponBookEntries) return List<WeaponProfile>.from(all);
    final wid = _selectedWeapon?.id;
    if (wid == null) {
      return all
          .where((e) => e.weaponCatalogId == null || e.weaponCatalogId!.isEmpty)
          .toList();
    }
    return all
        .where((e) {
          final o = e.weaponCatalogId;
          return o == null || o.isEmpty || o == wid;
        })
        .toList();
  }

  String _bookEntryCatalogSubtitle(WeaponProfile e) {
    final id = e.weaponCatalogId;
    if (id == null || id.isEmpty) {
      return 'Katalog silahı: genel (tüm çeşitlerde listelenir)';
    }
    for (final w in _weapons) {
      if (w.id == id) return 'Katalog: ${w.name} · ${w.caliber}';
    }
    return 'Katalog id: $id (liste güncel değilse bulunmayabilir)';
  }

  String _bookScopeAmmoSummaryLine(WeaponProfile e) {
    String scope = '—';
    final sid = e.scopeCatalogId;
    if (sid != null && sid.isNotEmpty) {
      ScopeType? found;
      for (final s in _scopes) {
        if (s.id == sid) {
          found = s;
          break;
        }
      }
      scope = found?.name ?? sid;
    }
    String ammo = '—';
    final aid = e.ammoCatalogId;
    if (aid != null && aid.isNotEmpty) {
      AmmoType? found;
      for (final a in _ammos) {
        if (a.id == aid) {
          found = a;
          break;
        }
      }
      if (found != null) {
        final vid = e.ammoVariantId;
        AmmoBarrelVariant? v;
        if (vid != null) {
          v = found.variantById(vid);
        }
        final vLabel = v != null && v.label.isNotEmpty ? ' · ${v.label}' : '';
        ammo = '${found.name}$vLabel';
      } else {
        ammo = aid;
      }
    }
    return 'Dürbün: $scope · Mühimmat: $ammo';
  }

  String? _millerSfLineForBook(WeaponProfile e) {
    final sf = millerStabilityFactorGreen(
      bulletMassGrains: e.bulletMassGrains,
      caliberInches: e.bulletCaliberInches,
      twistInchesPerTurn: e.twistInchesPerTurn,
      avgVelocityMps: e.muzzleVelocityMps,
      temperatureC: 15,
      pressureHpa: 1013,
      relativeHumidityPercent: 0,
    );
    if (sf == null) return null;
    return 'SF ≈ ${sf.toStringAsFixed(2)} (Miller, referans 15 °C)';
  }

  /// Defter özet satırı — hatve / mermi kayıtlıysa gösterilir.
  String? _bookSpinSummaryLine(WeaponProfile e) {
    final has = e.enableSpinDrift ||
        e.bulletMassGrains != null ||
        e.bulletCaliberInches != null ||
        e.twistInchesPerTurn != null;
    if (!has) return null;
    final parts = <String>[];
    if (e.bulletMassGrains != null) {
      parts.add('${e.bulletMassGrains!.toStringAsFixed(0)} gr');
    }
    if (e.bulletCaliberInches != null) {
      parts.add('${e.bulletCaliberInches} in çap');
    }
    if (e.twistInchesPerTurn != null) {
      parts.add('1:${e.twistInchesPerTurn} ${e.twistRightHanded ? 'RH' : 'LH'}');
    }
    final tail = parts.isEmpty ? '—' : parts.join(' · ');
    return 'Spin/hedef: ${e.enableSpinDrift ? 'açık' : 'kapalı'} · $tail';
  }

  /// Coriolis / jump / enlem / azimut özeti.
  String? _bookCoriolisSummaryLine(WeaponProfile e) {
    final has = e.enableCoriolis ||
        e.enableAerodynamicJump ||
        e.latitudeDegrees != null ||
        e.azimuthFromNorthDegrees != null;
    if (!has) return null;
    final parts = <String>[];
    if (e.enableCoriolis) parts.add('Coriolis');
    if (e.latitudeDegrees != null) {
      parts.add('φ ${e.latitudeDegrees!.toStringAsFixed(1)}°');
    }
    if (e.enableAerodynamicJump) parts.add('Aero jump');
    if (e.azimuthFromNorthDegrees != null) {
      parts.add('Atış azimut ${e.azimuthFromNorthDegrees!.toStringAsFixed(0)}°');
    }
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }

  List<ShotScenePreset> _visibleScenePresets() {
    final all = ShotScenePresetBookStore.entries.value;
    if (_showAllSceneBookEntries) return List<ShotScenePreset>.from(all);
    final wid = WeaponProfileStore.current.value?.id;
    if (wid == null || wid.isEmpty) {
      return all.where((e) => e.linkedWeaponProfileId == null || e.linkedWeaponProfileId!.isEmpty).toList();
    }
    return all
        .where((e) =>
            e.linkedWeaponProfileId == null || e.linkedWeaponProfileId!.isEmpty || e.linkedWeaponProfileId == wid)
        .toList();
  }

  Future<void> _applyBookSceneEntry(ShotScenePreset p) async {
    await ShotScenePresetBookStore.setActive(p);
    if (!mounted) return;
    setState(() {
      _applyShotSceneFields(p);
      _activeScenePresetId = p.id;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sahne yüklendi: ${p.name}')),
    );
  }

  Future<void> _deleteScenePresetEntry(String id) async {
    await ShotScenePresetBookStore.remove(id);
    if (!mounted) return;
    if (_activeScenePresetId == id) {
      _activeScenePresetId = ShotScenePresetBookStore.current.value?.id;
    }
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sahne silindi.')),
    );
  }

  void _startNewScenePreset() {
    setState(() => _activeScenePresetId = null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sonraki «Sahneyi kaydet» yeni sahne satırı oluşturur.'),
      ),
    );
  }

  Future<void> _applyBookProfileEntry(WeaponProfile p) async {
    await WeaponProfileBookStore.setActive(p);
    if (!mounted) return;
    _fillFormFromWeaponProfile(p);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Defterden yuklendi: ${p.name}')),
    );
  }

  Future<void> _deleteBookProfileEntry(String id) async {
    await WeaponProfileBookStore.remove(id);
    if (!mounted) return;
    if (_activeBookProfileId == id) {
      _activeBookProfileId = WeaponProfileStore.current.value?.id;
    }
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profil silindi.')),
    );
  }

  void _startNewBookProfile() {
    setState(() => _activeBookProfileId = null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sonraki «Profili kaydet» yeni defter satiri olur.'),
      ),
    );
  }

  @override
  void dispose() {
    _barometerSub?.cancel();
    _ballisticsRangePrefsSaveTimer?.cancel();
    _distanceCtrl.removeListener(_onBallisticsRangePrefsFieldChanged);
    _tableStartCtrl.removeListener(_onBallisticsRangePrefsFieldChanged);
    _tableEndCtrl.removeListener(_onBallisticsRangePrefsFieldChanged);
    _tableStepCtrl.removeListener(_onBallisticsRangePrefsFieldChanged);
    unawaited(_flushBallisticsRangePrefs());
    _tabController.dispose();
    BallisticsEnvBridge.pending.removeListener(_applyBleEnvToForm);
    WeaponProfileStore.current.removeListener(_onWeaponProfileChanged);
    WeaponProfileBookStore.entries.removeListener(_onBookEntriesChanged);
    ShotScenePresetBookStore.current.removeListener(_onShotSceneChanged);
    ShotScenePresetBookStore.entries.removeListener(_onSceneBookEntriesChanged);
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
      _barrelInchesCtrl,
      _tableStartCtrl,
      _tableEndCtrl,
      _tableStepCtrl,
      _reticleSearchCtrl,
      _bcSegCtrl,
      _customDragCtrl,
      _targetCrossCtrl,
      _weaponNotesCtrl,
      _bulletLenInCtrl,
      _zeroElevCompCtrl,
      _zeroWindCompCtrl,
      _zeroAtmoTempCtrl,
      _zeroAtmoPresCtrl,
      _zeroAtmoRhCtrl,
      _zeroPowderTCtrl,
      _clickValueCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Silah / dürbün / mühimmat açılır listeleri — ada göre A–Z (yerel bağımsız ASCII sıra).
  void _sortCatalogAlphabetically() {
    int byName(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());
    _weapons.sort((x, y) => byName(x.name, y.name));
    _scopes.sort((x, y) => byName(x.name, y.name));
    _ammos.sort((x, y) => byName(x.name, y.name));
  }

  /// Katalog listeleri yenilendikten sonra [DropdownMenuItem.value] ile aynı nesne referansına döner;
  /// aksi halde seçim eski listeden kalır ve açılır liste değiştirilemez.
  void _rebindCatalogSelectionsToLoadedLists() {
    final w = _selectedWeapon;
    if (w != null) {
      WeaponType? match;
      for (final x in _weapons) {
        if (x.id == w.id) {
          match = x;
          break;
        }
      }
      _selectedWeapon = match;
    }
    final s = _selectedScope;
    if (s != null) {
      ScopeType? match;
      for (final x in _scopes) {
        if (x.id == s.id) {
          match = x;
          break;
        }
      }
      _selectedScope = match;
    }
    final a = _selectedAmmo;
    if (a != null) {
      AmmoType? match;
      for (final x in _ammos) {
        if (x.id == a.id) {
          match = x;
          break;
        }
      }
      _selectedAmmo = match;
      if (match != null) {
        final vid = _selectedAmmoVariantId;
        if (vid != null && !match.variants.any((e) => e.id == vid)) {
          _selectedAmmoVariantId = match.variants.isNotEmpty ? match.variants.first.id : null;
        }
        if ((_selectedAmmoVariantId == null || _selectedAmmoVariantId!.isEmpty) &&
            match.variants.isNotEmpty) {
          _selectedAmmoVariantId = match.variants.first.id;
        }
      } else {
        _selectedAmmoVariantId = null;
      }
    }
  }

  Future<void> _showSavedWeaponProfilesSheet() async {
    if (!mounted) return;
    final theme = Theme.of(context);
    final entries = List<WeaponProfile>.from(WeaponProfileBookStore.entries.value)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final maxH = MediaQuery.sizeOf(ctx).height * 0.65;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Text(
                    'Kayıtlı silahlarım',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                if (entries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Text(
                      'Defterde kayıt yok. «Silah» sekmesinden katalog seçip «Profili kaydet» ile ekleyin.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxH),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: entries.length,
                      itemBuilder: (ctx2, i) {
                        final p = entries[i];
                        final curId = WeaponProfileStore.current.value?.id;
                        final active = p.id.isNotEmpty && p.id == curId;
                        return ListTile(
                          leading: Icon(
                            active ? Icons.check_circle : Icons.circle_outlined,
                            color: active ? theme.colorScheme.primary : theme.colorScheme.outline,
                          ),
                          title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                            '${_bookEntryCatalogSubtitle(p)}\n${_bookScopeAmmoSummaryLine(p)}',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            unawaited(_applyBookProfileEntry(p));
                          },
                        );
                      },
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() => _tabController.index = 1);
                    },
                    child: const Text('Katalogdan silah · dürbün · mühimmat seç (Silah sekmesi)'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _loadUserCatalog() async {
    final bundled = await CatalogLoader.loadTurkeyNato();
    final presetBundle = await BallisticPresetRepository.loadActiveOrBuiltIn();
    final prevManifest = await BallisticPresetRepository.peekPreviousManifest();
    final uw = await UserCatalogStore.loadWeapons();
    final us = await UserCatalogStore.loadScopes();
    final ua = await UserCatalogStore.loadAmmos();
    if (!mounted) return;
    setState(() {
      _weapons = CatalogLoader.mergeWeapons(CatalogData.weapons, bundled.weapons, uw);
      _scopes = CatalogLoader.mergeScopes(
        CatalogData.scopes,
        [...bundled.scopes, ...CatalogStrelockExtra.scopes],
        us,
      );
      _ammos = CatalogLoader.mergeAmmos(
        CatalogData.ammos,
        [...bundled.ammos, ...CatalogStrelockExtra.ammos],
        ua,
      );
      _sortCatalogAlphabetically();
      _weaponPresetMap = presetBundle.weaponPresets;
      _caliberFallbackPresetMap = presetBundle.caliberFallbackPresets;
      _activePresetVersion = presetBundle.manifest.dataVersion;
      _activePresetSource = presetBundle.manifest.source;
      _previousPresetManifest = prevManifest;
      final persisted = WeaponProfileStore.current.value;
      if (persisted != null) {
        _applyWeaponProfileFields(persisted);
      } else if (_selectedWeapon != null) {
        _applyWeaponBallisticPreset(_selectedWeapon!);
      }
      final scene = ShotScenePresetBookStore.current.value;
      if (scene != null) {
        _applyShotSceneFields(scene);
        _activeScenePresetId = scene.id;
      }
      _rebindCatalogSelectionsToLoadedLists();
    });
  }

  Future<void> _updateBallisticPresetsFromRemote() async {
    final savedUrl = await BallisticPresetUpdater.getRemoteUrl() ?? '';
    if (!mounted) return;
    final ctrl = TextEditingController(text: savedUrl);
    var forceApply = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Preset güncelle (remote)'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Manifest URL',
                    hintText: 'https://example.com/ballistics/presets.json',
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: forceApply,
                  onChanged: (v) => setLocal(() => forceApply = v),
                  title: const Text('Zorla uygula'),
                  subtitle: Text(
                    'Aynı sürüm etiketinde bile paketi yeniden doğrular ve yükler.',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Güncelle')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final url = ctrl.text.trim();
    if (url.isEmpty) return;
    setState(() => _isUpdatingRemotePresets = true);
    final res = await BallisticPresetUpdater.updateFromUrl(url, force: forceApply);
    if (!mounted) return;
    setState(() => _isUpdatingRemotePresets = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(res.message)),
    );
    if (res.success) {
      await _loadUserCatalog();
    }
  }

  Future<void> _rollbackBallisticPresets() async {
    final prev = _previousPresetManifest ?? await BallisticPresetRepository.peekPreviousManifest();
    if (prev == null || !mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Önceki preset sürümüne dön'),
        content: Text(
          'Aktif: $_activePresetVersion ($_activePresetSource)\n'
          'Yüklenecek: ${prev.dataVersion} (${prev.source})\n\n'
          'Bir önceki kayıtlı paketle değiştirilsin mi?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Geri al')),
        ],
      ),
    );
    if (ok != true) return;
    final did = await BallisticPresetRepository.rollbackToPrevious();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          did
              ? 'Önceki preset yüklendi.'
              : 'Geri alınacak paket bulunamadı.',
        ),
      ),
    );
    if (did) {
      await _loadUserCatalog();
    }
  }

  Future<void> _loadReticleCatalog() async {
    final list = await ReticleCatalogLoader.load();
    if (!mounted) return;
    final scopeSnap = _selectedScope;
    setState(() {
      _reticles = list;
      if (_selectedReticle == null && list.isNotEmpty) {
        final idx = list.indexWhere((e) => e.id.startsWith('ret_generic_extra_'));
        _selectedReticle = idx >= 0 ? list[idx] : list.first;
      }
    });
    await _reloadReticleQuickPrefs();
    if (scopeSnap != null && _autoReticleFromScope && list.isNotEmpty) {
      await _syncReticleFromScope(scopeSnap);
    }
  }

  Future<void> _syncReticleFromScope(ScopeType s) async {
    if (!_autoReticleFromScope || _reticles.isEmpty) return;
    final rid = defaultReticleCatalogIdForScope(s) ?? fallbackReticleCatalogId(s.clickUnit);
    final idx = _reticles.indexWhere((e) => e.id == rid);
    if (idx < 0) return;
    await _selectReticle(_reticles[idx]);
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

  double? get _solutionRangeM => double.tryParse(_distanceCtrl.text.replaceAll(',', '.'));

  String get _pressureSuffixForKestrel => switch (_pressureUnit) {
        _PressureUnit.hpa => 'hPa',
        _PressureUnit.inHg => 'inHg',
        _PressureUnit.mmHg => 'mmHg',
        _PressureUnit.psi => 'psi',
      };

  String _kestrelTemperatureLine() {
    final t = _tempCtrl.text.trim();
    if (t.isEmpty) return '—';
    return '$t${_tempUnit == _TempUnit.c ? '°C' : '°F'}';
  }

  String _kestrelPressureLine() {
    final p = _pressureCtrl.text.trim();
    if (p.isEmpty) return 'Basınç: —';
    return 'Basınç: $p $_pressureSuffixForKestrel';
  }

  String _kestrelHumidityLine() {
    final h = _rhCtrl.text.trim();
    if (h.isEmpty) return 'RH —';
    return 'RH $h%';
  }

  String? _kestrelDensityAltitudeLine() {
    final d = _daCtrl.text.trim();
    if (d.isEmpty) return null;
    return 'DA=$d m';
  }

  String _tempUnitKey(_TempUnit u) => switch (u) { _TempUnit.c => 'c', _TempUnit.f => 'f' };
  String _pressureUnitKey(_PressureUnit u) => switch (u) {
        _PressureUnit.hpa => 'hpa',
        _PressureUnit.inHg => 'inHg',
        _PressureUnit.mmHg => 'mmHg',
        _PressureUnit.psi => 'psi',
      };
  String _heightUnitKey(_LengthUnit u) => switch (u) { _LengthUnit.m => 'm', _LengthUnit.ft => 'ft' };
  String _slopeUnitKey(_SlopeUnit u) => switch (u) {
        _SlopeUnit.deg => 'deg',
        _SlopeUnit.percent => 'percent',
        _SlopeUnit.cos => 'cos',
      };
  _TempUnit _tempUnitFromKey(String? s) => s == 'f' ? _TempUnit.f : _TempUnit.c;
  _PressureUnit _pressureUnitFromKey(String? s) => switch (s) {
        'inHg' => _PressureUnit.inHg,
        'mmHg' => _PressureUnit.mmHg,
        'psi' => _PressureUnit.psi,
        _ => _PressureUnit.hpa,
      };
  _LengthUnit _heightUnitFromKey(String? s) => s == 'ft' ? _LengthUnit.ft : _LengthUnit.m;
  _SlopeUnit _slopeUnitFromKey(String? s) => switch (s) {
        'percent' => _SlopeUnit.percent,
        'cos' => _SlopeUnit.cos,
        _ => _SlopeUnit.deg,
      };

  double _tempToC(double v) => _tempUnit == _TempUnit.c ? v : (v - 32.0) * 5.0 / 9.0;

  double _pressureToHpa(double v) {
    switch (_pressureUnit) {
      case _PressureUnit.hpa:
        return v;
      case _PressureUnit.inHg:
        return v * 33.8638866667;
      case _PressureUnit.mmHg:
        return v * 1.33322;
      case _PressureUnit.psi:
        return v * 68.9475729328;
    }
  }

  double _lengthToMeters(double v) => _heightUnit == _LengthUnit.m ? v : v * 0.3048;

  double _slopeToDegrees(double v) {
    switch (_slopeUnit) {
      case _SlopeUnit.deg:
        return v;
      case _SlopeUnit.percent:
        return math.atan(v / 100.0) * 180.0 / math.pi;
      case _SlopeUnit.cos:
        final c = v.clamp(-1.0, 1.0);
        return math.acos(c) * 180.0 / math.pi;
    }
  }

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
    final tRaw = _parse(_tempCtrl.text);
    final pRaw = _parse(_pressureCtrl.text);
    final elevRaw = _parse(_elevDeltaCtrl.text);
    final slopeRaw = _parse(_slopeCtrl.text);
    final bcSeg = parseBcMachSegments(_bcSegCtrl.text);
    final customDrag = parseCustomDragTable(_customDragCtrl.text);
    final customINodes = customDrag?.iNodes;
    return BallisticsSolveInput(
      distanceMeters: _parse(_distanceCtrl.text),
      muzzleVelocityMps: _parse(_mvCtrl.text),
      bcKind: _bcKind,
      ballisticCoefficient: _parse(_bcCtrl.text),
      temperatureC: _tempToC(tRaw),
      pressureHpa: _pressureToHpa(pRaw),
      relativeHumidityPercent: double.tryParse(_rhCtrl.text.replaceAll(',', '.')) ?? 0,
      densityAltitudeMeters:
          (daRaw != null && daRaw.abs() > 1e-6) ? _lengthToMeters(daRaw) : null,
      targetElevationDeltaMeters: _lengthToMeters(elevRaw),
      slopeAngleDegrees: _slopeToDegrees(slopeRaw),
      sightHeightMeters: (double.tryParse(_sightHcmCtrl.text.replaceAll(',', '.')) ?? 3.8) / 100.0,
      zeroRangeMeters: double.tryParse(_zeroRangeCtrl.text.replaceAll(',', '.')) ?? 100,
      crossWindMps: _crossWindMpsResolved(),
      enableCoriolis: _coriolisOn,
      latitudeDegrees: double.tryParse(_latCtrl.text.replaceAll(',', '.')) ?? 0,
      azimuthFromNorthDegrees: double.tryParse(_shotAzCtrl.text.replaceAll(',', '.')) ?? 0,
      enableSpinDrift: _spinOn,
      riflingTwistSign: _twistRightHanded ? 1 : -1,
      bulletMassGrains: double.tryParse(_grainCtrl.text.replaceAll(',', '.')),
      bulletCaliberInches: double.tryParse(_calInCtrl.text.replaceAll(',', '.')),
      twistInchesPerTurn: double.tryParse(_twistInCtrl.text.replaceAll(',', '.')),
      enableAerodynamicJump: _jumpOn,
      clickUnit: _clickUnit,
      clickValue: _parse(_clickValueCtrl.text),
      powderTempVelocityPairs: _powderPairs(),
      powderTemperatureC: double.tryParse(_powderCurTCtrl.text.replaceAll(',', '.')),
      bcMachSegments: bcSeg,
      customDragMachNodes: customDrag?.machs,
      customDragI: customINodes,
      targetCrossTrackMps: double.tryParse(_targetCrossCtrl.text.replaceAll(',', '.')) ?? 0,
      angularMilConvention: _angularMilConvention,
      moaDisplayConvention: _moaDisplayConvention,
      invertCrossWindSign: _invertCrossWindSign,
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
          height: 460,
          child: Scrollbar(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  columnSpacing: 14,
                  columns: const [
                    DataColumn(label: Text('Hedef')),
                    DataColumn(label: Text('m')),
                    DataColumn(label: Text('Δh m')),
                    DataColumn(label: Text('Elev mil')),
                    DataColumn(label: Text('Wind mil')),
                    DataColumn(label: Text('Lead mil')),
                    DataColumn(label: Text('LatΣ mil')),
                    DataColumn(label: Text('d cm')),
                    DataColumn(label: Text('w cm')),
                    DataColumn(label: Text('ön cm')),
                    DataColumn(label: Text('L cm')),
                    DataColumn(label: Text('E MOA')),
                    DataColumn(label: Text('W MOA')),
                    DataColumn(label: Text('Lead MOA')),
                    DataColumn(label: Text('L MOA')),
                    DataColumn(label: Text('El. klik')),
                    DataColumn(label: Text('Wnd klik')),
                    DataColumn(label: Text('Lead klik')),
                    DataColumn(label: Text('Lat klik')),
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
                          DataCell(Text(o.leadMil.toStringAsFixed(2))),
                          DataCell(Text(o.combinedLateralMil.toStringAsFixed(2))),
                          DataCell(Text((o.verticalHoldDeltaMeters * 100).toStringAsFixed(0))),
                          DataCell(Text((o.windLateralDeltaMeters * 100).toStringAsFixed(0))),
                          DataCell(Text((o.leadLateralDeltaMeters * 100).toStringAsFixed(0))),
                          DataCell(Text((o.combinedLateralDeltaMeters * 100).toStringAsFixed(0))),
                          DataCell(Text(o.dropMoa.toStringAsFixed(2))),
                          DataCell(Text(o.windMoa.toStringAsFixed(2))),
                          DataCell(Text(o.leadMoa.toStringAsFixed(2))),
                          DataCell(Text(o.combinedLateralMoa.toStringAsFixed(2))),
                          DataCell(Text(o.clicks.toStringAsFixed(2))),
                          DataCell(Text(o.windClicks.toStringAsFixed(2))),
                          DataCell(Text(o.leadClicks.toStringAsFixed(2))),
                          DataCell(Text(o.combinedLateralClicks.toStringAsFixed(2))),
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
          TextButton(
            onPressed: () async {
              final csv = savedTargetSolvesToCsv([
                for (final (t, o) in rows)
                  (t.name, t.distanceMeters, t.elevationDeltaMeters, o),
              ]);
              await shareCsvText(csv, filename: 'blue_viper_saved_targets.csv');
            },
            child: const Text('CSV paylaş'),
          ),
          TextButton(
            onPressed: () async {
              final tableRows = [
                for (final (t, o) in rows)
                  RangeTableRow.fromSolveOutput(t.distanceMeters.round(), o),
              ];
              await shareRangeTableXlsx(
                rows: tableRows,
                filename: 'blue_viper_saved_targets.xlsx',
                nameColumn: [for (final (t, _) in rows) t.name],
                deltaHmColumn: [for (final (t, _) in rows) t.elevationDeltaMeters],
              );
            },
            child: const Text('Excel (xlsx)'),
          ),
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
      id: _activeBookProfileId ?? '',
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
      weaponCatalogId: _selectedWeapon?.id,
      scopeCatalogId: _selectedScope?.id,
      ammoCatalogId: _selectedAmmo?.id,
      ammoVariantId: _activeAmmoVariant?.id,
      chronoMuzzleVelocityLocked: _chronoVoLocked,
      preferredBarrelInches: double.tryParse(_barrelInchesCtrl.text.replaceAll(',', '.')),
      enableSpinDrift: _spinOn,
      twistRightHanded: _twistRightHanded,
      bulletMassGrains: double.tryParse(_grainCtrl.text.replaceAll(',', '.')),
      bulletCaliberInches: double.tryParse(_calInCtrl.text.replaceAll(',', '.')),
      twistInchesPerTurn: double.tryParse(_twistInCtrl.text.replaceAll(',', '.')),
      enableCoriolis: _coriolisOn,
      latitudeDegrees: double.tryParse(_latCtrl.text.replaceAll(',', '.')),
      enableAerodynamicJump: _jumpOn,
      azimuthFromNorthDegrees: double.tryParse(_shotAzCtrl.text.replaceAll(',', '.')),
      userNotes: _weaponNotesCtrl.text.trim().isEmpty ? null : _weaponNotesCtrl.text.trim(),
      zeroElevCompensationClicks: double.tryParse(_zeroElevCompCtrl.text.replaceAll(',', '.')),
      zeroWindCompensationClicks: double.tryParse(_zeroWindCompCtrl.text.replaceAll(',', '.')),
      zeroAtmosphereTempC: double.tryParse(_zeroAtmoTempCtrl.text.replaceAll(',', '.')),
      zeroAtmospherePressureHpa: double.tryParse(_zeroAtmoPresCtrl.text.replaceAll(',', '.')),
      zeroAtmosphereRhPercent: double.tryParse(_zeroAtmoRhCtrl.text.replaceAll(',', '.')),
      zeroPowderTempC: double.tryParse(_zeroPowderTCtrl.text.replaceAll(',', '.')),
      bulletLengthInches: double.tryParse(_bulletLenInCtrl.text.replaceAll(',', '.')),
    );
    final saved = await WeaponProfileBookStore.upsertAndActivate(profile);
    if (!mounted) return;
    setState(() => _activeBookProfileId = saved.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deftere kaydedildi: ${saved.name}')),
    );
  }

  Future<void> _saveShotScenePreset() async {
    if (!_formKey.currentState!.validate()) return;
    var name = 'Sahne';
    ShotScenePreset? existing;
    for (final e in ShotScenePresetBookStore.entries.value) {
      if (e.id == _activeScenePresetId) {
        existing = e;
        break;
      }
    }
    if (existing != null) {
      name = existing.name;
    } else {
      final nameCtrl = TextEditingController(text: 'Sahne');
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Sahne kaydı'),
          content: TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Sahne adı',
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
      name = nameCtrl.text.trim().isEmpty ? 'Sahne' : nameCtrl.text.trim();
    }
    final wpId = WeaponProfileStore.current.value?.id ?? _activeBookProfileId ?? '';
    final preset = ShotScenePreset(
      id: _activeScenePresetId ?? '',
      name: name,
      linkedWeaponProfileId: wpId.isNotEmpty ? wpId : null,
      temperatureUnitKey: _tempUnitKey(_tempUnit),
      pressureUnitKey: _pressureUnitKey(_pressureUnit),
      heightUnitKey: _heightUnitKey(_heightUnit),
      slopeUnitKey: _slopeUnitKey(_slopeUnit),
      temperatureValue: double.tryParse(_tempCtrl.text.replaceAll(',', '.')),
      pressureValue: double.tryParse(_pressureCtrl.text.replaceAll(',', '.')),
      humidityPercent: double.tryParse(_rhCtrl.text.replaceAll(',', '.')),
      densityAltitudeValue: double.tryParse(_daCtrl.text.replaceAll(',', '.')),
      targetElevationDeltaValue: double.tryParse(_elevDeltaCtrl.text.replaceAll(',', '.')),
      slopeValue: double.tryParse(_slopeCtrl.text.replaceAll(',', '.')),
      useMetWindVector: _useMetWindVector,
      crossWindValue: double.tryParse(_crossWindCtrl.text.replaceAll(',', '.')),
      windSpeedValue: double.tryParse(_windSpeedVecCtrl.text.replaceAll(',', '.')),
      windFromValue: double.tryParse(_windFromCtrl.text.replaceAll(',', '.')),
      powderT1: double.tryParse(_powderT1Ctrl.text.replaceAll(',', '.')),
      powderV1: double.tryParse(_powderV1Ctrl.text.replaceAll(',', '.')),
      powderT2: double.tryParse(_powderT2Ctrl.text.replaceAll(',', '.')),
      powderV2: double.tryParse(_powderV2Ctrl.text.replaceAll(',', '.')),
      powderCurrentT: double.tryParse(_powderCurTCtrl.text.replaceAll(',', '.')),
    );
    final saved = await ShotScenePresetBookStore.upsertAndActivate(preset);
    if (!mounted) return;
    setState(() => _activeScenePresetId = saved.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sahne kaydedildi: ${saved.name}')),
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

  Future<void> _truingDialog({bool initialTuneMv = false}) async {
    final ammoLine = _selectedAmmo != null
        ? '${_selectedAmmo!.name} (${_selectedAmmo!.caliber})'
        : 'Mühimmat seçilmedi';
    final r = await Navigator.of(context).push<TrajectoryValidationResult>(
      MaterialPageRoute<TrajectoryValidationResult>(
        fullscreenDialog: true,
        builder: (ctx) => TrajectoryValidationPage(
          ammoSummary: ammoLine,
          initialMvMode: initialTuneMv,
          distanceController: _distanceCtrl,
          currentMvText: _mvCtrl.text.trim().isEmpty ? '—' : _mvCtrl.text.trim(),
          currentBcText: _bcCtrl.text.trim(),
          bcKindLabel: _bcKind.label,
          validateParentForm: () => _formKey.currentState?.validate() ?? false,
          collectInput: _collectInput,
          clickUnit: _clickUnit,
          clickValueText: _clickValueCtrl.text,
        ),
      ),
    );
    if (!mounted || r == null) return;
    if (r.mv != null) {
      setState(() {
        _mvCtrl.text = r.mv!.toStringAsFixed(1);
        _chronoVoLocked = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Vo güncellendi: ${r.mv!.toStringAsFixed(1)} m/s — saha Vo kilidi etkin (katalog Vo’yu değiştirmez).',
          ),
        ),
      );
    } else if (r.bc != null) {
      setState(() => _bcCtrl.text = r.bc!.toStringAsFixed(4));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_bcKind.label} BC güncellendi: ${r.bc!.toStringAsFixed(4)}')),
      );
    }
  }

  Future<void> _rangeTableDialog() async {
    if (!_formKey.currentState!.validate()) return;
    final start = int.tryParse(_tableStartCtrl.text) ?? BallisticsRangeUi.defaultTableStartM;
    final end = int.tryParse(_tableEndCtrl.text) ?? BallisticsRangeUi.fallbackTableEndM;
    final step = int.tryParse(_tableStepCtrl.text) ?? BallisticsRangeUi.defaultTableStepM;
    if (end < start || step <= 0) return;
    final rowCount = BallisticsRangeUi.rangeTableRowCount(start, end, step);
    if (rowCount > BallisticsRangeUi.maxRangeTableRows) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Menzil tablosu çok uzun ($rowCount satır, üst sınır ${BallisticsRangeUi.maxRangeTableRows}). '
            'Adımı büyütün veya bitiş menzilini düşürün.',
          ),
        ),
      );
      return;
    }
    final rows = buildBallisticsRangeTable(
      template: _collectInput(),
      startMeters: start,
      endMeters: end,
      stepMeters: step,
    );
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (ctx) => RangeTablePage(
          rows: rows,
          clickUnitShort: _clickUnit.label,
        ),
      ),
    );
  }

  Future<void> _openMovingTargetPage() async {
    BallisticsSolveInput? baseline;
    if (_formKey.currentState?.validate() == true) {
      baseline = _collectInput();
    }
    final applied = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (ctx) => MovingTargetLeadPage(
          baselineInput: baseline,
          onApplyCrossTrackMps: (v) {
            if (!mounted) return;
            setState(() => _targetCrossCtrl.text = v.toStringAsFixed(2));
          },
        ),
      ),
    );
    if (!mounted || applied != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Çapraz hız forma yazıldı; «HESAPLA» veya Ek sekmesinden doğrulayın.'),
      ),
    );
  }

  Future<void> _showZeroWizardDialog() async {
    final rangeC = TextEditingController(text: _distanceCtrl.text.trim());
    final offsetC = TextEditingController();
    try {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Sıfır / nişan sihirbazı'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: rangeC,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Menzil (m)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: offsetC,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Gözlenen dikey sapma (cm)',
                  helperText: '+ hedefin üstünde (yüksek vuruş), − alt',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
            FilledButton(
              onPressed: () {
                final rm = double.tryParse(rangeC.text.replaceAll(',', '.')) ?? 0;
                final cm = double.tryParse(offsetC.text.replaceAll(',', '.')) ?? 0;
                if (rm <= 0) return;
                final deltaM = -cm / 100.0;
                final mil = milFromLateralMeters(
                  deltaM: deltaM,
                  rangeM: rm,
                  convention: _angularMilConvention,
                );
                final moa = moaFromMilAndGeometry(
                  mil: mil,
                  deltaM: deltaM,
                  rangeM: rm,
                  convention: _moaDisplayConvention,
                );
                final cv = _parse(_clickValueCtrl.text);
                final clicks = clicksForCorrectionMil(
                  correctionMil: mil,
                  clickUnit: _clickUnit,
                  clickValue: cv,
                  moaClickConvention: _moaDisplayConvention,
                  angularMilConvention: _angularMilConvention,
                );
                Navigator.pop(ctx);
                if (!context.mounted) return;
                showDialog<void>(
                  context: context,
                  builder: (ctx2) => AlertDialog(
                    title: const Text('Önerilen dikey düzeltme'),
                    content: Text(
                      '≈ ${mil.toStringAsFixed(2)} mil · ${moa.toStringAsFixed(2)} MOA (seçili gösterim) · '
                      '≈ ${clicks.toStringAsFixed(1)} klik (${_clickUnit.label}, ${_clickValueCtrl.text}).\n\n'
                      'Yüksek vuruşta genelde elevasyonu azaltın (nişan hattı / tıklama yönü dürbüne göre değişir).',
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx2), child: const Text('Tamam')),
                    ],
                  ),
                );
              },
              child: const Text('Hesapla'),
            ),
          ],
        ),
      );
    } finally {
      rangeC.dispose();
      offsetC.dispose();
    }
  }

  Future<void> _openConvertersHub() async {
    final picked = await Navigator.of(context).push<BallisticsConverterAction>(
      MaterialPageRoute<BallisticsConverterAction>(
        fullscreenDialog: true,
        builder: (ctx) => BallisticsConvertersPage(
          compareRefReady: _profileCompareRef != null,
          onPick: (a) => Navigator.of(ctx).pop(a),
        ),
      ),
    );
    if (!mounted || picked == null) return;
    switch (picked) {
      case BallisticsConverterAction.truingVo:
        await _truingDialog(initialTuneMv: true);
      case BallisticsConverterAction.truingBc:
        await _truingDialog(initialTuneMv: false);
      case BallisticsConverterAction.truingAdvanced:
        await _truingDialog();
      case BallisticsConverterAction.rangeTable:
        await _rangeTableDialog();
      case BallisticsConverterAction.batchMultiRange:
        await _batchRangeListDialog();
      case BallisticsConverterAction.movingTarget:
        await _openMovingTargetPage();
      case BallisticsConverterAction.zeroWizard:
        await _showZeroWizardDialog();
      case BallisticsConverterAction.captureCompareRef:
        await _captureProfileCompareRef();
      case BallisticsConverterAction.runCompare:
        await _compareProfilesDialog();
      case BallisticsConverterAction.extraData:
        await _openExtraDataPage();
      case BallisticsConverterAction.unitConverters:
        if (!mounted) return;
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => const BallisticsUnitConvertersPage()),
        );
      case BallisticsConverterAction.bleDevicePrefs:
        if (!mounted) return;
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => const BleHubPage()),
        );
    }
  }

  Future<void> _openExtraDataPage() async {
    if (!_formKey.currentState!.validate()) return;
    if (_result == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Önce «HESAPLA» ile çözüm üretin.')),
      );
      return;
    }
    final p = WeaponProfileStore.current.value;
    final ze = p?.zeroElevCompensationClicks ?? 0;
    final zw = p?.zeroWindCompensationClicks ?? 0;
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => BallisticsExtraDataPage(
          input: _collectInput(),
          output: _result!,
          zeroElevCompClicks: ze,
          zeroWindCompClicks: zw,
          showEnergyFtLbf: _energyFtLbf,
        ),
      ),
    );
  }

  Future<void> _captureProfileCompareRef() async {
    if (!_formKey.currentState!.validate()) return;
    final snap = _collectInput();
    await BallisticCompareRefStore.save(snap);
    if (!mounted) return;
    setState(() {
      _profileCompareRef = snap;
      _profileCompareSummary = _formatCompareRefSummary(snap);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Referans profil kaydedildi (Vo/BC/nişan).')),
    );
  }

  Future<void> _compareProfilesDialog() async {
    final ref = _profileCompareRef;
    if (ref == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Önce «Referans» ile mevcut formu yakalayın.')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    final cur = _collectInput();
    final outA = BallisticsEngine.solve(ref.withShotConditionsFrom(cur));
    final outB = BallisticsEngine.solve(cur);
    if (!mounted) return;
    String d1(num x) => x.toStringAsFixed(1);
    String d2(num x) => x.toStringAsFixed(2);
    String d0(num x) => x.toStringAsFixed(0);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Profil karşılaştırması'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: DataTable(
              columnSpacing: 12,
              columns: const [
                DataColumn(label: Text('')),
                DataColumn(label: Text('Referans')),
                DataColumn(label: Text('Güncel')),
                DataColumn(label: Text('Δ')),
              ],
              rows: [
                DataRow(
                  cells: [
                    const DataCell(Text('Elev mil')),
                    DataCell(Text(d2(outA.dropMil))),
                    DataCell(Text(d2(outB.dropMil))),
                    DataCell(Text(d2(outB.dropMil - outA.dropMil))),
                  ],
                ),
                DataRow(
                  cells: [
                    const DataCell(Text('Elev MOA')),
                    DataCell(Text(d2(outA.dropMoa))),
                    DataCell(Text(d2(outB.dropMoa))),
                    DataCell(Text(d2(outB.dropMoa - outA.dropMoa))),
                  ],
                ),
                DataRow(
                  cells: [
                    const DataCell(Text('Wind mil')),
                    DataCell(Text(d2(outA.windMil))),
                    DataCell(Text(d2(outB.windMil))),
                    DataCell(Text(d2(outB.windMil - outA.windMil))),
                  ],
                ),
                DataRow(
                  cells: [
                    const DataCell(Text('Wind MOA')),
                    DataCell(Text(d2(outA.windMoa))),
                    DataCell(Text(d2(outB.windMoa))),
                    DataCell(Text(d2(outB.windMoa - outA.windMoa))),
                  ],
                ),
                DataRow(
                  cells: [
                    const DataCell(Text('LatΣ mil')),
                    DataCell(Text(d2(outA.combinedLateralMil))),
                    DataCell(Text(d2(outB.combinedLateralMil))),
                    DataCell(Text(d2(outB.combinedLateralMil - outA.combinedLateralMil))),
                  ],
                ),
                DataRow(
                  cells: [
                    const DataCell(Text('LatΣ MOA')),
                    DataCell(Text(d2(outA.combinedLateralMoa))),
                    DataCell(Text(d2(outB.combinedLateralMoa))),
                    DataCell(Text(d2(outB.combinedLateralMoa - outA.combinedLateralMoa))),
                  ],
                ),
                DataRow(
                  cells: [
                    const DataCell(Text('Lead mil')),
                    DataCell(Text(d2(outA.leadMil))),
                    DataCell(Text(d2(outB.leadMil))),
                    DataCell(Text(d2(outB.leadMil - outA.leadMil))),
                  ],
                ),
                DataRow(
                  cells: [
                    const DataCell(Text('Lead MOA')),
                    DataCell(Text(d2(outA.leadMoa))),
                    DataCell(Text(d2(outB.leadMoa))),
                    DataCell(Text(d2(outB.leadMoa - outA.leadMoa))),
                  ],
                ),
                DataRow(
                  cells: [
                    const DataCell(Text('TOF ms')),
                    DataCell(Text(d0(outA.timeOfFlightMs))),
                    DataCell(Text(d0(outB.timeOfFlightMs))),
                    DataCell(Text(d0(outB.timeOfFlightMs - outA.timeOfFlightMs))),
                  ],
                ),
                DataRow(
                  cells: [
                    const DataCell(Text('MV m/s')),
                    DataCell(Text(d1(outA.adjustedMuzzleVelocityMps))),
                    DataCell(Text(d1(outB.adjustedMuzzleVelocityMps))),
                    DataCell(Text(d1(outB.adjustedMuzzleVelocityMps - outA.adjustedMuzzleVelocityMps))),
                  ],
                ),
                DataRow(
                  cells: [
                    const DataCell(Text('El. klik')),
                    DataCell(Text(d2(outA.clicks))),
                    DataCell(Text(d2(outB.clicks))),
                    DataCell(Text(d2(outB.clicks - outA.clicks))),
                  ],
                ),
                DataRow(
                  cells: [
                    const DataCell(Text('Wnd klik')),
                    DataCell(Text(d2(outA.windClicks))),
                    DataCell(Text(d2(outB.windClicks))),
                    DataCell(Text(d2(outB.windClicks - outA.windClicks))),
                  ],
                ),
                DataRow(
                  cells: [
                    const DataCell(Text('Lead klik')),
                    DataCell(Text(d2(outA.leadClicks))),
                    DataCell(Text(d2(outB.leadClicks))),
                    DataCell(Text(d2(outB.leadClicks - outA.leadClicks))),
                  ],
                ),
                DataRow(
                  cells: [
                    const DataCell(Text('Lat klik')),
                    DataCell(Text(d2(outA.combinedLateralClicks))),
                    DataCell(Text(d2(outB.combinedLateralClicks))),
                    DataCell(Text(d2(outB.combinedLateralClicks - outA.combinedLateralClicks))),
                  ],
                ),
                DataRow(
                  cells: [
                    const DataCell(Text('Düşüş cm')),
                    DataCell(Text(d1(outA.verticalHoldDeltaMeters * 100))),
                    DataCell(Text(d1(outB.verticalHoldDeltaMeters * 100))),
                    DataCell(Text(d1((outB.verticalHoldDeltaMeters - outA.verticalHoldDeltaMeters) * 100))),
                  ],
                ),
                DataRow(
                  cells: [
                    const DataCell(Text('Rüzgâr cm')),
                    DataCell(Text(d1(outA.windLateralDeltaMeters * 100))),
                    DataCell(Text(d1(outB.windLateralDeltaMeters * 100))),
                    DataCell(Text(d1((outB.windLateralDeltaMeters - outA.windLateralDeltaMeters) * 100))),
                  ],
                ),
                DataRow(
                  cells: [
                    const DataCell(Text('Öncü cm')),
                    DataCell(Text(d1(outA.leadLateralDeltaMeters * 100))),
                    DataCell(Text(d1(outB.leadLateralDeltaMeters * 100))),
                    DataCell(Text(d1((outB.leadLateralDeltaMeters - outA.leadLateralDeltaMeters) * 100))),
                  ],
                ),
                DataRow(
                  cells: [
                    const DataCell(Text('Yanal cm')),
                    DataCell(Text(d1(outA.combinedLateralDeltaMeters * 100))),
                    DataCell(Text(d1(outB.combinedLateralDeltaMeters * 100))),
                    DataCell(
                      Text(d1((outB.combinedLateralDeltaMeters - outA.combinedLateralDeltaMeters) * 100)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final csv = profileCompareToCsv(refOut: outA, curOut: outB);
              await shareCsvText(csv, filename: 'blue_viper_profile_compare.csv');
            },
            child: const Text('CSV paylaş'),
          ),
          TextButton(
            onPressed: () async {
              await shareProfileCompareXlsx(
                refOut: outA,
                curOut: outB,
                filename: 'blue_viper_profile_compare.xlsx',
              );
            },
            child: const Text('Excel (xlsx)'),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Kapat')),
        ],
      ),
    );
  }

  Future<void> _batchRangeListDialog() async {
    final ctrl = TextEditingController(text: _lastBatchRangesCsv);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Menzil listesi (toplu hesap)'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Menziller (m)',
            hintText: 'Virgül veya boşluk ile ayırın: 300, 450, 600',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hesapla')),
        ],
      ),
    );
    if (ok != true) return;
    final raw = ctrl.text.replaceAll(';', ',').split(RegExp(r'[\s,]+'));
    final ranges = <int>[];
    for (final p in raw) {
      final t = p.trim();
      if (t.isEmpty) continue;
      final v = int.tryParse(t);
      if (v == null || v < 1) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Geçersiz menzil: "$t"')),
        );
        return;
      }
      ranges.add(v);
    }
    ranges.sort();
    final uniq = <int>{...ranges}.toList()..sort();
    if (uniq.isEmpty) return;
    const kMaxBatchDistances = 120;
    if (uniq.length > kMaxBatchDistances) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('En fazla $kMaxBatchDistances farklı menzil girin (şu an ${uniq.length}).'),
        ),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    _lastBatchRangesCsv = ctrl.text.trim();
    unawaited(
      BallisticsRangePrefs.save(
        primaryText: _distanceCtrl.text,
        tableStartText: _tableStartCtrl.text,
        tableEndText: _tableEndCtrl.text,
        tableStepText: _tableStepCtrl.text,
        batchCsv: _lastBatchRangesCsv,
      ),
    );
    final template = _collectInput();
    final rows = <(int, BallisticsSolveOutput)>[];
    for (final r in uniq) {
      final input = template.withTargetGeometry(
        distanceMeters: r.toDouble(),
        targetElevationDeltaMeters: template.targetElevationDeltaMeters,
      );
      rows.add((r, BallisticsEngine.solve(input)));
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Toplu menzil özeti'),
        content: SizedBox(
          width: double.maxFinite,
          height: 460,
          child: Scrollbar(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  columnSpacing: 14,
                  columns: const [
                    DataColumn(label: Text('m')),
                    DataColumn(label: Text('Elev mil')),
                    DataColumn(label: Text('Wind mil')),
                    DataColumn(label: Text('Lead mil')),
                    DataColumn(label: Text('LatΣ mil')),
                    DataColumn(label: Text('E MOA')),
                    DataColumn(label: Text('W MOA')),
                    DataColumn(label: Text('Lead MOA')),
                    DataColumn(label: Text('L MOA')),
                    DataColumn(label: Text('El. klik')),
                    DataColumn(label: Text('Wnd klik')),
                    DataColumn(label: Text('Lead klik')),
                    DataColumn(label: Text('Lat klik')),
                    DataColumn(label: Text('d cm')),
                    DataColumn(label: Text('w cm')),
                    DataColumn(label: Text('ön cm')),
                    DataColumn(label: Text('L cm')),
                    DataColumn(label: Text('TOF ms')),
                  ],
                  rows: [
                    for (final (r, o) in rows)
                      DataRow(
                        cells: [
                          DataCell(Text('$r')),
                          DataCell(Text(o.dropMil.toStringAsFixed(2))),
                          DataCell(Text(o.windMil.toStringAsFixed(2))),
                          DataCell(Text(o.leadMil.toStringAsFixed(2))),
                          DataCell(Text(o.combinedLateralMil.toStringAsFixed(2))),
                          DataCell(Text(o.dropMoa.toStringAsFixed(2))),
                          DataCell(Text(o.windMoa.toStringAsFixed(2))),
                          DataCell(Text(o.leadMoa.toStringAsFixed(2))),
                          DataCell(Text(o.combinedLateralMoa.toStringAsFixed(2))),
                          DataCell(Text(o.clicks.toStringAsFixed(2))),
                          DataCell(Text(o.windClicks.toStringAsFixed(2))),
                          DataCell(Text(o.leadClicks.toStringAsFixed(2))),
                          DataCell(Text(o.combinedLateralClicks.toStringAsFixed(2))),
                          DataCell(Text((o.verticalHoldDeltaMeters * 100).toStringAsFixed(0))),
                          DataCell(Text((o.windLateralDeltaMeters * 100).toStringAsFixed(0))),
                          DataCell(Text((o.leadLateralDeltaMeters * 100).toStringAsFixed(0))),
                          DataCell(Text((o.combinedLateralDeltaMeters * 100).toStringAsFixed(0))),
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
          TextButton(
            onPressed: () async {
              final csv = multiRangeSolveToCsv(rows);
              await shareCsvText(csv, filename: 'blue_viper_batch_ranges.csv');
            },
            child: const Text('CSV paylaş'),
          ),
          TextButton(
            onPressed: () async {
              final tableRows = [
                for (final (r, o) in rows) RangeTableRow.fromSolveOutput(r, o),
              ];
              await shareRangeTableXlsx(
                rows: tableRows,
                filename: 'blue_viper_batch_ranges.xlsx',
              );
            },
            child: const Text('Excel (xlsx)'),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Kapat')),
        ],
      ),
    );
  }

  void _applyWeaponBallisticPreset(WeaponType w) {
    final p = _weaponPresetMap[w.id] ?? _caliberFallbackPresetMap[w.caliber];
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
          _barrelInchesCtrl.text = (v.barrelInches ?? 0) > 0
              ? v.barrelInches!.toStringAsFixed(1)
              : '';
          return;
        }
      }
    }
    if (!_chronoVoLocked) {
      _mvCtrl.text = p.muzzleVelocityMps.toStringAsFixed(0);
    }
    final bcText = _bcKind == BcKind.g7
        ? (p.ballisticCoefficientG7 ?? estimateG7FromG1(p.ballisticCoefficientG1))
        : p.ballisticCoefficientG1;
    _bcCtrl.text = bcText.toString();
  }

  void _applyWeaponCatalogUiDefaults(WeaponType w) {
    final z = w.defaultZeroRangeM;
    if (z != null && z > 0) _zeroRangeCtrl.text = z.toStringAsFixed(0);
    final sh = w.defaultSightHeightCm;
    if (sh != null && sh > 0) _sightHcmCtrl.text = sh.toStringAsFixed(1);
    final tw = w.twistInchesPerTurn;
    if (tw != null && tw > 0) _twistInCtrl.text = tw.toString();
    final trh = w.twistRightHanded;
    if (trh != null) _twistRightHanded = trh;
    final bl = w.barrelLengthInches;
    if (bl != null && bl > 0) {
      _barrelInchesCtrl.text = bl.toStringAsFixed(1);
      _selectNearestBarrelInches(bl);
    }
  }

  void _onWeaponChanged(WeaponType? w) {
    setState(() {
      _selectedWeapon = w;
      if (w != null) {
        _weaponNameCtrl.text = '${w.name} (${w.caliber})';
        _applyWeaponBallisticPreset(w);
        _applyWeaponCatalogUiDefaults(w);
      }
    });
  }

  void _onScopeChanged(ScopeType? s) {
    setState(() {
      _selectedScope = s;
      if (s != null) {
        if (s.defaultFirstFocalPlane != null) {
          _reticleFfp = s.defaultFirstFocalPlane!;
        }
        _clickUnit = s.clickUnit;
        _clickValueCtrl.text = s.clickValue.toString();
        final maxZ = s.maxMagnification;
        final minZ = s.minMagnification;
        if (maxZ != null && maxZ > 0) {
          _scopeMagCtrl.text = maxZ.toString();
        } else if (minZ != null && minZ > 0) {
          _scopeMagCtrl.text = minZ.toString();
        }
        final refZ = s.referenceMagnification;
        if (refZ != null && refZ > 0) {
          _refMagCtrl.text = refZ.toString();
        }
      }
    });
    if (s != null) unawaited(_syncReticleFromScope(s));
  }

  void _applyBarrelVariant(AmmoBarrelVariant v) {
    if (!_chronoVoLocked) {
      _mvCtrl.text = v.muzzleVelocityMps.toStringAsFixed(0);
    }
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
        _barrelInchesCtrl.text = (v.barrelInches ?? 0) > 0
            ? v.barrelInches!.toStringAsFixed(1)
            : '';
        _applyBarrelVariant(v);
      } else {
        _selectedAmmoVariantId = null;
        _barrelInchesCtrl.text = '';
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
    if (inches > 0) _barrelInchesCtrl.text = inches.toStringAsFixed(1);
    _applyBarrelVariant(best);
  }

  void _applyManualBarrelInches() {
    final t = _barrelInchesCtrl.text.trim();
    final inches = double.tryParse(t.replaceAll(',', '.'));
    if (inches == null || inches <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçerli namlu uzunluğu girin (inç).')),
      );
      return;
    }
    setState(() => _selectNearestBarrelInches(inches));
  }

  Future<void> _showAllWeaponBarrelLengthsDialog() async {
    final rows = [..._weapons]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Silah / namlu inç listesi'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Silah')),
                DataColumn(label: Text('Kalibre')),
                DataColumn(label: Text('Namlu (in)')),
              ],
              rows: [
                for (final w in rows)
                  DataRow(
                    cells: [
                      DataCell(Text(w.name)),
                      DataCell(Text(w.caliber)),
                      DataCell(Text(w.barrelLengthInches?.toStringAsFixed(1) ?? '—')),
                    ],
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Kapat')),
        ],
      ),
    );
  }

  void _applyCatalogBandMuzzleVelocity() {
    final v = _activeAmmoVariant;
    if (v == null) return;
    setState(() {
      _chronoVoLocked = false;
      _mvCtrl.text = v.muzzleVelocityMps.toStringAsFixed(0);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Vo katalog bandına alındı: ${v.muzzleVelocityMps.toStringAsFixed(0)} m/s')),
    );
  }

  Future<void> _addWeaponDialog() async {
    double? pInStr(String s) {
      final t = s.trim();
      if (t.isEmpty) return null;
      final v = double.tryParse(t.replaceAll(',', '.'));
      if (v == null || !v.isFinite || v <= 0) return null;
      return v;
    }

    final v = await Navigator.of(context).push<ManualWeaponFormValues>(
      MaterialPageRoute<ManualWeaponFormValues>(
        fullscreenDialog: true,
        builder: (ctx) => const ManualWeaponEntryPage(),
      ),
    );
    if (v == null || !mounted) return;

    final twistParsed = pInStr(v.twistInchesPerTurn);
    final noteExtras = <String>[
      if (v.zeroElevClicks.isNotEmpty) 'Sıfır dikey klik (not): ${v.zeroElevClicks}',
      if (v.zeroWindClicks.isNotEmpty) 'Sıfır yatay klik (not): ${v.zeroWindClicks}',
      if (v.reticleHint.isNotEmpty) 'Retikül: ${v.reticleHint}',
    ];
    final mergedWeaponNotes = [
      if (v.notes.isNotEmpty) v.notes,
      ...noteExtras,
    ].join('\n');
    final item = WeaponType(
      id: 'user_weapon_${DateTime.now().millisecondsSinceEpoch}',
      name: v.name,
      caliber: v.caliber,
      role: v.role.isEmpty ? null : v.role,
      region: v.region.isEmpty ? null : v.region,
      barrelLengthInches: pInStr(v.barrelInches),
      notes: mergedWeaponNotes.isEmpty ? null : mergedWeaponNotes,
      defaultZeroRangeM: pInStr(v.zeroRangeM),
      defaultSightHeightCm: pInStr(v.sightHeightCm),
      twistInchesPerTurn: twistParsed,
      twistRightHanded: twistParsed != null ? v.twistRh : null,
    );
    final existing = await UserCatalogStore.loadWeapons();
    final custom = existing.where((e) => e.id.startsWith('user_weapon_')).toList()..add(item);
    await UserCatalogStore.saveWeapons(custom);
    await _loadUserCatalog();
    if (!mounted) return;
    final addedId = item.id;
    final g = v.grain.trim().isEmpty ? null : double.tryParse(v.grain.replaceAll(',', '.'));
    final ci = v.bulletCalIn.trim().isEmpty ? null : double.tryParse(v.bulletCalIn.replaceAll(',', '.'));
    setState(() {
      WeaponType? pick;
      for (final w in _weapons) {
        if (w.id == addedId) {
          pick = w;
          break;
        }
      }
      if (pick != null) {
        _selectedWeapon = pick;
        _weaponNameCtrl.text = '${pick.name} (${pick.caliber})';
        _applyWeaponBallisticPreset(pick);
        _applyWeaponCatalogUiDefaults(pick);
      }
      if (g != null && g > 0) _grainCtrl.text = g.toStringAsFixed(0);
      if (ci != null && ci > 0) _calInCtrl.text = ci.toString();
      final mvForm = double.tryParse(v.muzzleVelocityMps.replaceAll(',', '.'));
      if (mvForm != null && mvForm > 0) {
        _mvCtrl.text = mvForm.toStringAsFixed(0);
        _chronoVoLocked = true;
      }
      final bcForm = double.tryParse(v.ballisticCoefficient.replaceAll(',', '.'));
      if (bcForm != null && bcForm > 0) {
        _bcCtrl.text = bcForm.toString();
        _bcKind = v.bcIsG7 ? BcKind.g7 : BcKind.g1;
      }
    });
  }

  Future<void> _addScopeDialog() async {
    double? pMagStr(String s) {
      final t = s.trim();
      if (t.isEmpty) return null;
      final v = double.tryParse(t.replaceAll(',', '.'));
      if (v == null || !v.isFinite || v <= 0) return null;
      return v;
    }

    final form = await Navigator.of(context).push<ManualScopeFormValues>(
      MaterialPageRoute<ManualScopeFormValues>(
        fullscreenDialog: true,
        builder: (ctx) => const ManualScopeEntryPage(),
      ),
    );
    if (form == null || !mounted) return;
    final val = double.tryParse(form.clickValueText.replaceAll(',', '.'));
    if (val == null || val <= 0) return;
    double? pCmOpt(String s) {
      final t = s.trim();
      if (t.isEmpty) return null;
      final x = double.tryParse(t.replaceAll(',', '.'));
      if (x == null || !x.isFinite || x <= 0) return null;
      return x;
    }

    final scopeNotes = [
      if (form.reticleCode.isNotEmpty) 'Retikül: ${form.reticleCode}',
      if (form.notes.isNotEmpty) form.notes,
    ].join('\n');

    final item = ScopeType(
      id: 'user_scope_${DateTime.now().millisecondsSinceEpoch}',
      name: form.name,
      clickUnit: form.clickUnit,
      clickValue: val,
      minMagnification: pMagStr(form.minMag),
      maxMagnification: pMagStr(form.maxMag),
      referenceMagnification: pMagStr(form.refMag),
      notes: scopeNotes.isEmpty ? null : scopeNotes,
      defaultFirstFocalPlane: form.firstFocalPlane,
      verticalClickCmPer100m: pCmOpt(form.verticalClickCmPer100m),
      horizontalClickCmPer100m: pCmOpt(form.horizontalClickCmPer100m),
    );
    final existing = await UserCatalogStore.loadScopes();
    final custom = existing.where((e) => e.id.startsWith('user_scope_')).toList()..add(item);
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
    final existing = await UserCatalogStore.loadAmmos();
    final custom = existing.where((e) => e.id.startsWith('user_ammo_')).toList()..add(item);
    await UserCatalogStore.saveAmmos(custom);
    await _loadUserCatalog();
  }

  Widget _eqLineStreLock(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              k,
              style: TextStyle(
                color: StreLockBalColors.fieldText.withValues(alpha: 0.72),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: const TextStyle(
                color: StreLockBalColors.fieldText,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _equipmentSummaryCard(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Material(
      color: StreLockBalColors.fieldFill,
      elevation: 3,
      shadowColor: Colors.black45,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _tabController.index = 1),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'EKİPMAN ÖZETİ',
                      style: tt.labelSmall?.copyWith(
                        color: StreLockBalColors.headerOrange,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.05,
                      ),
                    ),
                  ),
                  Icon(Icons.edit_outlined, size: 18, color: StreLockBalColors.label.withValues(alpha: 0.7)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Mühimmat / dürbün değiştirmek için dokunun — Silah sekmesi açılır.',
                style: tt.bodySmall?.copyWith(
                  color: StreLockBalColors.label.withValues(alpha: 0.75),
                  fontSize: 11,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 8),
              _eqLineStreLock('Silah', _weaponNameCtrl.text.isEmpty ? '—' : _weaponNameCtrl.text),
              _eqLineStreLock('Dürbün', _selectedScope?.name ?? '—'),
              _eqLineStreLock('Mühimmat', _selectedAmmo?.name ?? '—'),
              _eqLineStreLock('Vo', '${_mvCtrl.text} m/s'),
              _eqLineStreLock('BC', '${_bcCtrl.text} (${_bcKind.label})'),
              _eqLineStreLock('Sıfır', '${_zeroRangeCtrl.text} m · nişangâh ${_sightHcmCtrl.text} cm'),
            ],
          ),
        ),
      ),
    );
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
      _equipmentSummaryCard(context),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: Text(
              'Atış çözümü',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 0.2),
            ),
          ),
          IconButton(
            tooltip: 'Dönüştürücüler',
            icon: const Icon(Icons.apps_outlined),
            onPressed: () => unawaited(_openConvertersHub()),
          ),
          PopupMenuButton<void>(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (ctx) => [
              PopupMenuItem<void>(
                child: const Text('Sıfır / nişan sihirbazı (sapma → tık)'),
                onTap: () => Future<void>.delayed(
                  Duration.zero,
                  () {
                    if (context.mounted) unawaited(_showZeroWizardDialog());
                  },
                ),
              ),
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
        '${_weaponNameCtrl.text} · ${_selectedScope?.name ?? "—"} · ${_selectedAmmo?.name ?? "—"} · '
        'Vo ${_mvCtrl.text} m/s · BC ${_bcCtrl.text} · ${_bcKind.label}',
        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant, height: 1.35),
      ),
      FilledButton.tonalIcon(
        onPressed: () => unawaited(_showSavedWeaponProfilesSheet()),
        icon: const Icon(Icons.library_books_outlined, size: 20),
        label: const Text('Kayıtlı silahlarım'),
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(46),
          alignment: Alignment.centerLeft,
        ),
      ),
      const SizedBox(height: 6),
      TextButton.icon(
        onPressed: () => setState(() => _tabController.index = 1),
        icon: const Icon(Icons.tune_rounded, size: 18),
        label: const Text('Katalog: silah · dürbün · mühimmat (Silah sekmesi)'),
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
        StreLockKestrelMetWindDial(
          windFromDegrees:
              double.tryParse(_windFromCtrl.text.replaceAll(',', '.')) ?? 270.0,
          onWindFromChanged: (d) => setState(() => _windFromCtrl.text = d.toStringAsFixed(0)),
          windSpeedMps: _windSpeedVecCtrl.text.trim().isEmpty
              ? '0.0'
              : _windSpeedVecCtrl.text.trim().replaceAll(',', '.'),
          temperatureLine: _kestrelTemperatureLine(),
          pressureLine: _kestrelPressureLine(),
          humidityLine: _kestrelHumidityLine(),
          densityAltitudeLine: _kestrelDensityAltitudeLine(),
          useMetWindVector: _useMetWindVector,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _numField(
                _tempCtrl,
                'Sıcaklık (ISA)',
                suffix: _tempUnit == _TempUnit.c ? '°C' : '°F',
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 110,
              child: DropdownButtonFormField<_TempUnit>(
                key: ValueKey(_tempUnit),
                initialValue: _tempUnit,
                decoration: const InputDecoration(labelText: 'Birim', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: _TempUnit.c, child: Text('°C')),
                  DropdownMenuItem(value: _TempUnit.f, child: Text('°F')),
                ],
                onChanged: (v) => setState(() => _tempUnit = v ?? _tempUnit),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _numField(
                _pressureCtrl,
                'Basınç',
                suffix: switch (_pressureUnit) {
                  _PressureUnit.hpa => 'hPa',
                  _PressureUnit.inHg => 'inHg',
                  _PressureUnit.mmHg => 'mmHg',
                  _PressureUnit.psi => 'psi',
                },
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 110,
              child: DropdownButtonFormField<_PressureUnit>(
                key: ValueKey(_pressureUnit),
                initialValue: _pressureUnit,
                decoration: const InputDecoration(labelText: 'Birim', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: _PressureUnit.hpa, child: Text('hPa')),
                  DropdownMenuItem(value: _PressureUnit.inHg, child: Text('inHg')),
                  DropdownMenuItem(value: _PressureUnit.mmHg, child: Text('mmHg')),
                  DropdownMenuItem(value: _PressureUnit.psi, child: Text('psi')),
                ],
                onChanged: (v) => setState(() => _pressureUnit = v ?? _pressureUnit),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Dahili barometre (basınç)'),
          subtitle: const Text('Destekleyen telefonlarda sensör akışı; değer hPa olarak forma yazılır.'),
          value: _useInternalBarometer,
          onChanged: (on) => unawaited(_setInternalBarometer(on)),
        ),
        const SizedBox(height: 4),
        FilledButton.icon(
          onPressed: () => unawaited(_applyMeteoToForm()),
          icon: const Icon(Icons.public),
          label: const Text('METEO (konumdan Open-Meteo)'),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Enerji: ft·lbf göster'),
          subtitle: const Text('Kapalıyken Joule; Ek veriler ve çözüm özeti buna uyumlu.'),
          value: _energyFtLbf,
          onChanged: (v) {
            setState(() => _energyFtLbf = v);
            unawaited(_persistBallisticsDisplayPrefs());
          },
        ),
        const SizedBox(height: 8),
        _numField(_rhCtrl, 'Göreli nem', suffix: '%'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _daCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText:
                'Yoğunluk irtifa (opsiyonel, ${_heightUnit == _LengthUnit.m ? 'm' : 'ft'})',
            helperText: 'Boş: P/T/nem; dolu: basınç ISA’dan türetilir',
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _numField(
                _elevDeltaCtrl,
                'Hedef rakım farkı (hedef−atıcı, +yukarı)',
                suffix: _heightUnit == _LengthUnit.m ? 'm' : 'ft',
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 110,
              child: DropdownButtonFormField<_LengthUnit>(
                key: ValueKey(_heightUnit),
                initialValue: _heightUnit,
                decoration: const InputDecoration(labelText: 'Yükseklik', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: _LengthUnit.m, child: Text('m')),
                  DropdownMenuItem(value: _LengthUnit.ft, child: Text('ft')),
                ],
                onChanged: (v) => setState(() => _heightUnit = v ?? _heightUnit),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _numField(
                _slopeCtrl,
                'Eğim (Δh yoksa)',
                suffix: switch (_slopeUnit) {
                  _SlopeUnit.deg => '°',
                  _SlopeUnit.percent => '%',
                  _SlopeUnit.cos => 'cos θ',
                },
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 110,
              child: DropdownButtonFormField<_SlopeUnit>(
                key: ValueKey(_slopeUnit),
                initialValue: _slopeUnit,
                decoration: const InputDecoration(labelText: 'Eğim', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: _SlopeUnit.deg, child: Text('°')),
                  DropdownMenuItem(value: _SlopeUnit.percent, child: Text('%')),
                  DropdownMenuItem(value: _SlopeUnit.cos, child: Text('cos')),
                ],
                onChanged: (v) => setState(() => _slopeUnit = v ?? _slopeUnit),
              ),
            ),
          ],
        ),
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
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Yan rüzgâr işaretini ters çevir'),
          subtitle: const Text(
            'Açıksa çözüme giren yan rüzgâr bileşeni çarpan −1 alır (bazı dürbün / eğitim tanımlarıyla eşlemek için).',
          ),
          value: _invertCrossWindSign,
          onChanged: (v) async {
            setState(() => _invertCrossWindSign = v);
            await _persistBallisticsDisplayPrefs();
          },
        ),
      ]),
      _strelokSection(context, 'KAYITLI SAHNE PRESETLERİ', [
        Text(
          'Ortam, rüzgâr ve barut sıcaklığı eğrisi burada ve Silah sekmesinde doldurulur. '
          'Aynı silahla farklı sahalarda farklı sahne kaydı seçin; silah profilinden bağımsızdır.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.35),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Tüm sahneleri göster'),
          subtitle: Text(
            'Kapalıyken: yalnızca genel veya şu anki silah defteri satırına bağlı sahneler.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          value: _showAllSceneBookEntries,
          onChanged: (v) => setState(() => _showAllSceneBookEntries = v),
        ),
        const SizedBox(height: 6),
        if (ShotScenePresetBookStore.entries.value.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Henüz sahne yok. Ortam/rüzgâr/barutu doldurup «Sahneyi kaydet»e basın.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          )
        else if (_visibleScenePresets().isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Bu görünümde liste boş. «Tüm sahneleri göster» açın veya silah defterinden bir profil seçin.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
            ),
          ),
        ..._visibleScenePresets().map((e) {
          final curSid = ShotScenePresetBookStore.current.value?.id;
          final selected =
              (e.id.isNotEmpty && e.id == (_activeScenePresetId ?? curSid)) ||
                  (_activeScenePresetId == null && e.id == curSid);
          final sum = e.summaryLine;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Material(
              color: selected
                  ? Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.35)
                  : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => unawaited(_applyBookSceneEntry(e)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                            [
                              if (e.linkedWeaponProfileId != null && e.linkedWeaponProfileId!.isNotEmpty)
                                'Silah id: ${e.linkedWeaponProfileId}',
                              ?sum,
                            ].join('\n'),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Sil',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Sahneyi sil'),
                              content: Text('"${e.name}" silinsin mi?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('İptal'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Sil'),
                                ),
                              ],
                            ),
                          );
                          if (ok == true && mounted) {
                            await _deleteScenePresetEntry(e.id);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _startNewScenePreset,
          icon: const Icon(Icons.note_add_outlined),
          label: const Text('Yeni sahne satırı'),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _saveShotScenePreset,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Sahneyi kaydet'),
        ),
      ]),
      _strelokSection(context, 'NİŞAN / KLİK', [
        Text(
          '${_sightHcmCtrl.text} cm · ${_zeroRangeCtrl.text} m · ${_clickUnit.label} ${_clickValueCtrl.text}',
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        if (_selectedScope != null &&
            (_selectedScope!.verticalClickCmPer100m != null ||
                _selectedScope!.horizontalClickCmPer100m != null))
          Text(
            'Dürbün (katalog): '
            'V ${_selectedScope!.verticalClickCmPer100m?.toStringAsFixed(2) ?? '—'} · '
            'H ${_selectedScope!.horizontalClickCmPer100m?.toStringAsFixed(2) ?? '—'} cm/klik @100 m',
            style: tt.bodySmall?.copyWith(color: StreLockBalColors.titleBlue, height: 1.3),
          ),
        TextButton(
          onPressed: () => setState(() => _tabController.index = 1),
          child: const Text('Nişan ve klik değerlerini düzenle'),
        ),
      ]),
      _strelokSection(context, 'ATIŞ YOLU DOĞRULAMA (KLİK → MV / BC)', [
        Text(
          'Sahadaki dikey düzeltmeyi programa işleyin: ya çıkış hızını (Vo) ya da balistik katsayıyı (BC) '
          'gözlenen düşüşe göre otomatik uyarlayın. Üstteki menzil ve Ana sekmedeki ortam değerleri kullanılır; '
          'klik girdisi için «Silah» sekmesinde klik birimi/değeri doğru olmalıdır.',
          style: tt.bodySmall?.copyWith(height: 1.35),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => unawaited(_truingDialog(initialTuneMv: true)),
                icon: const Icon(Icons.speed, size: 20),
                label: const Text('Vo (MV) truing'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => unawaited(_truingDialog(initialTuneMv: false)),
                icon: const Icon(Icons.timeline, size: 20),
                label: const Text('BC truing'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: () => unawaited(_truingDialog()),
          icon: const Icon(Icons.tune, size: 20),
          label: const Text('İleri… (mil / MOA / klik seçimi)'),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
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
          OutlinedButton.icon(
            onPressed: _result == null ? null : () => unawaited(_openExtraDataPage()),
            icon: const Icon(Icons.info_outline),
            label: const Text('Ek veriler'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _rangeTableDialog,
            icon: const Icon(Icons.table_rows, size: 20),
            label: const Text('Menzil tablosu'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => unawaited(_captureProfileCompareRef()),
                  icon: const Icon(Icons.flag_outlined, size: 20),
                  label: const Text('Referans'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _profileCompareRef == null
                      ? null
                      : () => unawaited(_compareProfilesDialog()),
                  icon: const Icon(Icons.compare_arrows, size: 20),
                  label: const Text('Karşılaştır'),
                ),
              ),
            ],
          ),
          if (_profileCompareSummary.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    'Kayıtlı referans: $_profileCompareSummary',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
                TextButton(
                  onPressed: () => unawaited(_applyCompareRefToForm()),
                  child: const Text('Forma yükle'),
                ),
                TextButton(
                  onPressed: () => unawaited(_clearProfileCompareRef()),
                  child: const Text('Sil'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => unawaited(_batchRangeListDialog()),
            icon: const Icon(Icons.format_list_numbered, size: 20),
            label: const Text('Menzil listesi (toplu)'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
          ),
        ],
      ),
      const SizedBox(height: 14),
      if (_result != null) ...[
        _StrelokHeroResult(
          result: _result!,
          clickUnit: _clickUnit,
          clickValue: _parse(_clickValueCtrl.text),
          streLockStyle: true,
          rangeMeters: _solutionRangeM,
          zeroElevCompClicks: WeaponProfileStore.current.value?.zeroElevCompensationClicks ?? 0,
          zeroWindCompClicks: WeaponProfileStore.current.value?.zeroWindCompensationClicks ?? 0,
          showEnergyFtLbf: _energyFtLbf,
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
      const SizedBox(height: 4),
      Text(
        'Preset sürümü: $_activePresetVersion · kaynak: $_activePresetSource',
        style: tt.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      if (_previousPresetManifest != null) ...[
        const SizedBox(height: 2),
        Text(
          'Geri alınabilir: ${_previousPresetManifest!.dataVersion} · ${_previousPresetManifest!.source}',
          style: tt.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
          ),
        ),
      ],
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerRight,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [
            OutlinedButton.icon(
              onPressed: (_previousPresetManifest == null || _isUpdatingRemotePresets)
                  ? null
                  : () => unawaited(_rollbackBallisticPresets()),
              icon: const Icon(Icons.undo),
              label: const Text('Önceki sürüm'),
            ),
            OutlinedButton.icon(
              onPressed: _isUpdatingRemotePresets
                  ? null
                  : () => unawaited(_updateBallisticPresetsFromRemote()),
              icon: _isUpdatingRemotePresets
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_download_outlined),
              label: Text(_isUpdatingRemotePresets ? 'Güncelleniyor...' : 'Preset güncelle'),
            ),
          ],
        ),
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
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [
            OutlinedButton.icon(
              onPressed: _showAllWeaponBarrelLengthsDialog,
              icon: const Icon(Icons.table_rows_outlined),
              label: const Text('Namlu inç listesi'),
            ),
            OutlinedButton.icon(
              onPressed: _addWeaponDialog,
              icon: const Icon(Icons.add),
              label: const Text('Silah ekle'),
            ),
          ],
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
              final v = _selectedAmmo!.variantById(id);
              _barrelInchesCtrl.text = (v.barrelInches ?? 0) > 0
                  ? v.barrelInches!.toStringAsFixed(1)
                  : '';
              _applyBarrelVariant(v);
            });
          },
        ),
      if (_selectedAmmo != null && _selectedAmmo!.variants.length > 1) const SizedBox(height: 8),
      if (_selectedAmmo != null) ...[
        Row(
          children: [
            Expanded(
              child: _numField(
                _barrelInchesCtrl,
                'Namlu uzunluğu (inç - manuel)',
                suffix: 'in',
                allowEmpty: true,
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: _applyManualBarrelInches,
              icon: const Icon(Icons.sync_alt, size: 18),
              label: const Text('Banda uygula'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Girilen inç değeri mühimmat varyantına en yakın banda eşlenir ve profilde saklanır.',
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
      const SizedBox(height: 6),
      Text(
        'G1/G7 dışı model için: Balistik Ekler > Özel sürüklenme i(Mach) tablosu.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 8),
      _numField(_mvCtrl, 'Çıkış hızı (m/s - tablo öncesi)', suffix: 'm/s'),
      const SizedBox(height: 4),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Saha Vo kilidi'),
        subtitle: const Text(
          'Açıkken katalog namlu bandı (16/20/24) veya mühimmat değişimi çıkış hızını değiştirmez; '
          'kronometre değeriniz korunur. «Profili kaydet» ile deftere yazılır.',
        ),
        value: _chronoVoLocked,
        onChanged: (on) => setState(() => _chronoVoLocked = on),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _selectedAmmo != null && _activeAmmoVariant != null ? _applyCatalogBandMuzzleVelocity : null,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Katalog namlu Vo’suna dön'),
        ),
      ),
      const SizedBox(height: 8),
      _bcFormField(),
      ]),
      _strelokSection(context, 'NİŞAN HATTI', [
      _numField(_sightHcmCtrl, 'Dürbün ekseni yüksekliği (sight height)', suffix: 'cm'),
      const SizedBox(height: 8),
      _numField(_zeroRangeCtrl, 'Sıfırlama menzili', suffix: 'm'),
      ]),
      _strelokSection(context, 'NAMLU / SPİN', [
      Text(
        'Hatve ve mermi verileri profilde saklanır. Spin drift hesabı için «Balistik Ekler» '
        'sekmesinde «Spin drift» anahtarını açın.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.35),
      ),
      const SizedBox(height: 8),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Sağ el twist (RH)'),
        subtitle: const Text('Kapalıysa sol el (LH)'),
        value: _twistRightHanded,
        onChanged: (v) => setState(() => _twistRightHanded = v),
      ),
      const SizedBox(height: 4),
      _numField(_twistInCtrl, 'Namlu hatve (in/tur)', suffix: 'in/tur', allowEmpty: true),
      const SizedBox(height: 8),
      _numField(_grainCtrl, 'Mermi ağırlığı (spin için)', suffix: 'gr', allowEmpty: true),
      const SizedBox(height: 8),
      _numField(_calInCtrl, 'Mermi çapı', suffix: 'in', allowEmpty: true),
      const SizedBox(height: 8),
      _numField(_bulletLenInCtrl, 'Mermi uzunluğu (isteğe bağlı)', suffix: 'in', allowEmpty: true),
      ]),
      _strelokSection(context, 'NOT VE SIFIR', [
        TextField(
          controller: _weaponNotesCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Profil notu',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Çoklu sıfır / ince ayar: çözüm kartındaki tıklara eklenir (yalnız gösterim + defter).',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.3),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _numField(_zeroElevCompCtrl, 'Ek dikey tık', allowEmpty: true)),
            const SizedBox(width: 8),
            Expanded(child: _numField(_zeroWindCompCtrl, 'Ek yatay tık', allowEmpty: true)),
          ],
        ),
        const SizedBox(height: 8),
        Text('Sıfırlama atmosferi (bilgi, kayıt)', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: _numField(_zeroAtmoTempCtrl, 'Sıfırda °C', allowEmpty: true)),
            const SizedBox(width: 8),
            Expanded(child: _numField(_zeroAtmoPresCtrl, 'Sıfırda hPa', allowEmpty: true)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _numField(_zeroAtmoRhCtrl, 'Sıfırda nem %', allowEmpty: true)),
            const SizedBox(width: 8),
            Expanded(child: _numField(_zeroPowderTCtrl, 'Sıfırda barut °C', allowEmpty: true)),
          ],
        ),
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
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: _saveShotScenePreset,
        icon: const Icon(Icons.save_outlined),
        label: const Text('Sahneyi kaydet (Ana sekmeyle aynı)'),
      ),
      ]),
      _strelokSection(context, 'KAYITLI SİLAH PROFİLLERİ (DEFTER)', [
        Text(
          'Katalogdaki her silah çeşidi için ayrı satır kaydedebilirsiniz. Üstte «Silah çeşidi»ni '
          'seçtikten sonra değerleri girip «Profili kaydet» — kayıt o silaha bağlanır. '
          'Listeden dokunarak forma ve katalog seçimine yüklenir.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.35),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Tüm silahların kayıtlarını göster'),
          subtitle: Text(
            _selectedWeapon == null
                ? 'Kapalıyken: yalnızca silaha bağlı olmayan genel satırlar.'
                : 'Kapalıyken: seçili silah + genel satırlar; seçili olmayanlar gizlenir.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          value: _showAllWeaponBookEntries,
          onChanged: (v) => setState(() => _showAllWeaponBookEntries = v),
        ),
        const SizedBox(height: 6),
        if (WeaponProfileBookStore.entries.value.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Defterde kayıt yok. Silah çeşidini seçip alttaki «Profili kaydet» ile ekleyin.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          )
        else if (_visibleBookProfiles().isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Bu görünümde liste boş. Üstten silah seçin, «Tüm silahlar» anahtarını açın veya '
              'yeni kayıt ekleyin.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
            ),
          ),
        ..._visibleBookProfiles().map((e) {
          final curId = WeaponProfileStore.current.value?.id;
          final selected =
              (e.id.isNotEmpty && e.id == (_activeBookProfileId ?? curId)) ||
                  (_activeBookProfileId == null && e.id == curId);
          final coriolisLine = _bookCoriolisSummaryLine(e);
          final spinLine = _bookSpinSummaryLine(e);
          final sfLine = _millerSfLineForBook(e);
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Material(
              color: selected
                  ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35)
                  : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => unawaited(_applyBookProfileEntry(e)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                            '${_bookEntryCatalogSubtitle(e)}\n'
                            '${_bookScopeAmmoSummaryLine(e)}\n'
                            '${sfLine != null ? '$sfLine\n' : ''}'
                            '${coriolisLine != null ? '$coriolisLine\n' : ''}'
                            '${spinLine != null ? '$spinLine\n' : ''}'
                            'Vo ${e.muzzleVelocityMps.toStringAsFixed(0)} m/s · '
                            'BC ${e.displayBallisticCoefficient.toStringAsFixed(3)} (${e.bcKind.label}) · '
                            '${e.zeroRangeM.toStringAsFixed(0)} m sıfır',
                            maxLines: 6,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Kopyala',
                        icon: const Icon(Icons.copy_outlined),
                        onPressed: () async {
                          final n = await WeaponProfileBookStore.duplicate(e);
                          if (!context.mounted) return;
                          setState(() => _activeBookProfileId = n.id);
                          _fillFormFromWeaponProfile(n);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Kopyalandı: ${n.name}')),
                          );
                        },
                      ),
                      IconButton(
                        tooltip: 'Sil',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Profili sil'),
                              content: Text('"${e.name}" defterden silinsin mi?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('İptal'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Sil'),
                                ),
                              ],
                            ),
                          );
                          if (ok == true && mounted) {
                            await _deleteBookProfileEntry(e.id);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: _startNewBookProfile,
          icon: const Icon(Icons.note_add_outlined),
          label: const Text('Yeni profil (ayrı kayıt satırı)'),
        ),
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
      const SizedBox(height: 8),
      Text(
        'Namlu hatve ve mermi alanları «Silah ve mühimmat» sekmesindeki «NAMLU / SPİN» bölümündedir.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
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
      _strelokSection(context, 'ÇIKTI — MİL / MOA / KLİK', [
        Text(
          'Sayı formatı: mil için lineer (Δ/R×1000) veya atan tabanlı mrad; MOA için eski mil×3.438, '
          'gerçek yay dakikası veya shooter IPHY. «Klik birimi: MOA» ise her tıkın mil karşılığı da '
          'bu MOA tanımı ve mil seçiminizle aynı çerçevede hesaplanır. «Çözüm» özetinde düşüş ve yanal '
          'için MOA ile birlikte önerilen klik (Silah sekmesindeki klik birimi/değeri) gösterilir.',
          style: tt.bodySmall?.copyWith(height: 1.35),
        ),
        spacing,
        DropdownButtonFormField<AngularMilConvention>(
          key: ValueKey(_angularMilConvention),
          initialValue: _angularMilConvention,
          decoration: const InputDecoration(
            labelText: 'Mil tanımı',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(
              value: AngularMilConvention.linear,
              child: Text('Lineer (Δ/R×1000)'),
            ),
            DropdownMenuItem(
              value: AngularMilConvention.trueAngle,
              child: Text('Gerçek açı (atan2)'),
            ),
          ],
          onChanged: (v) async {
            if (v == null) return;
            setState(() => _angularMilConvention = v);
            await _persistBallisticsDisplayPrefs();
          },
        ),
        spacing,
        DropdownButtonFormField<MoaDisplayConvention>(
          key: ValueKey(_moaDisplayConvention),
          initialValue: _moaDisplayConvention,
          decoration: const InputDecoration(
            labelText: 'MOA gösterimi',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(
              value: MoaDisplayConvention.legacyFromMil,
              child: Text('Mil × 3.438 (uyumluluk)'),
            ),
            DropdownMenuItem(
              value: MoaDisplayConvention.trueArcminute,
              child: Text('Gerçek yay dakikası'),
            ),
            DropdownMenuItem(
              value: MoaDisplayConvention.shooterInchesPer100Yd,
              child: Text('Shooter MOA (≈1.047″ @100 yd)'),
            ),
          ],
          onChanged: (v) async {
            if (v == null) return;
            setState(() => _moaDisplayConvention = v);
            await _persistBallisticsDisplayPrefs();
          },
        ),
      ]),
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
        subtitle: const Text('Hatve / mermi: Silah ve mühimmat → NAMLU / SPİN'),
        value: _spinOn,
        onChanged: (v) => setState(() => _spinOn = v),
      ),
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
            child: Text(
              'Sürüklenme: tek BC veya Mach parçalı BC aynı G1/G7 integratörünü kullanır. '
              'Özel i(Mach) tablosu, G1 biçiminde bir sürüklenme şekli tanımlar; BC ölçek olarak kalır. '
              'Vo ve menzilde sahada doğrulama önerilir. Tam Doppler tabanlı ayrı kütüphane yok; '
              'parçalı BC / özel tablo ile başka ürünlere yaklaşın.',
              style: tt.bodySmall?.copyWith(height: 1.35),
            ),
          ),
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
          TextButton.icon(
            onPressed: () => unawaited(_openMovingTargetPage()),
            icon: const Icon(Icons.directions_run, size: 18),
            label: const Text('Hız ve açıdan hesapla'),
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
      const SizedBox(height: 8),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Dürbün seçimine göre önizlemeyi güncelle'),
        subtitle: Text(
          'Açıkken «Silah ve mühimmat» sekmesinde dürbün değiştirildiğinde burada eşlenen '
          'parametrik taksimat yüklenir. Gösterim üreticinin resmi çizimi değildir; mil/MOA tutması hesapla uyumludur.',
          style: tt.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        value: _autoReticleFromScope,
        onChanged: (v) async {
          setState(() => _autoReticleFromScope = v);
          if (v && _selectedScope != null) {
            await _syncReticleFromScope(_selectedScope!);
          }
        },
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
        'Varsayılan bitiş ${BallisticsRangeUi.defaultTableEndM} m (≈3 km sınıfı); motor çok daha uzun menzili de çözer. '
        'Çok satırda tablo yavaşlar — üst sınır ${BallisticsRangeUi.maxRangeTableRows} satır (adımı büyütün). '
        'Ana menzil, tablo aralığı ve son toplu menzil listesi cihazda saklanır.',
        style: tt.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
    return Theme(
      data: streLockBallisticsTheme(context),
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          final cs = theme.colorScheme;
          return Form(
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
          );
        },
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
    bool allowEmpty = false,
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
        if (allowEmpty && (value == null || value.trim().isEmpty)) return null;
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
  final bool streLockStyle;
  final double? rangeMeters;
  final double zeroElevCompClicks;
  final double zeroWindCompClicks;
  final bool showEnergyFtLbf;

  const _StrelokHeroResult({
    required this.result,
    required this.clickUnit,
    required this.clickValue,
    this.streLockStyle = false,
    this.rangeMeters,
    this.zeroElevCompClicks = 0,
    this.zeroWindCompClicks = 0,
    this.showEnergyFtLbf = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final prim = streLockStyle ? StreLockBalColors.accentBlue : cs.primary;
    final onCard = streLockStyle ? StreLockBalColors.fieldText : null;
    final subtle = streLockStyle
        ? StreLockBalColors.fieldText.withValues(alpha: 0.65)
        : cs.onSurfaceVariant;

    final dropCm = rangeMeters != null && rangeMeters! > 0
        ? result.verticalHoldDeltaMeters * 100.0
        : null;

    String clickSpec() {
      final v = clickValue;
      final s = v == v.roundToDouble() ? v.toStringAsFixed(1) : v.toStringAsFixed(2);
      return '$s ${clickUnit.label}';
    }

    Widget heroCol(
      String title,
      String primaryMrad,
      double moa,
      double clicksN,
    ) {
      final spec = clickSpec();
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              title,
              style: tt.labelSmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 0.9,
                color: prim,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              primaryMrad,
              textAlign: TextAlign.center,
              style: tt.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                fontSize: 26,
                height: 1.05,
                color: onCard,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${moa.toStringAsFixed(2)} MOA',
              textAlign: TextAlign.center,
              style: tt.bodySmall?.copyWith(color: subtle, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              '${clicksN.toStringAsFixed(1)} klik',
              textAlign: TextAlign.center,
              style: tt.bodySmall?.copyWith(
                color: subtle,
                fontSize: 11,
                height: 1.2,
              ),
            ),
            Text(
              spec,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: tt.bodySmall?.copyWith(
                color: subtle.withValues(alpha: 0.85),
                fontSize: 10,
                height: 1.15,
              ),
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
              child: Text(k, style: tt.bodySmall?.copyWith(color: subtle)),
            ),
            Expanded(
              flex: 4,
              child: Text(
                v,
                textAlign: TextAlign.end,
                style: tt.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: onCard,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final deco = streLockStyle
        ? BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: StreLockBalColors.fieldFill,
            border: Border.all(color: StreLockBalColors.accentBlue.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          )
        : BoxDecoration(
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
          );

    return Container(
      decoration: deco,
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
                color: streLockStyle ? StreLockBalColors.headerOrange : cs.primary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                heroCol(
                  'DÜŞÜŞ (MRAD)',
                  result.dropMil.toStringAsFixed(2),
                  result.dropMoa,
                  result.clicks + zeroElevCompClicks,
                ),
                Container(
                  width: 1,
                  height: 96,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  color: (streLockStyle ? StreLockBalColors.fieldText : cs.outlineVariant)
                      .withValues(alpha: 0.25),
                ),
                heroCol(
                  'YANAL (MRAD)',
                  result.windMil.toStringAsFixed(2),
                  result.windMoa,
                  result.windClicks + zeroWindCompClicks,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Öncü ${result.leadMil.toStringAsFixed(2)} mil (${result.leadClicks.toStringAsFixed(1)} klik) · '
              'Toplam yatay ${result.combinedLateralMil.toStringAsFixed(2)} mil (${result.combinedLateralClicks.toStringAsFixed(1)} klik)'
              '${dropCm != null ? ' · düşüş ~${dropCm.toStringAsFixed(0)} cm @ ${rangeMeters!.toStringAsFixed(0)} m' : ''}',
              textAlign: TextAlign.center,
              style: tt.bodySmall?.copyWith(color: subtle),
            ),
            const Divider(height: 20),
            detailRow(
              'Klik (düşüş)',
              '${(result.clicks + zeroElevCompClicks).toStringAsFixed(1)} ($clickValue ${clickUnit.label})',
            ),
            detailRow(
              'Klik (yan saf)',
              '${(result.windClicks + zeroWindCompClicks).toStringAsFixed(1)} ($clickValue ${clickUnit.label})',
            ),
            detailRow('Klik (öncü)', '${result.leadClicks.toStringAsFixed(1)} ($clickValue ${clickUnit.label})'),
            detailRow('Klik (yatay top.)', '${result.combinedLateralClicks.toStringAsFixed(1)} ($clickValue ${clickUnit.label})'),
            detailRow('Vo (kullanılan)', '${result.adjustedMuzzleVelocityMps.toStringAsFixed(1)} m/s'),
            detailRow('Hız (hedef)', '${result.impactVelocityMps.toStringAsFixed(0)} m/s'),
            if (result.impactEnergyJoules != null)
              detailRow(
                'Enerji (hedef)',
                showEnergyFtLbf
                    ? '${(result.impactEnergyJoules! * 0.737562149).toStringAsFixed(0)} ft·lbf'
                    : '${result.impactEnergyJoules!.toStringAsFixed(0)} J',
              ),
            detailRow(
              'TOF',
              '${(result.timeOfFlightMs / 1000.0).toStringAsFixed(3)} s (${result.timeOfFlightMs.toStringAsFixed(0)} ms)',
            ),
          ],
        ),
      ),
    );
  }
}
