import 'catalog_data.dart';

/// Silah fabrika / tipik balistik ön ayarı (Vo, BC; isteğe bağlı varsayılan mühimmat ve dürbün id).
class WeaponBallisticPreset {
  final double muzzleVelocityMps;
  final double ballisticCoefficientG1;
  /// Boşsa G7 modunda [ballisticCoefficientG1] üzerinden kabaca G7 tahmini kullanılır.
  final double? ballisticCoefficientG7;
  final String? ammoCatalogId;
  final String? ammoVariantId;
  final String? scopeCatalogId;

  const WeaponBallisticPreset({
    required this.muzzleVelocityMps,
    required this.ballisticCoefficientG1,
    this.ballisticCoefficientG7,
    this.ammoCatalogId,
    this.ammoVariantId,
    this.scopeCatalogId,
  });
}

/// Silah [WeaponType.id] → ön ayar.
const Map<String, WeaponBallisticPreset> weaponBallisticPresets = {
  'r700_308': WeaponBallisticPreset(
    muzzleVelocityMps: 800,
    ballisticCoefficientG1: 0.462,
    ammoCatalogId: '308_168_smk',
    scopeCatalogId: 'pmii_01mil',
  ),
  'tikka_t3x': WeaponBallisticPreset(
    muzzleVelocityMps: 800,
    ballisticCoefficientG1: 0.462,
    ammoCatalogId: '308_168_smk',
    scopeCatalogId: 'tr_scope_525x56_mil',
  ),
  'sako_trg22': WeaponBallisticPreset(
    muzzleVelocityMps: 800,
    ballisticCoefficientG1: 0.505,
    ammoCatalogId: '308_175_smk',
    scopeCatalogId: 'swarovski_x5i_52556_mil',
  ),
  'sako_trg42': WeaponBallisticPreset(
    muzzleVelocityMps: 870,
    ballisticCoefficientG1: 0.675,
    ammoCatalogId: 'lapua_338_250_scenar',
    scopeCatalogId: 'pmii_01mil',
  ),
  'm110': WeaponBallisticPreset(
    muzzleVelocityMps: 780,
    ballisticCoefficientG1: 0.496,
    ammoCatalogId: '762_175_otm',
    scopeCatalogId: 'vortex_pst_gen2_mil',
  ),
  'barrett_mrad': WeaponBallisticPreset(
    muzzleVelocityMps: 870,
    ballisticCoefficientG1: 0.675,
    ammoCatalogId: '338_250_scenar',
    scopeCatalogId: 'nightforce_nx8_mil',
  ),
  'tr_knt76': WeaponBallisticPreset(
    muzzleVelocityMps: 838,
    ballisticCoefficientG1: 0.45,
    ammoCatalogId: 'mke_762_m80',
    ammoVariantId: 'b22',
    scopeCatalogId: 'tr_scope_525x56_mil',
  ),
  'tr_jmk_bora': WeaponBallisticPreset(
    muzzleVelocityMps: 887,
    ballisticCoefficientG1: 0.62,
    ammoCatalogId: 'mke_127_m33',
    scopeCatalogId: 'tr_scope_624x50_mil',
  ),
  'tr_kn12': WeaponBallisticPreset(
    muzzleVelocityMps: 890,
    ballisticCoefficientG1: 0.675,
    ammoCatalogId: 'mke_859_ball',
    scopeCatalogId: 'tr_scope_525x56_mil',
  ),
  'tr_ksr50': WeaponBallisticPreset(
    muzzleVelocityMps: 887,
    ballisticCoefficientG1: 0.62,
    ammoCatalogId: 'mke_127_m33',
    scopeCatalogId: 'tr_scope_624x50_mil',
  ),
  'tr_jng90': WeaponBallisticPreset(
    muzzleVelocityMps: 810,
    ballisticCoefficientG1: 0.496,
    ammoCatalogId: 'bund_762_m118lr',
    scopeCatalogId: 'tr_scope_525x56_mil',
  ),
  'tr_hk33': WeaponBallisticPreset(
    muzzleVelocityMps: 885,
    ballisticCoefficientG1: 0.304,
    ammoCatalogId: 'bund_556_m855',
    scopeCatalogId: 'tr_scope_416x50_mil',
  ),
  'tr_g3a7': WeaponBallisticPreset(
    muzzleVelocityMps: 800,
    ballisticCoefficientG1: 0.393,
    ammoCatalogId: 'bund_508_nereli',
    scopeCatalogId: 'tr_scope_312x50_mil',
  ),
  'tr_mpt76_carbine': WeaponBallisticPreset(
    muzzleVelocityMps: 785,
    ballisticCoefficientG1: 0.42,
    ammoCatalogId: 'bund_tr_mpt_standard',
    scopeCatalogId: 'tr_scope_312x50_mil',
  ),
  'nato_cz_bren2': WeaponBallisticPreset(
    muzzleVelocityMps: 885,
    ballisticCoefficientG1: 0.304,
    ammoCatalogId: 'bund_556_m855',
    scopeCatalogId: 'tr_scope_416x50_mil',
  ),
  'nato_sig_mcx': WeaponBallisticPreset(
    muzzleVelocityMps: 870,
    ballisticCoefficientG1: 0.304,
    ammoCatalogId: 'bund_556_m855',
    scopeCatalogId: 'tr_scope_312x50_mil',
  ),
  'nato_r700_police': WeaponBallisticPreset(
    muzzleVelocityMps: 800,
    ballisticCoefficientG1: 0.458,
    ammoCatalogId: 'winchester_match_168',
    scopeCatalogId: 'tr_scope_525x56_mil',
  ),
  'nato_tikka_t3x_tac': WeaponBallisticPreset(
    muzzleVelocityMps: 808,
    ballisticCoefficientG1: 0.455,
    ammoCatalogId: 'sb_308_168_hpbt',
    scopeCatalogId: 'leupold_mk5_mil',
  ),
  'nato_sig_cross': WeaponBallisticPreset(
    muzzleVelocityMps: 798,
    ballisticCoefficientG1: 0.465,
    ammoCatalogId: 'rws_308_168_target',
    scopeCatalogId: 'vortex_pst_gen2_mil',
  ),
  'nato_desert_tech_srs': WeaponBallisticPreset(
    muzzleVelocityMps: 870,
    ballisticCoefficientG1: 0.675,
    ammoCatalogId: 'lapua_338_250_scenar',
    scopeCatalogId: 'atacr_fc_dimil',
  ),
  'akm_762x39': WeaponBallisticPreset(
    muzzleVelocityMps: 705,
    ballisticCoefficientG1: 0.3,
    ammoCatalogId: '762x39_123',
    scopeCatalogId: 'tr_scope_312x50_mil',
  ),
  'svd': WeaponBallisticPreset(
    muzzleVelocityMps: 810,
    ballisticCoefficientG1: 0.5,
    ammoCatalogId: '762x54r_174',
    scopeCatalogId: 'tr_scope_416x50_mil',
  ),
  'cz557': WeaponBallisticPreset(
    muzzleVelocityMps: 800,
    ballisticCoefficientG1: 0.462,
    ammoCatalogId: '308_168_smk',
    scopeCatalogId: 'tr_scope_312x50_mil',
  ),
  'ruger_rpr': WeaponBallisticPreset(
    muzzleVelocityMps: 825,
    ballisticCoefficientG1: 0.61,
    ammoCatalogId: '65cm_140_eldm',
    scopeCatalogId: 'vortex_pst_gen2_mil',
  ),
  'accuracy_axsr': WeaponBallisticPreset(
    muzzleVelocityMps: 880,
    ballisticCoefficientG1: 0.63,
    ammoCatalogId: 'bund_300nm_230',
    scopeCatalogId: 'pmii_01mil',
  ),
  'm2010': WeaponBallisticPreset(
    muzzleVelocityMps: 865,
    ballisticCoefficientG1: 0.533,
    ammoCatalogId: '300wm_190_smk',
    scopeCatalogId: 'atacr_fc_dimil',
  ),
};

/// Kalibre için yedek ön ayar (bundled silah id’si listede yoksa).
const Map<String, WeaponBallisticPreset> caliberFallbackPresets = {
  '7.62x51': WeaponBallisticPreset(
    muzzleVelocityMps: 800,
    ballisticCoefficientG1: 0.393,
    ammoCatalogId: 'mke_762_m80',
    scopeCatalogId: 'tr_scope_525x56_mil',
  ),
  '.308 Win': WeaponBallisticPreset(
    muzzleVelocityMps: 800,
    ballisticCoefficientG1: 0.462,
    ammoCatalogId: '308_168_smk',
    scopeCatalogId: 'tr_scope_525x56_mil',
  ),
  '5.56x45': WeaponBallisticPreset(
    muzzleVelocityMps: 885,
    ballisticCoefficientG1: 0.304,
    ammoCatalogId: 'bund_556_m855',
    scopeCatalogId: 'tr_scope_312x50_mil',
  ),
  '6.5 CM': WeaponBallisticPreset(
    muzzleVelocityMps: 825,
    ballisticCoefficientG1: 0.61,
    ammoCatalogId: '65cm_140_eldm',
    scopeCatalogId: 'tr_scope_525x56_mil',
  ),
  '6.5 PRC': WeaponBallisticPreset(
    muzzleVelocityMps: 895,
    ballisticCoefficientG1: 0.625,
    ammoCatalogId: 'hornady_65prc_143',
    scopeCatalogId: 'tr_scope_525x56_mil',
  ),
  '.408 CT': WeaponBallisticPreset(
    muzzleVelocityMps: 925,
    ballisticCoefficientG1: 0.870,
    ammoCatalogId: 'nominal_408ct_419',
    scopeCatalogId: 'tr_scope_624x50_mil',
  ),
  '.338 LM': WeaponBallisticPreset(
    muzzleVelocityMps: 870,
    ballisticCoefficientG1: 0.675,
    ammoCatalogId: 'lapua_338_250_scenar',
    scopeCatalogId: 'swarovski_x5i_52556_mil',
  ),
  '8.59x70': WeaponBallisticPreset(
    muzzleVelocityMps: 890,
    ballisticCoefficientG1: 0.675,
    ammoCatalogId: 'mke_859_ball',
    scopeCatalogId: 'tr_scope_525x56_mil',
  ),
  '8.59x69': WeaponBallisticPreset(
    muzzleVelocityMps: 890,
    ballisticCoefficientG1: 0.675,
    ammoCatalogId: 'mke_859_ball',
    scopeCatalogId: 'tr_scope_525x56_mil',
  ),
  '12.7x99': WeaponBallisticPreset(
    muzzleVelocityMps: 820,
    ballisticCoefficientG1: 0.62,
    ammoCatalogId: 'bund_127_bmg',
    scopeCatalogId: 'tr_scope_624x50_mil',
  ),
  '7.62x39': WeaponBallisticPreset(
    muzzleVelocityMps: 705,
    ballisticCoefficientG1: 0.3,
    ammoCatalogId: '762x39_123',
    scopeCatalogId: 'tr_scope_312x50_mil',
  ),
  '7.62x54R': WeaponBallisticPreset(
    muzzleVelocityMps: 810,
    ballisticCoefficientG1: 0.5,
    ammoCatalogId: '762x54r_174',
    scopeCatalogId: 'tr_scope_416x50_mil',
  ),
  '.300 WM': WeaponBallisticPreset(
    muzzleVelocityMps: 865,
    ballisticCoefficientG1: 0.533,
    ammoCatalogId: '300wm_190_smk',
    scopeCatalogId: 'tr_scope_525x56_mil',
  ),
  '.300 NM': WeaponBallisticPreset(
    muzzleVelocityMps: 880,
    ballisticCoefficientG1: 0.63,
    ammoCatalogId: 'bund_300nm_230',
    scopeCatalogId: 'pmii_01mil',
  ),
};

WeaponBallisticPreset? ballisticPresetForWeapon(WeaponType w) {
  final s = weaponBallisticPresets[w.id];
  if (s != null) return s;
  return caliberFallbackPresets[w.caliber];
}
