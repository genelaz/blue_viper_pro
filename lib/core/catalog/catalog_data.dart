import '../ballistics/bc_g7_estimate.dart';
import '../ballistics/click_units.dart';

/// Tek mühimmat için namlu uzunluğuna göre Vo / BC varyantı.
class AmmoBarrelVariant {
  final String id;
  final String label;
  final double? barrelInches;
  final double muzzleVelocityMps;
  /// Katalogda yoksa [null] — balistikte kullanıcı datasheet / deney G1 BC girer.
  final double? bcG1;
  /// İsteğe bağlı G7 BC (lb/in²); G7 modunda öncelik.
  final double? bcG7;

  const AmmoBarrelVariant({
    required this.id,
    required this.label,
    this.barrelInches,
    required this.muzzleVelocityMps,
    this.bcG1,
    this.bcG7,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        if (barrelInches != null) 'barrelInches': barrelInches,
        'muzzleVelocityMps': muzzleVelocityMps,
        if (bcG1 != null) 'bcG1': bcG1,
        if (bcG7 != null) 'bcG7': bcG7,
      };

  factory AmmoBarrelVariant.fromMap(Map<String, dynamic> map) =>
      AmmoBarrelVariant(
        id: map['id'] as String,
        label: map['label'] as String,
        barrelInches: (map['barrelInches'] as num?)?.toDouble(),
        muzzleVelocityMps: (map['muzzleVelocityMps'] as num).toDouble(),
        bcG1: (map['bcG1'] as num?)?.toDouble(),
        bcG7: (map['bcG7'] as num?)?.toDouble(),
      );
}

class WeaponType {
  final String id;
  final String name;
  final String caliber;
  /// Örnek: sniper, dmr, assault, lmg, carbine
  final String? role;
  /// Örnek: TR, NATO, US, OTHER
  final String? region;
  /// Namlu uzunluğu (in); mühimmat bandı seçimine yaklaşım için.
  final double? barrelLengthInches;
  /// Üretici / seri / dipçik vb. serbest not.
  final String? notes;
  /// Forma yazılacak varsayılan sıfırlama menzili (m).
  final double? defaultZeroRangeM;
  /// Forma yazılacak varsayılan nişan yüksekliği (cm).
  final double? defaultSightHeightCm;
  /// Namlu hatve (in/tur); forma ile senkron.
  final double? twistInchesPerTurn;
  /// Sağ el twist; null = forma varsayılanına dokunma.
  final bool? twistRightHanded;

  const WeaponType({
    required this.id,
    required this.name,
    required this.caliber,
    this.role,
    this.region,
    this.barrelLengthInches,
    this.notes,
    this.defaultZeroRangeM,
    this.defaultSightHeightCm,
    this.twistInchesPerTurn,
    this.twistRightHanded,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'caliber': caliber,
        if (role != null) 'role': role,
        if (region != null) 'region': region,
        if (barrelLengthInches != null) 'barrelLengthInches': barrelLengthInches,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
        if (defaultZeroRangeM != null) 'defaultZeroRangeM': defaultZeroRangeM,
        if (defaultSightHeightCm != null) 'defaultSightHeightCm': defaultSightHeightCm,
        if (twistInchesPerTurn != null) 'twistInchesPerTurn': twistInchesPerTurn,
        if (twistRightHanded != null) 'twistRightHanded': twistRightHanded,
      };

  factory WeaponType.fromMap(Map<String, dynamic> map) => WeaponType(
        id: map['id'] as String,
        name: map['name'] as String,
        caliber: map['caliber'] as String,
        role: map['role'] as String?,
        region: map['region'] as String?,
        barrelLengthInches: (map['barrelLengthInches'] as num?)?.toDouble(),
        notes: map['notes'] as String?,
        defaultZeroRangeM: (map['defaultZeroRangeM'] as num?)?.toDouble(),
        defaultSightHeightCm: (map['defaultSightHeightCm'] as num?)?.toDouble(),
        twistInchesPerTurn: (map['twistInchesPerTurn'] as num?)?.toDouble(),
        twistRightHanded: map['twistRightHanded'] is bool ? map['twistRightHanded'] as bool : null,
      );
}

class ScopeType {
  final String id;
  final String name;
  final ClickUnit clickUnit;
  final double clickValue;
  /// Değişken zoom alt sınırı (×), isteğe bağlı.
  final double? minMagnification;
  /// Değişken zoom üst sınırı (×), isteğe bağlı.
  final double? maxMagnification;
  /// SFP retikül doğum büyütmesi (×), isteğe bağlı.
  final double? referenceMagnification;
  /// Serbest metin (objektif çap, tüp çapı, üretici kodu vb.).
  final String? notes;
  /// Kullanıcı dürbünü için FFP varsayımı; forma uygulanır.
  final bool? defaultFirstFocalPlane;
  /// 100 m'de dikey klik başına cm (bilgi / forma ipucu).
  final double? verticalClickCmPer100m;
  /// 100 m'de yatay klik başına cm.
  final double? horizontalClickCmPer100m;

  const ScopeType({
    required this.id,
    required this.name,
    required this.clickUnit,
    required this.clickValue,
    this.minMagnification,
    this.maxMagnification,
    this.referenceMagnification,
    this.notes,
    this.defaultFirstFocalPlane,
    this.verticalClickCmPer100m,
    this.horizontalClickCmPer100m,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'clickUnit': clickUnit.name,
        'clickValue': clickValue,
        if (minMagnification != null) 'minMagnification': minMagnification,
        if (maxMagnification != null) 'maxMagnification': maxMagnification,
        if (referenceMagnification != null) 'referenceMagnification': referenceMagnification,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
        if (defaultFirstFocalPlane != null) 'defaultFirstFocalPlane': defaultFirstFocalPlane,
        if (verticalClickCmPer100m != null) 'verticalClickCmPer100m': verticalClickCmPer100m,
        if (horizontalClickCmPer100m != null) 'horizontalClickCmPer100m': horizontalClickCmPer100m,
      };

  factory ScopeType.fromMap(Map<String, dynamic> map) => ScopeType(
        id: map['id'] as String,
        name: map['name'] as String,
        clickUnit: ClickUnit.values.firstWhere(
          (e) => e.name == map['clickUnit'],
          orElse: () => ClickUnit.mil,
        ),
        clickValue: (map['clickValue'] as num?)?.toDouble() ?? 0.1,
        minMagnification: (map['minMagnification'] as num?)?.toDouble(),
        maxMagnification: (map['maxMagnification'] as num?)?.toDouble(),
        referenceMagnification: (map['referenceMagnification'] as num?)?.toDouble(),
        notes: map['notes'] as String?,
        defaultFirstFocalPlane: map['defaultFirstFocalPlane'] is bool ? map['defaultFirstFocalPlane'] as bool : null,
        verticalClickCmPer100m: (map['verticalClickCmPer100m'] as num?)?.toDouble(),
        horizontalClickCmPer100m: (map['horizontalClickCmPer100m'] as num?)?.toDouble(),
      );
}

class AmmoType {
  final String id;
  final String name;
  final String caliber;
  final List<AmmoBarrelVariant> variants;

  const AmmoType({
    required this.id,
    required this.name,
    required this.caliber,
    required this.variants,
  });

  /// İlk varyant (geri uyumluluk / varsayılan).
  double get muzzleVelocityMps => variants.first.muzzleVelocityMps;

  double? get bcG1 => variants.first.bcG1;

  double? get bcG7 => variants.first.bcG7;

  AmmoBarrelVariant variantById(String id) =>
      variants.firstWhere((v) => v.id == id, orElse: () => variants.first);

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'caliber': caliber,
        'variants': variants.map((e) => e.toMap()).toList(),
      };

  factory AmmoType.fromMap(Map<String, dynamic> map) {
    final vList = map['variants'] as List<dynamic>?;
    if (vList != null && vList.isNotEmpty) {
      return AmmoType(
        id: map['id'] as String,
        name: map['name'] as String,
        caliber: map['caliber'] as String,
        variants: vList
            .map((e) =>
                AmmoBarrelVariant.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
    }
    // Eski tek-değer kayıtlar
    return AmmoType(
      id: map['id'] as String,
      name: map['name'] as String,
      caliber: map['caliber'] as String,
      variants: [
        AmmoBarrelVariant(
          id: 'default',
          label: 'Tek değer',
          muzzleVelocityMps: (map['muzzleVelocityMps'] as num).toDouble(),
          bcG1: (map['bcG1'] as num?)?.toDouble(),
        ),
      ],
    );
  }
}

/// Üç standart namlu bandı: ~16" / ~20" / ~24".
List<AmmoBarrelVariant> ammoVariantsThreeBarrels({
  required double mv16,
  required double bc16,
  required double mv20,
  required double bc20,
  required double mv24,
  required double bc24,
  double? bc16g7,
  double? bc20g7,
  double? bc24g7,
}) =>
    [
      AmmoBarrelVariant(
        id: 'b16',
        label: '~16" namlu',
        barrelInches: 16,
        muzzleVelocityMps: mv16,
        bcG1: bc16,
        bcG7: bc16g7 ?? estimateG7FromG1(bc16),
      ),
      AmmoBarrelVariant(
        id: 'b20',
        label: '~20" namlu',
        barrelInches: 20,
        muzzleVelocityMps: mv20,
        bcG1: bc20,
        bcG7: bc20g7 ?? estimateG7FromG1(bc20),
      ),
      AmmoBarrelVariant(
        id: 'b24',
        label: '~24" namlu',
        barrelInches: 24,
        muzzleVelocityMps: mv24,
        bcG1: bc24,
        bcG7: bc24g7 ?? estimateG7FromG1(bc24),
      ),
    ];

class CatalogData {
  static const weapons = <WeaponType>[
    WeaponType(id: 'r700_308', name: 'Remington 700', caliber: '.308 Win', role: 'sniper', region: 'US'),
    WeaponType(id: 'tikka_t3x', name: 'Tikka T3x', caliber: '.308 Win', role: 'sniper', region: 'NATO'),
    WeaponType(id: 'sako_trg22', name: 'Sako TRG 22', caliber: '.308 Win', role: 'sniper', region: 'NATO'),
    WeaponType(id: 'sako_trg42', name: 'Sako TRG 42', caliber: '.338 LM', role: 'sniper', region: 'NATO'),
    WeaponType(id: 'm110', name: 'M110 SASS', caliber: '7.62x51', role: 'dmr', region: 'US'),
    WeaponType(id: 'barrett_mrad', name: 'Barrett MRAD', caliber: '.338 LM', role: 'sniper', region: 'US'),
    WeaponType(id: 'tr_knt76', name: 'KNT-76', caliber: '7.62x51', role: 'sniper', region: 'TR'),
    WeaponType(
        id: 'tr_jmk_bora', name: 'JMK BORA-12 (BORA)', caliber: '12.7x99', role: 'sniper', region: 'TR'),
    WeaponType(
      id: 'tr_kn12',
      name: 'KN-12 (.338 LM / 8.59x69)',
      caliber: '8.59x69',
      role: 'sniper',
      region: 'TR',
    ),
    WeaponType(id: 'tr_ksr50', name: 'KSR-50', caliber: '12.7x99', role: 'sniper', region: 'TR'),
    WeaponType(id: 'akm_762x39', name: 'AKM', caliber: '7.62x39', role: 'assault', region: 'OTHER'),
    WeaponType(id: 'svd', name: 'SVD Dragunov', caliber: '7.62x54R', role: 'dmr', region: 'OTHER'),
    WeaponType(id: 'cz557', name: 'CZ 557', caliber: '.308 Win', role: 'sniper', region: 'NATO'),
    WeaponType(id: 'ruger_rpr', name: 'Ruger Precision Rifle', caliber: '6.5 CM', role: 'sniper', region: 'US'),
    WeaponType(id: 'accuracy_axsr', name: 'Accuracy AXSR', caliber: '.300 NM', role: 'sniper', region: 'NATO'),
    WeaponType(id: 'm2010', name: 'M2010 ESR', caliber: '.300 WM', role: 'sniper', region: 'US'),
  ];

  static const scopes = <ScopeType>[
    ScopeType(
      id: 'pmii_01mil',
      name: 'Schmidt & Bender PM II (0.1 mil)',
      clickUnit: ClickUnit.mil,
      clickValue: 0.1,
    ),
    ScopeType(
      id: 'vortex_01mil',
      name: 'Vortex Razor HD (0.1 mil)',
      clickUnit: ClickUnit.mil,
      clickValue: 0.1,
    ),
    ScopeType(
      id: 'leupold_025moa',
      name: 'Leupold Mark 5HD (1/4 MOA)',
      clickUnit: ClickUnit.moa,
      clickValue: 0.25,
    ),
    ScopeType(
      id: 'nightforce_025moa',
      name: 'Nightforce ATACR (1/4 MOA)',
      clickUnit: ClickUnit.moa,
      clickValue: 0.25,
    ),
    ScopeType(
      id: 'march_005mil',
      name: 'March 5-42x (0.05 mil)',
      clickUnit: ClickUnit.mil,
      clickValue: 0.05,
    ),
    ScopeType(
      id: 'vector_01mil',
      name: 'Vector Optics (0.1 mil)',
      clickUnit: ClickUnit.mil,
      clickValue: 0.1,
    ),
    ScopeType(
      id: 'athlon_025moa',
      name: 'Athlon Cronus (1/4 MOA)',
      clickUnit: ClickUnit.moa,
      clickValue: 0.25,
    ),
    // Türkiye’de yaygın silah üstü tipik büyütmeler (markasız / genel)
    ScopeType(
      id: 'tr_scope_312x50_mil',
      name: 'Silah üstü 3-12×50 (26 mm tüp, tipik TR, 0.1 mil)',
      clickUnit: ClickUnit.mil,
      clickValue: 0.1,
    ),
    ScopeType(
      id: 'tr_scope_416x50_mil',
      name: 'Silah üstü 4-16×50 (tipik TR / genel, 0.1 mil)',
      clickUnit: ClickUnit.mil,
      clickValue: 0.1,
    ),
    ScopeType(
      id: 'tr_scope_624x50_mil',
      name: 'Silah üstü 6-24×50 (tipik TR / genel, 0.1 mil)',
      clickUnit: ClickUnit.mil,
      clickValue: 0.1,
    ),
    ScopeType(
      id: 'tr_scope_525x56_mil',
      name: 'Silah üstü 5-25×56 (34 mm tüp, tipik TR, 0.1 mil)',
      clickUnit: ClickUnit.mil,
      clickValue: 0.1,
    ),
    ScopeType(
      id: 'tr_scope_525x50_mil',
      name: 'Silah üstü 5-25×50 (tipik TR, 0.1 mil)',
      clickUnit: ClickUnit.mil,
      clickValue: 0.1,
    ),
    ScopeType(
      id: 'tr_scope_520x50_mil',
      name: 'Silah üstü 5-20×50 (genel av/taktik, 0.1 mil)',
      clickUnit: ClickUnit.mil,
      clickValue: 0.1,
    ),
    // 3E EOS (3E Elektro Optik Sistemler, TR) — tıklama nominal; üretici belgesi / saha ile doğrulayın.
    ScopeType(
      id: 'tr_3e_keskin_31250_mil',
      name: '3E EOS Keskin 3-12×50 (mil-mil, nominal 0.1 mil)',
      clickUnit: ClickUnit.mil,
      clickValue: 0.1,
    ),
    ScopeType(
      id: 'tr_3e_avci_mil',
      name: '3E EOS AVCI (piyade platformları ile uyumlu seriler; nominal 0.1 mil)',
      clickUnit: ClickUnit.mil,
      clickValue: 0.1,
    ),
    ScopeType(
      id: 'tr_3e_eos_gen_mil',
      name: '3E EOS taktik dürbün (diğer modeller; nominal 0.1 mil — kılavuz)',
      clickUnit: ClickUnit.mil,
      clickValue: 0.1,
    ),
    // Swarovski (Avusturya)
    ScopeType(
      id: 'swarovski_x5i_52556_mil',
      name: 'Swarovski Optik X5i 5-25×56 P BT (0.1 mil)',
      clickUnit: ClickUnit.mil,
      clickValue: 0.1,
    ),
    ScopeType(
      id: 'swarovski_z8i_mil',
      name: 'Swarovski Optik Z8i (taktik modül, 0.1 mil)',
      clickUnit: ClickUnit.mil,
      clickValue: 0.1,
    ),
    ScopeType(
      id: 'swarovski_z5i_moa',
      name: 'Swarovski Optik Z5i (1/4 MOA)',
      clickUnit: ClickUnit.moa,
      clickValue: 0.25,
    ),
    ScopeType(
      id: 'swarovski_ds_moa',
      name: 'Swarovski Optik dS (dijital, 1/4 MOA eşleniği)',
      clickUnit: ClickUnit.moa,
      clickValue: 0.25,
    ),
    // Diğer yaygın silah üstü markalar
    ScopeType(
      id: 'burris_xtr3_mil',
      name: 'Burris XTR III (0.1 mil)',
      clickUnit: ClickUnit.mil,
      clickValue: 0.1,
    ),
    ScopeType(
      id: 'trijicon_tenmile_mil',
      name: 'Trijicon Tenmile (0.1 mil)',
      clickUnit: ClickUnit.mil,
      clickValue: 0.1,
    ),
    ScopeType(
      id: 'trijicon_credo_mil',
      name: 'Trijicon Credo HX (0.1 mil)',
      clickUnit: ClickUnit.mil,
      clickValue: 0.1,
    ),
    ScopeType(
      id: 'us_optics_tpal_mil',
      name: 'US Optics TPAL / B-Series (0.1 mil)',
      clickUnit: ClickUnit.mil,
      clickValue: 0.1,
    ),
    ScopeType(
      id: 'zero_compromise_zc527_mil',
      name: 'Zero Compromise Optic ZC527 (0.1 mil)',
      clickUnit: ClickUnit.mil,
      clickValue: 0.1,
    ),
    ScopeType(
      id: 'sightron_s3_moa',
      name: 'Sightron SIII (1/4 MOA)',
      clickUnit: ClickUnit.moa,
      clickValue: 0.25,
    ),
    ScopeType(
      id: 'sightron_sv_mil',
      name: 'Sightron SV (0.1 mil)',
      clickUnit: ClickUnit.mil,
      clickValue: 0.1,
    ),
    ScopeType(
      id: 'hawke_sidewinder_mil',
      name: 'Hawke Sidewinder (0.1 mil)',
      clickUnit: ClickUnit.mil,
      clickValue: 0.1,
    ),
    ScopeType(
      id: 'delta_sentry_mil',
      name: 'Delta Optical Stryker/Sentry HD (0.1 mil)',
      clickUnit: ClickUnit.mil,
      clickValue: 0.1,
    ),
    ScopeType(
      id: 'ior_valdada_mil',
      name: 'IOR Valdada Recon (0.1 mil)',
      clickUnit: ClickUnit.mil,
      clickValue: 0.1,
    ),
    ScopeType(
      id: 'nightforce_nx8_mil',
      name: 'Nightforce NX8 (0.2 mil)',
      clickUnit: ClickUnit.mil,
      clickValue: 0.2,
    ),
    ScopeType(
      id: 'vortex_pst_gen2_mil',
      name: 'Vortex PST Gen II (0.1 mil)',
      clickUnit: ClickUnit.mil,
      clickValue: 0.1,
    ),
    ScopeType(
      id: 'vortex_diamondback_moa',
      name: 'Vortex Diamondback Tactical (1/4 MOA)',
      clickUnit: ClickUnit.moa,
      clickValue: 0.25,
    ),
    ScopeType(
      id: 'sig_tango4_mil',
      name: 'Sig Sauer TANGO4 (0.1 mil)',
      clickUnit: ClickUnit.mil,
      clickValue: 0.1,
    ),
    ScopeType(
      id: 'leupold_mk5_mil',
      name: 'Leupold Mark 5HD (0.1 mil)',
      clickUnit: ClickUnit.mil,
      clickValue: 0.1,
    ),
    ScopeType(
      id: 'atacr_fc_dimil',
      name: 'Nightforce ATACR F1 (0.1 mil)',
      clickUnit: ClickUnit.mil,
      clickValue: 0.1,
    ),
  ];

  static final ammos = <AmmoType>[
    AmmoType(
      id: '308_168_smk',
      name: '.308 Win 168gr SMK',
      caliber: '.308 Win',
      variants: ammoVariantsThreeBarrels(
        mv16: 755, bc16: 0.462,
        mv20: 800, bc20: 0.462,
        mv24: 835, bc24: 0.462,
      ),
    ),
    AmmoType(
      id: '308_175_smk',
      name: '.308 Win 175gr SMK',
      caliber: '.308 Win',
      variants: ammoVariantsThreeBarrels(
        mv16: 738, bc16: 0.505,
        mv20: 785, bc20: 0.505,
        mv24: 820, bc24: 0.505,
      ),
    ),
    AmmoType(
      id: '338_250_scenar',
      name: '.338 LM 250gr Scenar',
      caliber: '.338 LM',
      variants: ammoVariantsThreeBarrels(
        mv16: 830, bc16: 0.675,
        mv20: 870, bc20: 0.675,
        mv24: 905, bc24: 0.675,
      ),
    ),
    AmmoType(
      id: '762_175_otm',
      name: '7.62x51 175gr OTM',
      caliber: '7.62x51',
      variants: ammoVariantsThreeBarrels(
        mv16: 738, bc16: 0.496,
        mv20: 780, bc20: 0.496,
        mv24: 815, bc24: 0.496,
      ),
    ),
    AmmoType(
      id: '65cm_140_eldm',
      name: '6.5 CM 140gr ELD-M',
      caliber: '6.5 CM',
      variants: ammoVariantsThreeBarrels(
        mv16: 785, bc16: 0.610,
        mv20: 825, bc20: 0.610,
        mv24: 855, bc24: 0.610,
      ),
    ),
    AmmoType(
      id: '300wm_190_smk',
      name: '.300 WM 190gr SMK',
      caliber: '.300 WM',
      variants: ammoVariantsThreeBarrels(
        mv16: 820, bc16: 0.533,
        mv20: 865, bc20: 0.533,
        mv24: 895, bc24: 0.533,
      ),
    ),
    AmmoType(
      id: '762x54r_174',
      name: '7.62x54R 174gr',
      caliber: '7.62x54R',
      variants: ammoVariantsThreeBarrels(
        mv16: 755, bc16: 0.500,
        mv20: 795, bc20: 0.500,
        mv24: 825, bc24: 0.500,
      ),
    ),
    AmmoType(
      id: '762x39_123',
      name: '7.62x39 123gr',
      caliber: '7.62x39',
      variants: ammoVariantsThreeBarrels(
        mv16: 675, bc16: 0.300,
        mv20: 705, bc20: 0.300,
        mv24: 730, bc24: 0.300,
      ),
    ),
    AmmoType(
      id: 'mke_762_m80',
      name: 'MKE 7.62 mm×51 Ball (M80) — Vo 23,7 m: 838±9,1 m/s; BC 0,45 (G1) [MKE USA]',
      caliber: '7.62x51',
      variants: [
        AmmoBarrelVariant(
          id: 'b16',
          label: '~16" namlu (tahmini Vo)',
          barrelInches: 16,
          muzzleVelocityMps: 805,
          bcG1: 0.45,
          bcG7: estimateG7FromG1(0.45),
        ),
        AmmoBarrelVariant(
          id: 'b22',
          label: '~22" referans (yakın Vo 838)',
          barrelInches: 22,
          muzzleVelocityMps: 838,
          bcG1: 0.45,
          bcG7: estimateG7FromG1(0.45),
        ),
        AmmoBarrelVariant(
          id: 'b24',
          label: '~24" namlu (tahmini Vo)',
          barrelInches: 24,
          muzzleVelocityMps: 858,
          bcG1: 0.45,
          bcG7: estimateG7FromG1(0.45),
        ),
      ],
    ),
    AmmoType(
      id: 'mke_762_m118',
      name:
          'MKE 7.62 mm×51 M118 — Vo 23,7 m: 784±9 m/s; ~11,4 g [MKE USA]; nominal G1≈0,49 / G7 tahmini (doğrulayın)',
      caliber: '7.62x51',
      variants: [
        AmmoBarrelVariant(
          id: 'b16',
          label: '~16" namlu (tahmini Vo)',
          barrelInches: 16,
          muzzleVelocityMps: 752,
          bcG1: 0.49,
          bcG7: estimateG7FromG1(0.49),
        ),
        AmmoBarrelVariant(
          id: 'b22',
          label: '~22" referans (yakın Vo 784)',
          barrelInches: 22,
          muzzleVelocityMps: 784,
          bcG1: 0.49,
          bcG7: estimateG7FromG1(0.49),
        ),
        AmmoBarrelVariant(
          id: 'b24',
          label: '~24" namlu (tahmini Vo)',
          barrelInches: 24,
          muzzleVelocityMps: 805,
          bcG1: 0.49,
          bcG7: estimateG7FromG1(0.49),
        ),
      ],
    ),
    AmmoType(
      id: 'mke_762_m62',
      name: 'MKE 7.62 mm×51 İzli (M62) — Vo 23,7 m: 838±9,1 m/s; BC 0,47 (G1) [mke.gov.tr]',
      caliber: '7.62x51',
      variants: [
        AmmoBarrelVariant(
          id: 'b16',
          label: '~16" namlu (tahmini Vo)',
          barrelInches: 16,
          muzzleVelocityMps: 805,
          bcG1: 0.47,
          bcG7: estimateG7FromG1(0.47),
        ),
        AmmoBarrelVariant(
          id: 'b22',
          label: '~22" referans (yakın Vo 838)',
          barrelInches: 22,
          muzzleVelocityMps: 838,
          bcG1: 0.47,
          bcG7: estimateG7FromG1(0.47),
        ),
        AmmoBarrelVariant(
          id: 'b24',
          label: '~24" namlu (tahmini Vo)',
          barrelInches: 24,
          muzzleVelocityMps: 858,
          bcG1: 0.47,
          bcG7: estimateG7FromG1(0.47),
        ),
      ],
    ),
    AmmoType(
      id: 'mke_762_subsonic',
      name: 'MKE 7.62 mm×51 Subsonic — Vo 23,7 m: 305 m/s; 13 g mermi [MKE USA]',
      caliber: '7.62x51',
      variants: [
        AmmoBarrelVariant(
          id: 'b16',
          label: '~16" (çok hafif fark)',
          barrelInches: 16,
          muzzleVelocityMps: 302,
          bcG1: 0.52,
          bcG7: estimateG7FromG1(0.52),
        ),
        AmmoBarrelVariant(
          id: 'b20',
          label: '~20" referans',
          barrelInches: 20,
          muzzleVelocityMps: 305,
          bcG1: 0.52,
          bcG7: estimateG7FromG1(0.52),
        ),
        AmmoBarrelVariant(
          id: 'b24',
          label: '~24" (çok hafif fark)',
          barrelInches: 24,
          muzzleVelocityMps: 308,
          bcG1: 0.52,
          bcG7: estimateG7FromG1(0.52),
        ),
      ],
    ),
    AmmoType(
      id: 'mke_859_ball',
      name: 'MKE 8,59 mm×70 (338 LM) Ball — Vo 890±10 m/s; 16,4 g [MKE USA]',
      caliber: '8.59x70',
      variants: [
        AmmoBarrelVariant(
          id: 'b20',
          label: '~20" namlu (tahmini Vo)',
          barrelInches: 20,
          muzzleVelocityMps: 868,
          bcG1: 0.675,
          bcG7: estimateG7FromG1(0.675),
        ),
        AmmoBarrelVariant(
          id: 'b24',
          label: '~24" referans (yakın Vo 890)',
          barrelInches: 24,
          muzzleVelocityMps: 890,
          bcG1: 0.675,
          bcG7: estimateG7FromG1(0.675),
        ),
        AmmoBarrelVariant(
          id: 'b26',
          label: '~26" namlu (tahmini Vo)',
          barrelInches: 26,
          muzzleVelocityMps: 905,
          bcG1: 0.675,
          bcG7: estimateG7FromG1(0.675),
        ),
      ],
    ),
    AmmoType(
      id: 'mke_859_solid',
      name:
          'MKE 8,59 mm×70 (338 LM) Solid Metal Projectile — Vo 890±10 m/s; 15,6 g [MKE USA]',
      caliber: '8.59x70',
      variants: [
        AmmoBarrelVariant(
          id: 'b20',
          label: '~20" namlu (tahmini Vo)',
          barrelInches: 20,
          muzzleVelocityMps: 868,
          bcG1: 0.58,
          bcG7: estimateG7FromG1(0.58),
        ),
        AmmoBarrelVariant(
          id: 'b24',
          label: '~24" referans (yakın Vo 890)',
          barrelInches: 24,
          muzzleVelocityMps: 890,
          bcG1: 0.58,
          bcG7: estimateG7FromG1(0.58),
        ),
        AmmoBarrelVariant(
          id: 'b26',
          label: '~26" namlu (tahmini Vo)',
          barrelInches: 26,
          muzzleVelocityMps: 905,
          bcG1: 0.58,
          bcG7: estimateG7FromG1(0.58),
        ),
      ],
    ),
    AmmoType(
      id: 'mke_127_m33',
      name: 'MKE 12,7 mm×99 M33 — Vo 23,7 m: 887±9,2 m/s [MKE USA]',
      caliber: '12.7x99',
      variants: [
        AmmoBarrelVariant(
          id: 'b20',
          label: '~20" namlu (tahmini Vo)',
          barrelInches: 20,
          muzzleVelocityMps: 855,
          bcG1: 0.62,
          bcG7: estimateG7FromG1(0.62),
        ),
        AmmoBarrelVariant(
          id: 'b24',
          label: '~24" referans (yakın Vo 887)',
          barrelInches: 24,
          muzzleVelocityMps: 887,
          bcG1: 0.62,
          bcG7: estimateG7FromG1(0.62),
        ),
        AmmoBarrelVariant(
          id: 'b29',
          label: '~29" namlu (tahmini Vo)',
          barrelInches: 29,
          muzzleVelocityMps: 910,
          bcG1: 0.62,
          bcG7: estimateG7FromG1(0.62),
        ),
      ],
    ),
    AmmoType(
      id: 'mke_127_m8',
      name: 'MKE 12,7 mm×99 M8 (AP) — Vo 23,7 m: 887±9,2 m/s [MKE USA]',
      caliber: '12.7x99',
      variants: [
        AmmoBarrelVariant(
          id: 'b20',
          label: '~20" namlu (tahmini Vo)',
          barrelInches: 20,
          muzzleVelocityMps: 855,
          bcG1: 0.58,
          bcG7: estimateG7FromG1(0.58),
        ),
        AmmoBarrelVariant(
          id: 'b24',
          label: '~24" referans (yakın Vo 887)',
          barrelInches: 24,
          muzzleVelocityMps: 887,
          bcG1: 0.58,
          bcG7: estimateG7FromG1(0.58),
        ),
        AmmoBarrelVariant(
          id: 'b29',
          label: '~29" namlu (tahmini Vo)',
          barrelInches: 29,
          muzzleVelocityMps: 910,
          bcG1: 0.58,
          bcG7: estimateG7FromG1(0.58),
        ),
      ],
    ),
    AmmoType(
      id: 'mke_127_m17',
      name: 'MKE 12,7 mm×99 M17 (İzli) — Vo 23,7 m: 872±12 m/s [MKE USA]',
      caliber: '12.7x99',
      variants: [
        AmmoBarrelVariant(
          id: 'b20',
          label: '~20" namlu (tahmini Vo)',
          barrelInches: 20,
          muzzleVelocityMps: 842,
          bcG1: 0.58,
          bcG7: estimateG7FromG1(0.58),
        ),
        AmmoBarrelVariant(
          id: 'b24',
          label: '~24" referans (yakın Vo 872)',
          barrelInches: 24,
          muzzleVelocityMps: 872,
          bcG1: 0.58,
          bcG7: estimateG7FromG1(0.58),
        ),
        AmmoBarrelVariant(
          id: 'b29',
          label: '~29" namlu (tahmini Vo)',
          barrelInches: 29,
          muzzleVelocityMps: 895,
          bcG1: 0.58,
          bcG7: estimateG7FromG1(0.58),
        ),
      ],
    ),
    AmmoType(
      id: 'mke_127_m2ap',
      name: 'MKE 12,7 mm×99 M2 AP — Vo 23,7 m: 887 m/s [MKE USA]',
      caliber: '12.7x99',
      variants: [
        AmmoBarrelVariant(
          id: 'b20',
          label: '~20" namlu (tahmini Vo)',
          barrelInches: 20,
          muzzleVelocityMps: 855,
          bcG1: 0.55,
          bcG7: estimateG7FromG1(0.55),
        ),
        AmmoBarrelVariant(
          id: 'b24',
          label: '~24" referans (yakın Vo 887)',
          barrelInches: 24,
          muzzleVelocityMps: 887,
          bcG1: 0.55,
          bcG7: estimateG7FromG1(0.55),
        ),
        AmmoBarrelVariant(
          id: 'b29',
          label: '~29" namlu (tahmini Vo)',
          barrelInches: 29,
          muzzleVelocityMps: 910,
          bcG1: 0.55,
          bcG7: estimateG7FromG1(0.55),
        ),
      ],
    ),
    AmmoType(
      id: 'mke_127_solid_sniper',
      name: 'MKE 12,7 mm×99 Solid Sniper — Vo 24 m: 845±9,2 m/s [MKE USA]',
      caliber: '12.7x99',
      variants: [
        AmmoBarrelVariant(
          id: 'b20',
          label: '~20" namlu (tahmini Vo)',
          barrelInches: 20,
          muzzleVelocityMps: 818,
          bcG1: 0.95,
          bcG7: estimateG7FromG1(0.95),
        ),
        AmmoBarrelVariant(
          id: 'b24',
          label: '~24" referans (yakın Vo 845)',
          barrelInches: 24,
          muzzleVelocityMps: 845,
          bcG1: 0.95,
          bcG7: estimateG7FromG1(0.95),
        ),
        AmmoBarrelVariant(
          id: 'b29',
          label: '~29" namlu (tahmini Vo)',
          barrelInches: 29,
          muzzleVelocityMps: 865,
          bcG1: 0.95,
          bcG7: estimateG7FromG1(0.95),
        ),
      ],
    ),
    // Lapua (FI)
    AmmoType(
      id: 'lapua_308_155_scenar',
      name: 'Lapua .308 Win 155gr Scenar',
      caliber: '.308 Win',
      variants: ammoVariantsThreeBarrels(
        mv16: 765, bc16: 0.506,
        mv20: 810, bc20: 0.506,
        mv24: 845, bc24: 0.506,
      ),
    ),
    AmmoType(
      id: 'lapua_308_167_scenarl',
      name: 'Lapua .308 Win 167gr Scenar-L',
      caliber: '.308 Win',
      variants: ammoVariantsThreeBarrels(
        mv16: 745, bc16: 0.552,
        mv20: 790, bc20: 0.552,
        mv24: 825, bc24: 0.552,
      ),
    ),
    AmmoType(
      id: 'lapua_308_175_scenar',
      name: 'Lapua .308 Win 175gr Scenar',
      caliber: '.308 Win',
      variants: ammoVariantsThreeBarrels(
        mv16: 732, bc16: 0.515,
        mv20: 778, bc20: 0.515,
        mv24: 815, bc24: 0.515,
      ),
    ),
    AmmoType(
      id: 'lapua_308_170',
      name: 'Lapua .308 Win 170gr (genel G1 — saha ile dogrulayin)',
      caliber: '.308 Win',
      variants: ammoVariantsThreeBarrels(
        mv16: 718, bc16: 0.488,
        mv20: 762, bc20: 0.488,
        mv24: 798, bc24: 0.488,
      ),
    ),
    AmmoType(
      id: 'lapua_65_123_scenar',
      name: 'Lapua 6.5 CM 123gr Scenar',
      caliber: '6.5 CM',
      variants: ammoVariantsThreeBarrels(
        mv16: 795, bc16: 0.547,
        mv20: 835, bc20: 0.547,
        mv24: 870, bc24: 0.547,
      ),
    ),
    AmmoType(
      id: 'lapua_65_136_scenar',
      name: 'Lapua 6.5 CM 136gr Scenar',
      caliber: '6.5 CM',
      variants: ammoVariantsThreeBarrels(
        mv16: 770, bc16: 0.615,
        mv20: 812, bc20: 0.615,
        mv24: 845, bc24: 0.615,
      ),
    ),
    AmmoType(
      id: 'lapua_300wm_155_scenar',
      name: 'Lapua .300 Win Mag 155gr Scenar',
      caliber: '.300 WM',
      variants: ammoVariantsThreeBarrels(
        mv16: 885, bc16: 0.487,
        mv20: 930, bc20: 0.487,
        mv24: 965, bc24: 0.487,
      ),
    ),
    AmmoType(
      id: 'lapua_338_250_scenar',
      name: 'Lapua .338 LM 250gr Scenar',
      caliber: '.338 LM',
      variants: ammoVariantsThreeBarrels(
        mv16: 830, bc16: 0.675,
        mv20: 870, bc20: 0.675,
        mv24: 905, bc24: 0.675,
      ),
    ),
    AmmoType(
      id: 'lapua_338_250_b408_fmj_bt',
      name: 'Lapua .338 LM 250gr B408 FMJ BT (genel G1 — tip ile dogrulayin)',
      caliber: '.338 LM',
      variants: ammoVariantsThreeBarrels(
        mv16: 822, bc16: 0.630,
        mv20: 862, bc20: 0.630,
        mv24: 895, bc24: 0.630,
      ),
    ),
    AmmoType(
      id: 'lapua_338_ap408_fmj_bt',
      name: 'Lapua .338 LM AP408 FMJ BT (zirh delici tip — G1 tahmini)',
      caliber: '.338 LM',
      variants: ammoVariantsThreeBarrels(
        mv16: 808, bc16: 0.565,
        mv20: 848, bc20: 0.565,
        mv24: 878, bc24: 0.565,
      ),
    ),
    AmmoType(
      id: 'lapua_338_300_scenar',
      name: 'Lapua .338 LM 300gr Scenar OTM',
      caliber: '.338 LM',
      variants: ammoVariantsThreeBarrels(
        mv16: 795, bc16: 0.825,
        mv20: 835, bc20: 0.825,
        mv24: 870, bc24: 0.825,
      ),
    ),
    AmmoType(
      id: 'lapua_762_fmj',
      name: 'Lapua 7.62x51 146gr FMJ (Ball tipi)',
      caliber: '7.62x51',
      variants: ammoVariantsThreeBarrels(
        mv16: 750, bc16: 0.393,
        mv20: 800, bc20: 0.393,
        mv24: 838, bc24: 0.393,
      ),
    ),
    // Prvi Partizan / PPU (RS)
    AmmoType(
      id: 'ppu_762_m80',
      name: 'Prvi Partizan 7.62x51 M80 Ball 145gr',
      caliber: '7.62x51',
      variants: ammoVariantsThreeBarrels(
        mv16: 738, bc16: 0.393,
        mv20: 785, bc20: 0.393,
        mv24: 820, bc24: 0.393,
      ),
    ),
    AmmoType(
      id: 'ppu_762_match_175',
      name: 'Prvi Partizan 7.62x51 175gr Match HPBT',
      caliber: '7.62x51',
      variants: ammoVariantsThreeBarrels(
        mv16: 720, bc16: 0.488,
        mv20: 765, bc20: 0.488,
        mv24: 800, bc24: 0.488,
      ),
    ),
    AmmoType(
      id: 'ppu_308_168_hpbt',
      name: 'Prvi Partizan .308 Win 168gr Match HPBT',
      caliber: '.308 Win',
      variants: ammoVariantsThreeBarrels(
        mv16: 748, bc16: 0.450,
        mv20: 792, bc20: 0.450,
        mv24: 828, bc24: 0.450,
      ),
    ),
    AmmoType(
      id: 'ppu_338_250_hpbt',
      name: 'Prvi Partizan .338 LM 250gr HPBT',
      caliber: '.338 LM',
      variants: ammoVariantsThreeBarrels(
        mv16: 825, bc16: 0.640,
        mv20: 865, bc20: 0.640,
        mv24: 895, bc24: 0.640,
      ),
    ),
    AmmoType(
      id: 'ppu_65_140_hpbt',
      name: 'Prvi Partizan 6.5 CM 140gr HPBT',
      caliber: '6.5 CM',
      variants: ammoVariantsThreeBarrels(
        mv16: 778, bc16: 0.560,
        mv20: 818, bc20: 0.560,
        mv24: 850, bc24: 0.560,
      ),
    ),
    AmmoType(
      id: 'ppu_556_m193',
      name: 'Prvi Partizan 5.56x45 M193 55gr',
      caliber: '5.56x45',
      variants: ammoVariantsThreeBarrels(
        mv16: 860, bc16: 0.246,
        mv20: 905, bc20: 0.246,
        mv24: 938, bc24: 0.246,
      ),
    ),
    AmmoType(
      id: 'ppu_556_m855',
      name: 'Prvi Partizan 5.56x45 SS109/M855 62gr',
      caliber: '5.56x45',
      variants: ammoVariantsThreeBarrels(
        mv16: 810, bc16: 0.304,
        mv20: 855, bc20: 0.304,
        mv24: 888, bc24: 0.304,
      ),
    ),
    AmmoType(
      id: 'ppu_762x39_123',
      name: 'Prvi Partizan 7.62x39 123gr FMJ',
      caliber: '7.62x39',
      variants: ammoVariantsThreeBarrels(
        mv16: 668, bc16: 0.300,
        mv20: 698, bc20: 0.300,
        mv24: 722, bc24: 0.300,
      ),
    ),
    // Hornady, Federal, Nosler, Norma, S&B, vb. (nominal)
    AmmoType(
      id: 'hornady_308_178_eldx',
      name: 'Hornady .308 Win 178gr ELD-X',
      caliber: '.308 Win',
      variants: ammoVariantsThreeBarrels(
        mv16: 728, bc16: 0.552,
        mv20: 775, bc20: 0.552,
        mv24: 810, bc24: 0.552,
      ),
    ),
    AmmoType(
      id: 'hornady_300wm_200_eldx',
      name: 'Hornady .300 Win Mag 200gr ELD-X',
      caliber: '.300 WM',
      variants: ammoVariantsThreeBarrels(
        mv16: 845, bc16: 0.625,
        mv20: 890, bc20: 0.625,
        mv24: 920, bc24: 0.625,
      ),
    ),
    AmmoType(
      id: 'federal_gmm_168',
      name: 'Federal Gold Medal .308 168gr SMK',
      caliber: '.308 Win',
      variants: ammoVariantsThreeBarrels(
        mv16: 748, bc16: 0.462,
        mv20: 792, bc20: 0.462,
        mv24: 828, bc24: 0.462,
      ),
    ),
    AmmoType(
      id: 'federal_gmm_175',
      name: 'Federal Gold Medal 7.62x51 175gr SMK',
      caliber: '7.62x51',
      variants: ammoVariantsThreeBarrels(
        mv16: 725, bc16: 0.505,
        mv20: 770, bc20: 0.505,
        mv24: 805, bc24: 0.505,
      ),
    ),
    AmmoType(
      id: 'nosler_308_168_cc',
      name: 'Nosler .308 Win 168gr Custom Competition',
      caliber: '.308 Win',
      variants: ammoVariantsThreeBarrels(
        mv16: 742, bc16: 0.470,
        mv20: 788, bc20: 0.470,
        mv24: 822, bc24: 0.470,
      ),
    ),
    AmmoType(
      id: 'norma_308_168_golden',
      name: 'Norma .308 Win 168gr Golden Target',
      caliber: '.308 Win',
      variants: ammoVariantsThreeBarrels(
        mv16: 750, bc16: 0.475,
        mv20: 795, bc20: 0.475,
        mv24: 830, bc24: 0.475,
      ),
    ),
    AmmoType(
      id: 'norma_308_190_diamond',
      name: 'Norma .308 Win 190gr Diamond Line (genel G1 — katalog ile dogrulayin)',
      caliber: '.308 Win',
      variants: ammoVariantsThreeBarrels(
        mv16: 688, bc16: 0.545,
        mv20: 735, bc20: 0.545,
        mv24: 772, bc24: 0.545,
      ),
    ),
    AmmoType(
      id: 'pramtec_1270_750',
      name: 'Pramtec / 12.7×99 750gr (BMG sinifi — G1 tahmini)',
      caliber: '12.7x99',
      variants: ammoVariantsThreeBarrels(
        mv16: 760, bc16: 1.050,
        mv20: 795, bc20: 1.050,
        mv24: 825, bc24: 1.050,
      ),
    ),
    AmmoType(
      id: 'hornady_1270_750_amax',
      name: 'Hornady .50 BMG 750gr A-MAX (12.7×99 — G1 tahmini)',
      caliber: '12.7x99',
      variants: ammoVariantsThreeBarrels(
        mv16: 765, bc16: 1.080,
        mv20: 802, bc20: 1.080,
        mv24: 832, bc24: 1.080,
      ),
    ),
    AmmoType(
      id: 'sb_762_147_fmj',
      name: 'Sellier & Bellot 7.62x51 147gr FMJ',
      caliber: '7.62x51',
      variants: ammoVariantsThreeBarrels(
        mv16: 735, bc16: 0.398,
        mv20: 780, bc20: 0.398,
        mv24: 815, bc24: 0.398,
      ),
    ),
    AmmoType(
      id: 'sb_308_168_hpbt',
      name: 'Sellier & Bellot .308 Win 168gr HPBT',
      caliber: '.308 Win',
      variants: ammoVariantsThreeBarrels(
        mv16: 738, bc16: 0.455,
        mv20: 785, bc20: 0.455,
        mv24: 820, bc24: 0.455,
      ),
    ),
    AmmoType(
      id: 'rws_308_168_target',
      name: 'RWS .308 Win 168gr Target Line',
      caliber: '.308 Win',
      variants: ammoVariantsThreeBarrels(
        mv16: 745, bc16: 0.465,
        mv20: 790, bc20: 0.465,
        mv24: 825, bc24: 0.465,
      ),
    ),
    AmmoType(
      id: 'winchester_match_168',
      name: 'Winchester Match .308 168gr BTHP',
      caliber: '.308 Win',
      variants: ammoVariantsThreeBarrels(
        mv16: 740, bc16: 0.458,
        mv20: 785, bc20: 0.458,
        mv24: 818, bc24: 0.458,
      ),
    ),
    AmmoType(
      id: 'black_hills_175',
      name: 'Black Hills 7.62x51 / .308 175gr Match',
      caliber: '7.62x51',
      variants: ammoVariantsThreeBarrels(
        mv16: 725, bc16: 0.498,
        mv20: 770, bc20: 0.498,
        mv24: 808, bc24: 0.498,
      ),
    ),
    AmmoType(
      id: 'imi_556_m855',
      name: 'IMI 5.56x45 M855 62gr (IWI)',
      caliber: '5.56x45',
      variants: ammoVariantsThreeBarrels(
        mv16: 805, bc16: 0.304,
        mv20: 850, bc20: 0.304,
        mv24: 882, bc24: 0.304,
      ),
    ),
    AmmoType(
      id: 'berger_65_140_factory',
      name: 'Berger 6.5 CM 140gr Hybrid Target (ticari)',
      caliber: '6.5 CM',
      variants: ammoVariantsThreeBarrels(
        mv16: 780, bc16: 0.618,
        mv20: 820, bc20: 0.618,
        mv24: 855, bc24: 0.618,
      ),
    ),
  ];
}
