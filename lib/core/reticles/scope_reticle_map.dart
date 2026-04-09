import '../ballistics/click_units.dart';
import '../catalog/catalog_data.dart';

/// [assets/reticles/reticle_catalog.json] içindeki retikül `id` değerleri.
///
/// **Önizleme — telif:** Üreticilerin retikül çizimleri telif / ticari marka
/// kapsamındadır. İnternetten resmi görsel indirip uygulamaya gömmek yerine,
/// bu projede [ReticleCanvasPainter] ile çizilen **parametrik** desenler
/// (hash, ağaç, mil-dot, duplex, German #4) kullanılır; ekrandaki görünüm
/// eğitim/önizleme amaçlıdır ve katalogdaki gerçek P4L, H59, TReMoR3 vb. ile
/// birebir aynı değildir.
///
/// Dürbün seçildiğinde retikülün otomatik değişmesi: [BallisticsPage] içinde
/// `_autoReticleFromScope` açıkken `_syncReticleFromScope` bu eşlemeyi uygular.
const kScopeIdToDefaultReticleId = <String, String>{
  'pmii_01mil': 'ret_schmidt_bender_hash_31',
  'vortex_01mil': 'ret_vortex_hash_1',
  'vortex_pst_gen2_mil': 'ret_vortex_tree_4',
  'vortex_diamondback_moa': 'ret_vortex_tree_3',
  'leupold_025moa': 'ret_leupold_hash_72',
  'leupold_mk5_mil': 'ret_leupold_hash_71',
  'nightforce_025moa': 'ret_nightforce_hash_12',
  'nightforce_nx8_mil': 'ret_nightforce_hash_11',
  'atacr_fc_dimil': 'ret_nightforce_tree_13',
  'march_005mil': 'ret_march_hash_241',
  'vector_01mil': 'ret_vector_hash_311',
  'athlon_025moa': 'ret_athlon_tree_93',
  'tr_scope_312x50_mil': 'ret_vector_hash_311',
  'tr_scope_416x50_mil': 'ret_vector_hash_311',
  'tr_scope_624x50_mil': 'ret_vector_hash_311',
  'tr_scope_525x56_mil': 'ret_vector_hash_311',
  'tr_scope_525x50_mil': 'ret_vector_hash_311',
  'tr_scope_520x50_mil': 'ret_vector_hash_311',
  // 3E EOS: aynı marka, farklı önizleme desenleri (hash / ağaç / mil-dot).
  'tr_3e_keskin_31250_mil': 'ret_element_optics_hash_301',
  'tr_3e_avci_mil': 'ret_element_optics_tree_304',
  'tr_3e_eos_gen_mil': 'ret_element_optics_mil_dot_305',
  'swarovski_x5i_52556_mil': 'ret_swarovski_hash_211',
  'swarovski_z8i_mil': 'ret_swarovski_tree_214',
  'swarovski_z5i_moa': 'ret_swarovski_tree_213',
  'swarovski_ds_moa': 'ret_swarovski_tree_213',
  'burris_xtr3_mil': 'ret_burris_hash_81',
  'trijicon_tenmile_mil': 'ret_trijicon_hash_21',
  'trijicon_credo_mil': 'ret_trijicon_tree_23',
  'us_optics_tpal_mil': 'ret_us_optics_hash_161',
  'zero_compromise_zc527_mil': 'ret_zero_compromise_hash_172',
  'sightron_s3_moa': 'ret_sightron_tree_183',
  'sightron_sv_mil': 'ret_sightron_hash_181',
  'hawke_sidewinder_mil': 'ret_hawke_hash_191',
  'delta_sentry_mil': 'ret_delta_optical_hash_131',
  'ior_valdada_mil': 'ret_ior_hash_202',
  'sig_tango4_mil': 'ret_sig_sauer_hash_112',
};

String? defaultReticleCatalogIdForScope(ScopeType scope) =>
    kScopeIdToDefaultReticleId[scope.id];

/// Eşleme yoksa tıklama birimine göre güvenli varsayılan.
String fallbackReticleCatalogId(ClickUnit click) =>
    click == ClickUnit.moa ? 'ret_nightforce_hash_12' : 'ret_vortex_hash_1';
